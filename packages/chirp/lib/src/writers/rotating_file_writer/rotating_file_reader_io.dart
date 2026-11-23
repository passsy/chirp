import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer_io.dart'
    show LogFileName;
import 'package:clock/clock.dart';

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

    final log = LogFileName(resolvedPath);
    final files = dir.listSync().whereType<File>().map((it) => it.path).toSet();
    final rotated = files.where((it) {
      if (!log.isRotated(it)) {
        return false;
      }
      if (!log.isCompressed(it)) {
        return true;
      }
      // While a rotated file is compressed, both it and its .gz exist, and
      // only the plain file is complete.
      return !files.contains(log.uncompressed(it));
    }).toList()
      ..sort(log.compareRotated);

    final currentPaths = files.where((it) {
      return File(it).uri.pathSegments.last == log.name;
    });
    return [...rotated, if (includeCurrent) ...currentPaths];
  }

  @override
  Stream<String> read({
    int? last,
    Encoding encoding = utf8,
  }) async* {
    final files = await listFiles();
    final log = LogFileName(await _resolveBaseFilePath());

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
          compressed: log.isCompressed(path),
          rotated: log.isRotated(path),
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
        compressed: log.isCompressed(path),
        rotated: log.isRotated(path),
      );
    }
  }

  @override
  Stream<String> tail({
    int? last,
    Encoding encoding = utf8,
  }) async* {
    if (_recordSeparator.isEmpty) {
      throw ArgumentError.value(
        _recordSeparator,
        'recordSeparator',
        'tail needs a separator to find where a record ends',
      );
    }
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
/// Follows the log like `tail -F`. Like Vector and Filebeat, it knows a file
/// by its content, not by its name. Every file the log consists of over time
/// is a generation, identified by its first [_identityLength] bytes and read
/// once from its first to its last byte. A rotation only renames the current
/// file, so the rotated file still starts with the same bytes and is read on
/// where the current file stopped. A compressed file is identified by its
/// decompressed bytes.
///
/// Each pass reads the rotated files in the order of their names, then the
/// current file. The current file is only read when nothing was rotated
/// since the rotated files were listed, so the generations keep their order.
///
/// Limits:
/// - The log must only be appended to. A file rewritten in place is read
///   again from its start when its first bytes changed, otherwise not.
/// - A generation whose first [_identityLength] bytes, or all of them when it
///   is shorter, start like those of an older one is taken for its
///   continuation when the older one is not there anymore.
/// - A rotated file that the retention policy deletes before it was read is
///   gone. Only bytes that a pass saw are reported as missing.
/// - Two short failures to read in polls one interval apart are reported
///   like one failure that lasts.
class _Tail {
  final RotatingFileReaderIo _reader;
  final File _file;
  final LogFileName _log;
  final int? _last;
  final Encoding _encoding;

  /// The encoded record separator. Records are split before they are
  /// decoded, so that a malformed record does not take others with it.
  final List<int> _separator;
  final List<int> _space;
  final _controller = StreamController<String>();

  /// The generations of the last pass, oldest first.
  final _generations = <_Generation>[];

  /// The generation of each rotated file, by its path, while it is unchanged.
  final _known = <String, ({_FileState state, _Generation generation})>{};

  /// The broken archives that were reported, so each is reported once.
  final _reported = <String>{};

  /// Collects the records of the history when only the last ones are wanted,
  /// as the emission of each, so that an undecodable record is only
  /// reported when it is wanted.
  ListQueue<void Function()>? _ring;
  int _ringSize = 0;

  /// Runs while the files can not be read, so that a failure that lasts is
  /// reported, once.
  Stopwatch? _failing;
  bool _failureReported = false;

  Timer? _retry;
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
        _log = LogFileName(file.path),
        _last = last,
        _encoding = encoding,
        _separator = encoding.encode(reader._recordSeparator),
        _space = encoding.encode(' ') {
    _controller.onListen = () {
      unawaited(_run());
    };
    _controller.onResume = () {
      unawaited(_poll());
    };
    _controller.onCancel = () {
      _cancelled = true;
      _retry?.cancel();
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
        if (await _emitLast(count)) {
          _failing = null;
          return;
        }
        // A rotated name holds another file since the history was listed.
        _generations.clear();
        _known.clear();
      } on FileSystemException catch (e, stack) {
        _failed(e, stack);
        _generations.clear();
        _known.clear();
        final retry = Completer<void>();
        _retry = Timer(_reader._pollInterval, retry.complete);
        await retry.future;
      }
    }
  }

  /// Emits the last [count] records of the files as they are when the first
  /// pass ends. Everything written later is followed.
  ///
  /// Returns false without emitting anything when a rotated name holds
  /// another file since it was listed, as the history may have read it.
  Future<bool> _emitLast(int count) async {
    final ring = ListQueue<void Function()>();
    _ring = ring;
    _ringSize = count;
    final List<_RotatedFile>? rotated;
    try {
      rotated = await _pass(skipRotated: true);
    } finally {
      _ring = null;
    }
    if (rotated == null) {
      return true;
    }

    // Only read as far as their records are needed, and decoded like the
    // followed ones.
    final chunks = <List<void Function()>>[];
    var missing = count - ring.length;
    for (final file in rotated.reversed) {
      if (missing <= 0 || _cancelled) {
        break;
      }
      final records = ListQueue<void Function()>();
      _ring = records;
      _ringSize = missing;
      try {
        await _readRotated(file, _Generation());
      } finally {
        _ring = null;
      }
      chunks.add(records.toList());
      missing -= records.length;
    }
    if (_cancelled) {
      return true;
    }
    if (_replacedSince(rotated)) {
      return false;
    }

    final history = [...chunks.reversed.expand((it) => it), ...ring];
    final skip = history.length > count ? history.length - count : 0;
    for (final emit in history.skip(skip)) {
      emit();
    }
    return true;
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
        final rotated = await _pass();
        if (rotated != null) {
          _failing = null;
        }
      } on FileSystemException catch (e, stack) {
        // The next poll continues where this one stopped.
        _failed(e, stack);
      } catch (e, stack) {
        _controller.addError(e, stack);
      }
    } while (_pollAgain && !_cancelled);
    _polling = false;
  }

  /// A file that can not be read for a moment, like one that is locked while
  /// it is rotated, is not reported. One that can not be read for a whole
  /// poll interval is, but only once until a poll succeeds.
  void _failed(FileSystemException error, StackTrace stack) {
    final failing = _failing;
    if (failing == null) {
      _failing = clock.stopwatch()..start();
      _failureReported = false;
      return;
    }
    if (_failureReported) {
      return;
    }
    if (failing.elapsed < _reader._pollInterval) {
      return;
    }
    _failureReported = true;
    _controller.addError(error, stack);
  }

  /// Reads everything that was written since the last pass.
  ///
  /// With [skipRotated], the rotated files are identified but not read.
  /// Returns the rotated files, or null when the pass stopped before its end.
  Future<List<_RotatedFile>?> _pass({bool skipRotated = false}) async {
    while (!_cancelled) {
      final rotated = _listRotated();
      final seen = <_Generation>{};
      for (final file in rotated) {
        if (_stopped) {
          return null;
        }
        final generation = await _identifyRotated(file, seen);
        if (generation == null) {
          continue;
        }
        seen.add(generation);
        if (skipRotated) {
          generation.done = true;
        }
        if (generation.done) {
          continue;
        }
        if (!await _readRotated(file, generation)) {
          return null;
        }
      }
      if (_stopped) {
        return null;
      }

      final current = await _openCurrent();
      try {
        if (_rotatedSince(rotated)) {
          // The opened file may be newer than a rotated file that is not
          // read yet.
          continue;
        }
        final generation =
            current == null ? null : await _identifyCurrent(current, seen);
        if (generation != null) {
          seen.add(generation);
        }
        // The gap comes before the records of the current file.
        _forgetGone(seen);
        if (generation != null) {
          if (!await _readCurrent(current!, generation)) {
            // Rewritten in place while it was read.
            _generations.remove(generation);
            continue;
          }
          if (_stopped) {
            return null;
          }
        }
      } finally {
        await current?.close();
      }

      final paths = rotated.map((it) => it.path).toSet();
      _known.removeWhere((path, _) => !paths.contains(path));
      final states = rotated.map(_brokenKey).toSet();
      _reported.retainWhere(states.contains);
      return rotated;
    }
    return null;
  }

  /// Forgets the generations whose files are gone, and reports those with
  /// bytes that were seen but not read, like a rotated file that the
  /// retention policy deleted while the listener paused.
  ///
  /// Bytes written after the last look are not known, so their loss is not
  /// reported.
  void _forgetGone(Set<_Generation> seen) {
    final gone = _generations.where((it) => !seen.contains(it)).toList();
    _generations.retainWhere(seen.contains);
    if (_ring != null) {
      // The history only promises the records that are there.
      return;
    }
    for (final generation in gone) {
      if (generation.done) {
        // Read to its end, or skipped as history.
        continue;
      }
      if (generation.offset >= generation.size) {
        continue;
      }
      _controller.addError(
        FileSystemException(
          'Deleted before tail read it, '
          '${generation.size - generation.offset} bytes of records are missing',
          generation.path,
        ),
      );
    }
  }

  /// The generation of [file], or null when it can not be identified yet.
  /// [seen] are the generations of other files in this pass.
  Future<_Generation?> _identifyRotated(
    _RotatedFile file,
    Set<_Generation> seen,
  ) async {
    if (_reported.contains(_brokenKey(file))) {
      // A broken archive is not decompressed again until it changes.
      return null;
    }
    // Decompressing the start on every pass would cost, so an unchanged
    // archive keeps its generation. A plain file is identified by its bytes.
    final known = file.compressed ? _known[file.path] : null;
    if (known != null && known.state == file.state) {
      // Forgotten when its file was gone in a pass.
      if (_generations.contains(known.generation)) {
        return known.generation;
      }
    }

    final List<int>? read;
    try {
      read = await _readStart(file);
    } on FormatException catch (e, stack) {
      _reportBroken(file, e, stack);
      return null;
    }
    if (read == null || read.isEmpty) {
      // Deleted, or empty and without records.
      return null;
    }
    final start = read;

    // Generations are rotated in order, so the oldest one that fits.
    final generation = _generations.where((it) {
      if (seen.contains(it) || !it.isStartOf(start)) {
        return false;
      }
      return file.compressed || file.state.size >= it.offset;
    }).firstOrNull;
    final result = generation ?? _addGeneration();
    result
      ..grow(start)
      ..path = file.path;
    if (!file.compressed) {
      result.size = file.state.size;
    }
    _known[file.path] = (state: file.state, generation: result);
    return result;
  }

  /// The generation of the current file, or null when it is empty.
  Future<_Generation?> _identifyCurrent(
    RandomAccessFile current,
    Set<_Generation> seen,
  ) async {
    final length = await current.length();
    final start = await _readBytes(current, 0, _identityLength);
    if (start.isEmpty) {
      return null;
    }

    // The one that was read as the current file is the newest.
    final generation = _generations.where((it) {
      if (it.done || seen.contains(it) || !it.isStartOf(start)) {
        return false;
      }
      return length >= it.offset;
    }).lastOrNull;
    final result = generation ?? _addGeneration();
    result
      ..grow(start)
      ..path = _file.path
      ..size = length;
    return result;
  }

  _Generation _addGeneration() {
    final generation = _Generation();
    _generations.add(generation);
    return generation;
  }

  /// The first [_identityLength] bytes of [file], decompressed. Returns null
  /// when it is deleted.
  Future<List<int>?> _readStart(_RotatedFile file) async {
    if (!file.compressed) {
      try {
        final opened = await File(file.path).open();
        try {
          return await _readBytes(opened, 0, _identityLength);
        } finally {
          await _close(opened);
        }
      } on PathNotFoundException {
        // Compressed since it was listed, or deleted.
      }
    }
    final bytes = <int>[];
    try {
      await for (final chunk in _decompressed(file)) {
        bytes.addAll(chunk);
        if (bytes.length >= _identityLength) {
          break;
        }
      }
    } on PathNotFoundException {
      return null;
    }
    if (bytes.length <= _identityLength) {
      return bytes;
    }
    return bytes.sublist(0, _identityLength);
  }

  /// Reads the rest of [generation] from the rotated [file], and ends it.
  ///
  /// Returns false when the listener paused or cancelled before the end.
  Future<bool> _readRotated(_RotatedFile file, _Generation generation) async {
    if (!file.compressed) {
      try {
        final opened = await File(file.path).open();
        try {
          final start = await _readBytes(opened, 0, generation.start.length);
          if (!generation.isStartOf(start)) {
            // Another file took the name since it was identified. The next
            // pass identifies it, and reports this one as gone.
            return true;
          }
          final length = await opened.length();
          while (generation.offset < length) {
            if (_stopped) {
              return false;
            }
            final bytes = await _readBytes(
              opened,
              generation.offset,
              generation.offset + _chunkSize,
            );
            if (bytes.isEmpty) {
              break;
            }
            _decode(generation, bytes);
          }
        } finally {
          await _close(opened);
        }
        _end(generation);
        return true;
      } on PathNotFoundException {
        // Compressed since it was listed, or deleted.
      }
    }

    try {
      var position = 0;
      await for (final chunk in _decompressed(file)) {
        if (_stopped) {
          return false;
        }
        final end = position + chunk.length;
        if (end > generation.offset) {
          final skip = generation.offset - position;
          _decode(generation, skip > 0 ? chunk.sublist(skip) : chunk);
        }
        position = end;
      }
    } on PathNotFoundException {
      // Deleted by the retention policy.
      return true;
    } on FormatException catch (e, stack) {
      _reportBroken(file, e, stack);
      return true;
    }
    _end(generation);
    return true;
  }

  /// Reads what [current] gained since [generation] was read.
  ///
  /// Returns false when it turns out to be rewritten in place.
  Future<bool> _readCurrent(
    RandomAccessFile current,
    _Generation generation,
  ) async {
    final length = await current.length();
    while (generation.offset < length) {
      if (_stopped) {
        return true;
      }
      final start = await _readBytes(current, 0, generation.start.length);
      if (!generation.isStartOf(start)) {
        return false;
      }
      final bytes = await _readBytes(
        current,
        generation.offset,
        generation.offset + _chunkSize,
      );
      if (bytes.isEmpty) {
        // Truncated meanwhile.
        return false;
      }
      _decode(generation, bytes);
    }
    return true;
  }

  Stream<List<int>> _decompressed(_RotatedFile file) {
    final path = file.compressed ? file.path : '${file.path}.gz';
    return File(path).openRead().transform(gzip.decoder);
  }

  void _decode(_Generation generation, List<int> bytes) {
    final chunkOffset = generation.offset;
    generation.offset += bytes.length;

    // The pending record has no separator, but one may start in its last
    // bytes. Only those are searched again, so a long record costs linear
    // time.
    final carry = _lastBytes(
      generation.pending,
      min(_separator.length - 1, generation.pendingLength),
    );
    final window = Uint8List(carry.length + bytes.length)
      ..setAll(0, carry)
      ..setAll(carry.length, bytes);
    final windowOffset = chunkOffset - carry.length;

    // UTF-8 decodes a byte order mark at the start of a file to nothing, so
    // it can not be a separator there.
    var bom = 0;
    if (chunkOffset == 0 && _encoding is Utf8Codec) {
      if (_indexOf(window, _utf8Bom, 0) == 0) {
        bom = _utf8Bom.length;
      }
    }
    var start = 0;
    while (true) {
      final end = _indexOf(window, _separator, start == 0 ? bom : start);
      if (end < 0) {
        break;
      }
      if (start == 0) {
        // Completes the pending record.
        final recordOffset = chunkOffset - generation.pendingLength;
        final record = _join(
          generation.pending,
          generation.pendingLength - carry.length,
          Uint8List.sublistView(window, 0, end),
        );
        generation.clearPending();
        _emitRecord(record, atFileStart: recordOffset == 0);
      } else {
        _emitRecord(
          Uint8List.sublistView(window, start, end),
          atFileStart: windowOffset + start == 0,
        );
      }
      start = end + _separator.length;
    }

    // The carry is pending already.
    final rest = Uint8List.sublistView(window, max(start, carry.length));
    generation.addPending(rest);
  }

  /// Ends a generation that was read to its last byte. A record without
  /// separator at its end is complete then.
  void _end(_Generation generation) {
    final length = generation.pendingLength;
    if (length > 0) {
      final record = _join(generation.pending, length, const []);
      _emitRecord(record, atFileStart: generation.offset == length);
    }
    generation
      ..clearPending()
      ..done = true;
  }

  void _emitRecord(List<int> bytes, {required bool atFileStart}) {
    void Function() emit;
    try {
      final record = _decodeRecord(bytes, atFileStart: atFileStart);
      emit = () => _controller.add(record);
    } on FormatException catch (e, stack) {
      // Only this record is lost.
      emit = () => _controller.addError(e, stack);
    }

    final ring = _ring;
    if (ring == null) {
      emit();
      return;
    }
    ring.addLast(emit);
    if (ring.length > _ringSize) {
      ring.removeFirst();
    }
  }

  /// Decodes a record like [RotatingFileReaderIo.read] decodes it as part of
  /// its file: only the start of a file can hold a byte order mark.
  String _decodeRecord(List<int> bytes, {required bool atFileStart}) {
    if (atFileStart) {
      return _encoding.decode(bytes);
    }
    // Behind a space, a leading U+FEFF is not taken for a byte order mark.
    final text = _encoding.decode([..._space, ...bytes]);
    return text.substring(1);
  }

  void _reportBroken(_RotatedFile file, Object error, StackTrace stack) {
    if (_reported.add(_brokenKey(file))) {
      _controller.addError(error, stack);
    }
  }

  String _brokenKey(_RotatedFile file) => '${file.path} ${file.state}';

  /// Whether a rotated file appeared since [before] was listed.
  bool _rotatedSince(List<_RotatedFile> before) {
    final byGeneration = {for (final it in before) it.generation: it};
    return _listRotated().any((now) {
      final listed = byGeneration[now.generation];
      if (listed == null) {
        return true;
      }
      // Compressed since, or unchanged.
      return listed.compressed == now.compressed && listed.state != now.state;
    });
  }

  /// Whether a file of [before] changed since it was listed, other than by
  /// its compression or deletion. Then a rotation reused its name.
  bool _replacedSince(List<_RotatedFile> before) {
    final byGeneration = {for (final it in _listRotated()) it.generation: it};
    return before.any((listed) {
      final now = byGeneration[listed.generation];
      if (now == null) {
        return false;
      }
      return listed.compressed == now.compressed && listed.state != now.state;
    });
  }

  /// Returns null when the file does not exist. Other failures, like a
  /// file that is locked for a moment, throw and keep the read state.
  Future<RandomAccessFile?> _openCurrent() async {
    try {
      return await _file.open();
    } on PathNotFoundException {
      return null;
    }
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
        .where(_log.isRotated)
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
        state: (
          size: stat.size,
          modified: stat.modified,
          changed: stat.changed
        ),
      );
    }

    final generations = paths.map(_log.uncompressed).toSet();
    // While a rotated file is compressed, both it and its .gz exist, and
    // only the plain file is complete. It is deleted when the .gz is.
    final rotated = generations.map((it) {
      return stat(it, generation: it) ?? stat('$it.gz', generation: it);
    });
    return rotated.nonNulls.toList()
      ..sort((a, b) => _log.compareRotated(a.generation, b.generation));
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

/// One file of the log over its lifetime, from current to rotated to
/// compressed, and how far it was read.
class _Generation {
  /// Its first bytes, up to [_identityLength]. They identify it.
  List<int> start = const [];

  /// The number of bytes read, decompressed.
  int offset = 0;

  /// The bytes of the record that is not complete yet, as they were read.
  final pending = <Uint8List>[];
  int pendingLength = 0;

  /// Where it was seen last, and its size there, to report it when it is
  /// gone before it was read. The size of a compressed file is not known.
  String? path;
  int size = 0;

  /// Read to its last byte. Only a rotated file ends.
  bool done = false;

  /// Whether a file that starts with [bytes] can be this generation.
  bool isStartOf(List<int> bytes) {
    if (bytes.length < start.length) {
      return false;
    }
    for (var i = 0; i < start.length; i++) {
      if (bytes[i] != start[i]) {
        return false;
      }
    }
    return true;
  }

  void addPending(Uint8List bytes) {
    if (bytes.isEmpty) {
      return;
    }
    pending.add(bytes);
    pendingLength += bytes.length;
  }

  void clearPending() {
    pending.clear();
    pendingLength = 0;
  }

  /// Takes the longer start of a file that grew.
  void grow(List<int> bytes) {
    if (bytes.length > start.length) {
      start = bytes;
    }
  }
}

typedef _FileState = ({int size, DateTime modified, DateTime changed});

/// A rotated file as it was listed.
class _RotatedFile {
  final String path;

  /// The path before it was compressed.
  final String generation;
  final bool compressed;
  final _FileState state;

  _RotatedFile({
    required this.path,
    required this.generation,
    required this.compressed,
    required this.state,
  });
}

/// The bytes of [file] from [start] to [end], or fewer when it ends earlier.
Future<List<int>> _readBytes(RandomAccessFile file, int start, int end) async {
  await file.setPosition(start);
  return await file.read(end - start);
}

Future<void> _close(RandomAccessFile file) async {
  try {
    await file.close();
  } on FileSystemException {
    // Only read, so nothing is lost.
  }
}

const _utf8Bom = [0xEF, 0xBB, 0xBF];

/// The first [length] bytes of [chunks], followed by [tail].
Uint8List _join(List<Uint8List> chunks, int length, List<int> tail) {
  final result = Uint8List(length + tail.length);
  var at = 0;
  for (final chunk in chunks) {
    if (at >= length) {
      break;
    }
    final take = min(chunk.length, length - at);
    result.setRange(at, at + take, chunk);
    at += take;
  }
  result.setAll(length, tail);
  return result;
}

/// The last [count] bytes of [chunks].
List<int> _lastBytes(List<Uint8List> chunks, int count) {
  final bytes = <int>[];
  for (final chunk in chunks.reversed) {
    if (bytes.length >= count) {
      break;
    }
    final take = min(chunk.length, count - bytes.length);
    bytes.insertAll(0, chunk.sublist(chunk.length - take));
  }
  return bytes;
}

/// The index of [pattern] in [data] from [from] on, or -1.
int _indexOf(List<int> data, List<int> pattern, int from) {
  for (var i = from; i <= data.length - pattern.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (data[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return i;
    }
  }
  return -1;
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

/// As much as Filebeat uses to identify a file.
const int _identityLength = 1024;
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
