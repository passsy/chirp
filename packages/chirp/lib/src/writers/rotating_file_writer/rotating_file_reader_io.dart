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

    if (!dir.existsSync()) return const [];

    final files = dir.listSync().whereType<File>().map((it) => it.path).toSet();
    final rotated = files.where((it) {
      if (!_isRotatedLog(it, currentPath: resolvedPath)) {
        return false;
      }
      if (!_isCompressedLog(it, currentPath: resolvedPath)) {
        return true;
      }
      // While a rotated file is compressed, both it and its .gz exist, and
      // only the plain file is complete.
      return !files.contains(it.substring(0, it.length - '.gz'.length));
    }).toList()
      ..sort((a, b) {
        return _compareRotatedLogs(a, b, currentPath: resolvedPath);
      });

    final name = current.uri.pathSegments.last;
    final currentPaths = files.where((it) {
      return File(it).uri.pathSegments.last == name;
    });
    return [...rotated, if (includeCurrent) ...currentPaths];
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

        final lines = await _readRecords(
          path,
          encoding,
          _recordSeparator,
          compressed: _isCompressedLog(path, currentPath: currentPath),
          rotated: _isRotatedLog(path, currentPath: currentPath),
        ).toList();
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
      yield* _readRecords(
        path,
        encoding,
        _recordSeparator,
        compressed: _isCompressedLog(path, currentPath: currentPath),
        rotated: _isRotatedLog(path, currentPath: currentPath),
      );
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
/// A rotation shows as a new rotated file. The followed generation is then
/// finished from its rotated file, and the generations after it are read
/// from their start, oldest first. Without a new rotated file, the current
/// file is the followed generation as long as it has not shrunk and still
/// holds the first and the last bytes that were read.
///
/// Limits:
/// - The log must only be appended to. A file rewritten in place is read
///   again from its start when it got shorter or when the first or the last
///   read [_fingerprintLength] bytes changed, and not otherwise.
/// - A rotated file that the retention policy deleted before it was read is
///   gone.
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
  List<int> _firstBytes = [];
  List<int> _lastBytes = [];

  /// The rotated files that are read, by [_RotatedFile.generation].
  final _seen = <String, _RotatedFile>{};

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

  bool get _stopped => _cancelled || _paused;

  Future<void> _run() async {
    final last = _last;
    if (last != null) {
      // Keeps a poll from reading at the same time.
      _polling = true;
      try {
        await _emitLastWithRetry(last < 0 ? 0 : last);
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

  /// A file that can not be read for a moment must not turn the history
  /// into followed records, so the start is tried again from scratch.
  Future<void> _emitLastWithRetry(int count) async {
    while (!_cancelled) {
      try {
        await _emitLast(count);
        return;
      } on FileSystemException {
        _ring = null;
        _seen.clear();
        _restart();
        await Future<void>.delayed(_reader._pollInterval);
      }
    }
  }

  /// Emits the last [count] records of the files that exist right now.
  /// Everything written or rotated in later is followed.
  Future<void> _emitLast(int count) async {
    final ring = ListQueue<String>();
    _ring = ring;
    _ringSize = count;
    var older = <_RotatedFile>[];
    try {
      final listed = _listRotated();
      final current = await _openCurrent();
      try {
        final listedAgain = _listRotated();
        // A name can be reused, so the files are compared, not the names.
        final rotatedSince = listedAgain.where((it) {
          return !listed.any((before) => _isSameFile(before, it));
        }).toList();
        older = listedAgain.where((it) => !rotatedSince.contains(it)).toList();

        if (rotatedSince.isEmpty) {
          if (current != null) {
            final intact = await _read(current, canPause: false);
            if (!intact) {
              _restart();
            }
          }
        } else {
          // Rotated since the first listing. The file that was current then
          // is the oldest of the new rotated files, whether the rotation
          // happened before or after the open.
          await _readGeneration(
            rotatedSince.first,
            mustContinue: false,
            canPause: false,
          );
        }
      } finally {
        await current?.close();
      }
    } finally {
      _ring = null;
    }

    // Only read as far as their records are needed.
    final chunks = <List<String>>[];
    var missing = count - ring.length;
    for (final rotated in older.reversed) {
      _seen[rotated.generation] = rotated;
      if (missing <= 0 || _cancelled) {
        continue;
      }
      try {
        final lines = await _readRecords(
          rotated.path,
          _encoding,
          _reader._recordSeparator,
          compressed: rotated.compressed,
          rotated: true,
        ).toList();
        chunks.add(lines);
        missing -= lines.length;
      } on FormatException catch (e, stack) {
        // A broken archive. Read when the file changes.
        _controller.addError(e, stack);
      }
    }
    if (_cancelled) {
      return;
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
        // A file vanished while it was read. The next poll continues where
        // this one stopped.
      } catch (e, stack) {
        _controller.addError(e, stack);
      }
    } while (_pollAgain && !_cancelled);
    _polling = false;
  }

  /// Reads everything that was written since the last call.
  Future<void> _step() async {
    while (!_stopped) {
      final List<_RotatedFile> unseen;
      var currentContinues = false;
      final current = await _openCurrent();
      try {
        // Listed after the current file was opened. A rotation after this
        // moves the opened file, which is read to its end through its
        // handle, and shows as a rotated file with the next call.
        unseen = _unseenRotated();
        if (_offset > 0 && current != null) {
          currentContinues = await _continues(current);
        }
        if (unseen.isEmpty) {
          if (_offset > 0 && !currentContinues) {
            // Deleted, truncated or rewritten in place.
            _restart();
          }
          if (current == null) {
            return;
          }
          final intact = await _read(current, canPause: true);
          if (!intact) {
            // Rewritten while it was read.
            _restart();
            continue;
          }
          return;
        }
      } finally {
        // Not kept open while rotated files are read, an open file can not
        // be renamed on Windows.
        await current?.close();
      }
      await _readRotated(unseen, currentContinues: currentContinues);
    }
  }

  /// Reads the next generation of [unseen], which is not empty.
  Future<void> _readRotated(
    List<_RotatedFile> unseen, {
    required bool currentContinues,
  }) async {
    if (_offset == 0) {
      // The oldest generation that is not read yet, from its start.
      await _readGeneration(
        unseen.first,
        mustContinue: false,
        canPause: true,
      );
      return;
    }

    // The followed generation was rotated. Finishes it from its rotated
    // file, also when the new current file starts with the same bytes.
    for (final rotated in unseen) {
      final found = await _readGeneration(
        rotated,
        mustContinue: true,
        canPause: true,
      );
      if (found) {
        return;
      }
    }
    if (currentContinues) {
      // A rotated file that appeared late, like a repaired archive. Reads
      // it on its own and continues with the current file where it was.
      final offset = _offset;
      final partial = _partial;
      final decoder = _decoder;
      final firstBytes = _firstBytes;
      final lastBytes = _lastBytes;
      _restart();
      // Collected and only emitted when the whole file was read. A failed
      // read starts again at its first byte.
      final records = ListQueue<String>();
      _ring = records;
      _ringSize = _unlimited;
      try {
        await _readGeneration(
          unseen.first,
          mustContinue: false,
          canPause: false,
        );
      } finally {
        _ring = null;
        _offset = offset;
        _partial = partial;
        _decoder = decoder;
        _firstBytes = firstBytes;
        _lastBytes = lastBytes;
      }
      for (final record in records) {
        _controller.add(record);
      }
      return;
    }
    // The followed generation is deleted.
    _restart();
  }

  /// Reads [rotated] from [_offset] to its end.
  ///
  /// With [mustContinue], returns false without reading when [rotated] is
  /// not the followed generation.
  Future<bool> _readGeneration(
    _RotatedFile rotated, {
    required bool mustContinue,
    required bool canPause,
  }) async {
    final _Bytes? source;
    try {
      source = await _openRotated(rotated);
    } on FormatException catch (e, stack) {
      // A broken archive. Read again when the file changes.
      _controller.addError(e, stack);
      _seen[rotated.generation] = rotated;
      return false;
    }
    if (source == null) {
      // Deleted since it was listed.
      _seen[rotated.generation] = rotated;
      return false;
    }
    try {
      if (mustContinue && !await _continues(source)) {
        return false;
      }
      final intact = await _read(source, canPause: canPause);
      if (!intact) {
        _restart();
        return true;
      }
      if (_cancelled) {
        return true;
      }
      if (canPause && _paused) {
        // Continues with the next poll.
        return true;
      }
      _finishGeneration();
      _seen[rotated.generation] = rotated;
      return true;
    } finally {
      await source.close();
    }
  }

  /// Decodes [source] from [_offset] to its end, or until the listener
  /// pauses or cancels.
  ///
  /// Returns false when [source] turns out to be rewritten.
  Future<bool> _read(_Bytes source, {required bool canPause}) async {
    final length = await source.length();
    while (_offset < length) {
      if (_cancelled) {
        return true;
      }
      if (canPause && _paused) {
        return true;
      }
      if (_offset > 0 && !await _continues(source)) {
        return false;
      }
      final remaining = length - _offset;
      final count = remaining > _chunkSize ? _chunkSize : remaining;
      final bytes = await source.read(_offset, _offset + count);
      if (bytes.isEmpty) {
        // Shorter than its length said, it was truncated meanwhile.
        return false;
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
    return true;
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
    _firstBytes = [];
    _lastBytes = [];
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

  /// Returns null when the file does not exist. Other failures, like a
  /// file that is locked for a moment, throw and keep the read state.
  Future<_Bytes?> _openCurrent() async {
    try {
      return _FileBytes(await _file.open());
    } on PathNotFoundException {
      return null;
    }
  }

  /// Returns null when the file is deleted. Other failures throw, so that
  /// the file is tried again with the next poll.
  Future<_Bytes?> _openRotated(_RotatedFile rotated) async {
    if (!rotated.compressed) {
      try {
        return _FileBytes(await File(rotated.path).open());
      } on PathNotFoundException {
        // Compressed since it was listed, or deleted.
      }
    }
    final compressedPath =
        rotated.compressed ? rotated.path : '${rotated.path}.gz';
    try {
      final bytes = await File(compressedPath).readAsBytes();
      return _MemoryBytes(gzip.decode(bytes));
    } on PathNotFoundException {
      // Deleted by the retention policy.
      return null;
    }
  }

  /// The rotated files that are not read yet, oldest first.
  List<_RotatedFile> _unseenRotated() {
    final rotated = _listRotated();
    // Forgets deleted files, their names can be used again.
    final generations = rotated.map((it) => it.generation).toSet();
    _seen.removeWhere((generation, _) => !generations.contains(generation));

    return rotated.where((it) {
      final seen = _seen[it.generation];
      if (seen == null) {
        return true;
      }
      if (!_isSameFile(seen, it)) {
        return true;
      }
      // Remembers the compressed form, for the next comparison.
      _seen[it.generation] = it;
      return false;
    }).toList();
  }

  /// Whether [now] is the file that was listed as [before].
  bool _isSameFile(_RotatedFile before, _RotatedFile now) {
    if (before.generation != now.generation) {
      return false;
    }
    if (before.compressed != now.compressed) {
      // Compressed since. A plain file in place of a compressed one is
      // another file with a reused name.
      return now.compressed;
    }
    // The change time tells two files apart when size and modification
    // time are equal.
    return before.size == now.size &&
        before.modified == now.modified &&
        before.changed == now.changed;
  }

  /// The rotated files, oldest first.
  List<_RotatedFile> _listRotated() {
    final dir = _file.parent;
    if (!dir.existsSync()) {
      return const [];
    }
    final paths = dir
        .listSync()
        .whereType<File>()
        .map((it) => it.path)
        .where((it) => _isRotatedLog(it, currentPath: _file.path))
        .toSet();

    _RotatedFile? stat(String path, {required String generation}) {
      final stat = File(path).statSync();
      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }
      return _RotatedFile(
        path: path,
        generation: generation,
        compressed: path != generation,
        size: stat.size,
        modified: stat.modified,
        changed: stat.changed,
      );
    }

    final generations = paths.map((it) {
      if (_isCompressedLog(it, currentPath: _file.path)) {
        return it.substring(0, it.length - '.gz'.length);
      }
      return it;
    }).toSet();

    final rotated = <_RotatedFile>[];
    for (final generation in generations) {
      // While a rotated file is compressed, both it and its .gz exist, and
      // only the plain file is complete. It is deleted when the .gz is.
      final file = stat(generation, generation: generation) ??
          stat('$generation.gz', generation: generation);
      if (file != null) {
        rotated.add(file);
      }
    }
    rotated.sort((a, b) {
      return _compareRotatedLogs(
        a.generation,
        b.generation,
        currentPath: _file.path,
      );
    });
    return rotated;
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

    // Every change in the directory can be a write or a rotation.
    _watcher = dir.watch().listen(
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

/// A rotated file as it was listed.
class _RotatedFile {
  final String path;

  /// The path before it was compressed.
  final String generation;
  final bool compressed;
  final int size;
  final DateTime modified;
  final DateTime changed;

  _RotatedFile({
    required this.path,
    required this.generation,
    required this.compressed,
    required this.size,
    required this.modified,
    required this.changed,
  });
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
  final current = _LogName(currentPath);
  final name = File(path).uri.pathSegments.last;
  return name != current.name && name.endsWith('${current.extension}.gz');
}

/// Whether [path] is a rotated file of the log at [currentPath].
bool _isRotatedLog(String path, {required String currentPath}) {
  final current = _LogName(currentPath);
  final name = File(path).uri.pathSegments.last;
  if (name == current.name) {
    return false;
  }
  return isRotatedLogFile(
    name,
    baseName: current.baseName,
    extension: current.extension,
  );
}

final _rotationPattern =
    RegExp(r'^(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})(?:_(\d+))?');

/// Orders rotated files of the log at [currentPath] from old to new, by the
/// time and the counter in their names. The modification time does not say
/// it, compressing a file changes it.
int _compareRotatedLogs(String a, String b, {required String currentPath}) {
  final current = _LogName(currentPath);

  ({String time, int counter}) rotation(String path) {
    final name = File(path).uri.pathSegments.last;
    final rest = name.substring(current.baseName.length + 1);
    final match = _rotationPattern.firstMatch(rest);
    if (match == null) {
      return (time: '', counter: 0);
    }
    return (
      time: match.group(1) ?? '',
      counter: int.parse(match.group(2) ?? '0'),
    );
  }

  final rotationA = rotation(a);
  final rotationB = rotation(b);
  final byTime = rotationA.time.compareTo(rotationB.time);
  if (byTime != 0) {
    return byTime;
  }
  return rotationA.counter.compareTo(rotationB.counter);
}

/// The parts of the name of a log file.
class _LogName {
  final String name;
  final String baseName;
  final String extension;

  factory _LogName(String path) {
    final name = File(path).uri.pathSegments.last;
    final dotIndex = name.lastIndexOf('.');
    return _LogName._(
      name: name,
      baseName: dotIndex > 0 ? name.substring(0, dotIndex) : name,
      extension: dotIndex > 0 ? name.substring(dotIndex) : '',
    );
  }

  _LogName._({
    required this.name,
    required this.baseName,
    required this.extension,
  });
}

/// The records of the log file at [path].
///
/// A rotated file can be compressed or deleted by the retention policy after
/// it was listed. Its `.gz` is read then, or nothing.
Stream<String> _readRecords(
  String path,
  Encoding encoding,
  String recordSeparator, {
  required bool compressed,
  required bool rotated,
}) async* {
  if (compressed) {
    final List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on PathNotFoundException {
      return;
    }
    final text = encoding.decode(gzip.decode(bytes));
    yield* Stream<String>.fromIterable(_splitRecords(text, recordSeparator));
    return;
  }

  final records = File(path)
      .openRead()
      .transform(encoding.decoder)
      .transform(_RecordSplitter(recordSeparator));
  try {
    await for (final record in records) {
      yield record;
    }
  } on PathNotFoundException {
    if (!rotated) {
      rethrow;
    }
    yield* _readRecords(
      '$path.gz',
      encoding,
      recordSeparator,
      compressed: true,
      rotated: true,
    );
  }
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
const int _unlimited = 1 << 62;
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
