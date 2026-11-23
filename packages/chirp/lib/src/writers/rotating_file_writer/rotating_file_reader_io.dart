import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer_io.dart'
    show isRotatedLogFile;

/// `dart:io`-based implementation of [RotatingFileReader].
///
/// Reads and tails log files produced by [RotatingFileWriter] on platforms
/// where file I/O is available.
class RotatingFileReaderIo implements RotatingFileReader {
  final FutureOr<String> Function() _baseFilePathProvider;
  final Duration _pollInterval;
  final String _recordSeparator;
  String? _resolvedBaseFilePath;

  @override
  String get baseFilePath {
    final path = _resolvedBaseFilePath;
    if (path == null) {
      throw StateError(
        'RotatingFileReader.baseFilePath is not available yet. '
        'If you provided an async baseFilePathProvider, '
        'the path is resolved asynchronously.',
      );
    }
    return path;
  }

  RotatingFileReaderIo({
    required FutureOr<String> Function() baseFilePathProvider,
    required Duration pollInterval,
    required String recordSeparator,
  })  : _baseFilePathProvider = baseFilePathProvider,
        _pollInterval = pollInterval,
        _recordSeparator = recordSeparator;

  Future<String> _resolveBaseFilePath() async {
    if (_resolvedBaseFilePath != null) return _resolvedBaseFilePath!;
    final path = await _baseFilePathProvider();
    _resolvedBaseFilePath = path;
    return path;
  }

  @override
  Future<List<String>> listFiles({bool includeCurrent = true}) async {
    final resolvedPath = await _resolveBaseFilePath();
    final current = File(resolvedPath);
    final dir = current.parent;
    final name = current.uri.pathSegments.last;

    if (!dir.existsSync()) return const [];

    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    final extension = dotIndex > 0 ? name.substring(dotIndex) : '';

    final entries = dir
        .listSync()
        .whereType<File>()
        .where((it) {
          final fileName = it.uri.pathSegments.last;
          if (fileName == name) {
            return includeCurrent;
          }
          return isRotatedLogFile(
            fileName,
            baseName: baseName,
            extension: extension,
          );
        })
        .map((it) => (path: it.path, modified: it.statSync().modified))
        .toList()
      ..sort((a, b) => a.modified.compareTo(b.modified));

    return entries.map((e) => e.path).toList(growable: false);
  }

  @override
  Stream<String> read({
    int? last,
    Encoding encoding = utf8,
  }) async* {
    final files = await listFiles();
    final currentPath = await _resolveBaseFilePath();

    // When last is requested, we need to materialize to compute the tail.
    if (last != null) {
      if (last <= 0) return;
      if (files.isEmpty) return;

      var remaining = last;
      final chunks = <List<String>>[];

      for (final path in files.reversed) {
        if (remaining <= 0) break;

        final lines = await _readAllLinesFromFile(
          path,
          encoding,
          _recordSeparator,
          compressed: _isCompressedLog(path, currentPath: currentPath),
        );
        if (lines.isEmpty) continue;

        if (lines.length > remaining) {
          chunks.add(lines.sublist(lines.length - remaining));
          remaining = 0;
          continue;
        }

        chunks.add(lines);
        remaining -= lines.length;
      }

      for (final chunk in chunks.reversed) {
        for (final line in chunk) {
          yield line;
        }
      }
      return;
    }

    // Stream all content in order.
    for (final path in files) {
      if (_isCompressedLog(path, currentPath: currentPath)) {
        final bytes = await File(path).readAsBytes();
        final decompressed = gzip.decode(bytes);
        final text = encoding.decode(decompressed);
        final records = _splitRecords(text, _recordSeparator);
        yield* Stream<String>.fromIterable(records);
      } else {
        yield* File(path)
            .openRead()
            .transform(encoding.decoder)
            .transform(_RecordSplitter(_recordSeparator));
      }
    }
  }

  @override
  Stream<String> tail({
    int? last,
    Encoding encoding = utf8,
  }) async* {
    final path = await _resolveBaseFilePath();
    final tail = _Tail(
      reader: this,
      file: File(path),
      last: last,
      encoding: encoding,
    );
    yield* tail.stream;
  }
}

/// A running [RotatingFileReaderIo.tail].
///
/// Follows the log by name, like `tail -F`. Every file the log consists of
/// over time is a generation: the rotated files and the current file. Each
/// generation is read once, from its first byte to its last, by a decoder
/// that keeps an incomplete record or character until the rest arrives.
///
/// A file is checked and read through one open handle, which keeps pointing
/// to the same file when it is renamed in between. When the current file is
/// not the followed generation anymore, the rest of that generation is read
/// from its rotated file before the new current file is read from its start.
///
/// Limits: a rotated file that the retention policy deleted before it was
/// read is gone. A file rewritten in place is only recognized when it got
/// shorter, or when its first or its last read [_fingerprintLength] bytes
/// changed.
class _Tail {
  final RotatingFileReaderIo _reader;
  final File _file;
  final int? _last;
  final Encoding _encoding;
  final _controller = StreamController<String>();

  /// Collects the records of the history when only the last ones are wanted.
  ListQueue<String>? _ring;
  int _ringSize = 0;

  // The generation that is read right now.
  int _offset = 0;
  String _partial = '';
  Sink<List<int>>? _decoder;
  final _firstBytes = <int>[];
  final _lastBytes = <int>[];

  /// The rotated files that are read or older than the start of the tail.
  final _seen = <String>{};

  bool _cancelled = false;
  bool _polling = false;
  bool _pollAgain = false;
  Timer? _timer;
  StreamSubscription<FileSystemEvent>? _watcher;

  _Tail({
    required RotatingFileReaderIo reader,
    required File file,
    required int? last,
    required Encoding encoding,
  })  : _reader = reader,
        _file = file,
        _last = last,
        _encoding = encoding {
    _controller.onListen = () {
      unawaited(_run());
    };
    _controller.onResume = () {
      unawaited(_poll());
    };
    _controller.onCancel = () {
      _cancelled = true;
      _timer?.cancel();
      _watcher?.cancel();
    };
  }

  Stream<String> get stream => _controller.stream;

  /// A paused listener stops the reading, so that a large history is not
  /// buffered in memory.
  bool get _paused => _ring == null && _controller.isPaused;

  Future<void> _run() async {
    final last = _last;
    if (last != null) {
      // Keeps a poll from reading at the same time.
      _polling = true;
      try {
        await _emitLast(last < 0 ? 0 : last);
      } catch (e, stack) {
        _controller.addError(e, stack);
      } finally {
        _polling = false;
      }
    }
    if (_cancelled) {
      return;
    }

    // Reacts to file-system events and uses a periodic poll as a fallback
    // for filesystems that don't reliably emit change events.
    _watch();
    await _poll();
    if (_cancelled) {
      return;
    }
    _timer = Timer.periodic(_reader._pollInterval, (_) {
      _watch();
      unawaited(_poll());
    });
  }

  /// Emits the last [count] records that exist right now.
  Future<void> _emitLast(int count) async {
    // Listed before the current file is opened, so these are all older.
    // They are only read as far as their records are needed.
    final older = await _unseenRotated();
    _seen.addAll(older.map(_generation));

    final ring = ListQueue<String>();
    _ring = ring;
    _ringSize = count;
    try {
      await _step();
    } finally {
      _ring = null;
    }

    final chunks = <List<String>>[];
    var missing = count - ring.length;
    for (final path in older.reversed) {
      if (missing <= 0) {
        break;
      }
      final lines = await _readRotatedRecords(path);
      chunks.add(lines);
      missing -= lines.length;
    }

    final history = [...chunks.reversed.expand((it) => it), ...ring];
    final skip = history.length > count ? history.length - count : 0;
    for (final record in history.skip(skip)) {
      _controller.add(record);
    }
  }

  Future<void> _poll() async {
    if (_polling) {
      // The running poll may already be past the new bytes.
      _pollAgain = true;
      return;
    }
    _polling = true;
    do {
      _pollAgain = false;
      try {
        await _step();
      } on FileSystemException {
        // A file vanished while it was read. The next poll continues.
      } catch (e, stack) {
        _controller.addError(e, stack);
      }
    } while (_pollAgain && !_cancelled);
    _polling = false;
  }

  /// Reads everything that was written since the last call.
  Future<void> _step() async {
    while (!_cancelled && !_paused) {
      final current = await _openCurrent();
      try {
        if (_offset > 0) {
          if (current != null && await _continues(current)) {
            await _read(current, canPause: true);
            return;
          }
          // The followed file was rotated away, truncated or replaced.
          await _readRestFromRotated();
          continue;
        }

        // Listed after the current file was opened: a rotated file that
        // appears later than this holds the opened file itself.
        final rotatedCurrent = await _readOlderGenerations(current);
        if (rotatedCurrent) {
          continue;
        }
        if (current != null) {
          await _read(current, canPause: true);
        }
        return;
      } finally {
        await current?.close();
      }
    }
  }

  /// Finishes the followed generation, which is not the current file anymore.
  Future<void> _readRestFromRotated() async {
    for (final path in await _unseenRotated()) {
      final rotated = await _openRotated(path);
      if (rotated == null) {
        continue;
      }
      try {
        if (await _continues(rotated)) {
          _seen.add(_generation(path));
          await _read(rotated, canPause: false);
          _finishGeneration();
          return;
        }
      } finally {
        await rotated.close();
      }
    }
    // Truncated or rewritten in place, or the rotated file is deleted.
    _restart();
  }

  /// Reads the rotated files that are not read yet, before [current] is read
  /// from its start.
  ///
  /// Returns true when [current] was rotated since it was opened. It is read
  /// to its end then, and the new current file has to be opened.
  Future<bool> _readOlderGenerations(_Bytes? current) async {
    for (final path in await _unseenRotated()) {
      if (_cancelled || _paused) {
        return false;
      }
      _seen.add(_generation(path));
      final rotated = await _openRotated(path);
      if (rotated == null) {
        continue;
      }
      try {
        if (current != null && await _isSame(current, rotated)) {
          await _read(current, canPause: false);
          _finishGeneration();
          return true;
        }
        await _read(rotated, canPause: false);
        _finishGeneration();
      } finally {
        await rotated.close();
      }
    }
    return false;
  }

  /// Decodes [source] from [_offset] to its end.
  Future<void> _read(_Bytes source, {required bool canPause}) async {
    final length = await source.length();
    while (_offset < length) {
      if (_cancelled) {
        return;
      }
      if (canPause && _paused) {
        return;
      }
      final remaining = length - _offset;
      final count = remaining > _chunkSize ? _chunkSize : remaining;
      final bytes = await source.read(_offset, _offset + count);
      if (bytes.isEmpty) {
        // Shorter than its length said, it was truncated meanwhile.
        return;
      }

      final missingFirst = _fingerprintLength - _firstBytes.length;
      if (missingFirst > 0) {
        _firstBytes.addAll(bytes.take(missingFirst));
      }
      _lastBytes.addAll(bytes);
      if (_lastBytes.length > _fingerprintLength) {
        _lastBytes.removeRange(0, _lastBytes.length - _fingerprintLength);
      }
      _offset += bytes.length;

      try {
        final decoder = _decoder ??=
            _encoding.decoder.startChunkedConversion(_CallbackSink(_addText));
        decoder.add(bytes);
      } catch (e, stack) {
        // Undecodable bytes. Continues behind this chunk with a new decoder.
        _controller.addError(e, stack);
        _decoder = null;
        _partial = '';
      }
    }
  }

  void _addText(String text) {
    final parts = (_partial + text).split(_reader._recordSeparator);
    _partial = parts.removeLast();
    for (final record in parts) {
      _emit(record);
    }
  }

  void _emit(String record) {
    final ring = _ring;
    if (ring == null) {
      _controller.add(record);
      return;
    }
    ring.addLast(record);
    if (ring.length > _ringSize) {
      ring.removeFirst();
    }
  }

  /// Ends a generation that was read to its last byte. A record without
  /// separator at its end is complete then.
  void _finishGeneration() {
    try {
      _decoder?.close();
    } catch (e, stack) {
      // Ends within a character.
      _controller.addError(e, stack);
    }
    if (_partial.isNotEmpty) {
      _emit(_partial);
    }
    _restart();
  }

  /// Starts over at the first byte of the next generation.
  void _restart() {
    _offset = 0;
    _partial = '';
    _decoder = null;
    _firstBytes.clear();
    _lastBytes.clear();
  }

  /// Whether [source] is the followed generation, which may have grown.
  Future<bool> _continues(_Bytes source) async {
    if (await source.length() < _offset) {
      return false;
    }
    final first = await source.read(0, _firstBytes.length);
    if (!_equalBytes(first, _firstBytes)) {
      return false;
    }
    final last = await source.read(_offset - _lastBytes.length, _offset);
    return _equalBytes(last, _lastBytes);
  }

  /// Whether [a] and [b] are the same file, judged by its size and the
  /// bytes at its start and its end.
  Future<bool> _isSame(_Bytes a, _Bytes b) async {
    final length = await a.length();
    if (length == 0 || length != await b.length()) {
      return false;
    }
    final count = length > _fingerprintLength ? _fingerprintLength : length;
    if (!_equalBytes(await a.read(0, count), await b.read(0, count))) {
      return false;
    }
    return _equalBytes(
      await a.read(length - count, length),
      await b.read(length - count, length),
    );
  }

  Future<_Bytes?> _openCurrent() async {
    try {
      return _FileBytes(await _file.open());
    } on FileSystemException {
      return null;
    }
  }

  /// Returns null when the file is deleted.
  Future<_Bytes?> _openRotated(String path) async {
    try {
      if (_isCompressed(path)) {
        return _MemoryBytes(gzip.decode(await File(path).readAsBytes()));
      }
      return _FileBytes(await File(path).open());
    } on FileSystemException {
      if (_isCompressed(path)) {
        // Deleted by the retention policy.
        return null;
      }
      // Compressed since it was listed.
      return _openRotated('$path.gz');
    }
  }

  Future<List<String>> _readRotatedRecords(String path) async {
    try {
      return await _readAllLinesFromFile(
        path,
        _encoding,
        _reader._recordSeparator,
        compressed: _isCompressed(path),
      );
    } on FileSystemException {
      if (_isCompressed(path)) {
        // Deleted by the retention policy.
        return const [];
      }
      // Compressed since it was listed.
      return _readRotatedRecords('$path.gz');
    }
  }

  /// The rotated files that are not read yet, oldest first.
  Future<List<String>> _unseenRotated() async {
    final files = await _reader.listFiles(includeCurrent: false);
    final all = files.toSet();
    return files.where((it) {
      if (_seen.contains(_generation(it))) {
        return false;
      }
      // While a rotated file is compressed, both it and its .gz exist.
      return !_isCompressed(it) || !all.contains(_generation(it));
    }).toList();
  }

  bool _isCompressed(String path) {
    return _isCompressedLog(path, currentPath: _file.path);
  }

  /// The name of a rotated file before it was compressed.
  String _generation(String path) {
    if (!_isCompressed(path)) {
      return path;
    }
    return path.substring(0, path.length - '.gz'.length);
  }

  /// Watches the directory. It may not exist yet or be replaced later, the
  /// periodic poll covers the time without a watcher.
  void _watch() {
    if (_cancelled || _watcher != null) {
      return;
    }
    final dir = _file.parent;
    if (!FileSystemEntity.isWatchSupported || !dir.existsSync()) {
      return;
    }
    final fileName = _file.uri.pathSegments.last;
    final normalizedDirPath = _normalizeDirPath(dir.path);

    bool shouldPoll(FileSystemEvent event) {
      if (event.path.endsWith(fileName)) {
        return true;
      }
      return _normalizeDirPath(event.path) == normalizedDirPath;
    }

    _watcher = dir.watch().where(shouldPoll).listen(
      (_) {
        // Fire and forget.
        unawaited(_poll());
      },
      onError: (Object _) {
        _watcher?.cancel();
        _watcher = null;
      },
      onDone: () {
        _watcher = null;
      },
    );
  }
}

/// Random access to the bytes of a log file.
abstract class _Bytes {
  Future<int> length();

  /// The bytes from [start] to [end], or fewer when the file ends earlier.
  Future<List<int>> read(int start, int end);

  Future<void> close();
}

class _FileBytes implements _Bytes {
  final RandomAccessFile _file;

  _FileBytes(this._file);

  @override
  Future<int> length() => _file.length();

  @override
  Future<List<int>> read(int start, int end) async {
    await _file.setPosition(start);
    return _file.read(end - start);
  }

  @override
  Future<void> close() async {
    await _file.close();
  }
}

/// A compressed file, which can only be decompressed as a whole.
class _MemoryBytes implements _Bytes {
  final List<int> _bytes;

  _MemoryBytes(this._bytes);

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<List<int>> read(int start, int end) async {
    if (start >= _bytes.length) {
      return const [];
    }
    return _bytes.sublist(start, end > _bytes.length ? _bytes.length : end);
  }

  @override
  Future<void> close() async {}
}

/// Passes every decoded chunk to [onAdd].
class _CallbackSink implements Sink<String> {
  final void Function(String chunk) onAdd;

  _CallbackSink(this.onAdd);

  @override
  void add(String data) {
    onAdd(data);
  }

  @override
  void close() {}
}

bool _equalBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Whether [path] is a rotated file of the log at [currentPath] that was
/// compressed. A log file may itself be named `*.gz`.
bool _isCompressedLog(String path, {required String currentPath}) {
  final currentName = File(currentPath).uri.pathSegments.last;
  final dotIndex = currentName.lastIndexOf('.');
  final extension = dotIndex > 0 ? currentName.substring(dotIndex) : '';
  final name = File(path).uri.pathSegments.last;
  return name != currentName && name.endsWith('$extension.gz');
}

String _normalizeDirPath(String path) {
  final separator = Platform.pathSeparator;
  if (!path.endsWith(separator)) return path;
  return path.substring(0, path.length - separator.length);
}

Future<List<String>> _readAllLinesFromFile(
  String path,
  Encoding encoding,
  String recordSeparator, {
  required bool compressed,
}) async {
  if (compressed) {
    final bytes = await File(path).readAsBytes();
    final decompressed = gzip.decode(bytes);
    final text = encoding.decode(decompressed);
    return _splitRecords(text, recordSeparator);
  }

  return File(path)
      .openRead()
      .transform(encoding.decoder)
      .transform(_RecordSplitter(recordSeparator))
      .toList();
}

/// Splits [text] on [separator], dropping a trailing empty entry.
List<String> _splitRecords(String text, String separator) {
  if (text.isEmpty) return [];
  final parts = text.split(separator);
  // If the text ends with the separator, split produces a trailing empty string
  if (parts.isNotEmpty && parts.last.isEmpty) {
    parts.removeLast();
  }
  return parts;
}

const int _fingerprintLength = 64;
const int _chunkSize = 64 * 1024;
const Duration _defaultPollInterval = Duration(milliseconds: 1000);

RotatingFileReader createRotatingFileReader({
  required FutureOr<String> Function() baseFilePathProvider,
  Duration? pollInterval,
  String recordSeparator = '\n',
}) {
  return RotatingFileReaderIo(
    baseFilePathProvider: baseFilePathProvider,
    pollInterval: pollInterval ?? _defaultPollInterval,
    recordSeparator: recordSeparator,
  );
}

/// A [StreamTransformer] that splits a stream of strings on an arbitrary
/// [separator] string, analogous to [LineSplitter] but for custom delimiters.
class _RecordSplitter extends StreamTransformerBase<String, String> {
  final String _separator;

  const _RecordSplitter(this._separator);

  @override
  Stream<String> bind(Stream<String> stream) {
    var partial = '';
    return stream.transform(
      StreamTransformer<String, String>.fromHandlers(
        handleData: (chunk, sink) {
          final text = partial + chunk;
          final parts = text.split(_separator);
          partial = parts.removeLast();
          for (final part in parts) {
            sink.add(part);
          }
        },
        handleDone: (sink) {
          if (partial.isNotEmpty) {
            sink.add(partial);
          }
          sink.close();
        },
      ),
    );
  }
}
