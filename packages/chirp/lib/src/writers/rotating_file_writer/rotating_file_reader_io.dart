import 'dart:async';
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

    // When last is requested, we need to materialize to compute the tail.
    if (last != null) {
      if (last <= 0) return;
      if (files.isEmpty) return;

      var remaining = last;
      final chunks = <List<String>>[];

      for (final path in files.reversed) {
        if (remaining <= 0) break;

        final lines =
            await _readAllLinesFromFile(path, encoding, _recordSeparator);
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
      if (path.endsWith('.gz')) {
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
    final resolvedPath = await _resolveBaseFilePath();
    final file = File(resolvedPath);
    final dir = file.parent;
    final fileName = file.uri.pathSegments.last;

    // One decoder reads the current file from its first byte on, for the
    // history and for the follow. The follow continues where the history
    // stopped, so no record is lost, emitted twice or cut in two.
    var offset = 0;
    var partial = '';
    final records = <String>[];
    FileStat? lastStat;
    // The last bytes read before offset, to recognize a replaced file.
    final lastBytes = <int>[];

    Sink<List<int>> newDecoder() {
      return encoding.decoder.startChunkedConversion(
        _CallbackSink((chunk) {
          final parts = (partial + chunk).split(_recordSeparator);
          partial = parts.removeLast();
          records.addAll(parts);
        }),
      );
    }

    var decoder = newDecoder();

    // Starts over at the first byte of a new or replaced current file.
    void restart() {
      offset = 0;
      partial = '';
      decoder = newDecoder();
      lastStat = null;
      lastBytes.clear();
    }

    // Whether the file still holds the bytes that were read before offset.
    // A new file that already grew past offset looks like an append otherwise.
    Future<bool> isSameFile(int length) async {
      if (length < offset) {
        // File got rotated/truncated.
        return false;
      }
      final start = offset - lastBytes.length;
      final chunks = await file.openRead(start, offset).toList();
      final bytes = chunks.expand((it) => it).toList();
      if (bytes.length != lastBytes.length) {
        return false;
      }
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != lastBytes[i]) {
          return false;
        }
      }
      return true;
    }

    // Decodes what the current file gained since the last call into records.
    // An incomplete record or character waits for the rest of it.
    Future<void> readCurrent() async {
      final stat = file.statSync();
      if (stat.type == FileSystemEntityType.notFound) {
        restart();
        return;
      }

      final previous = lastStat;
      if (previous != null && _statsEqual(previous, stat)) {
        return;
      }

      final length = stat.size;
      try {
        if (!await isSameFile(length)) {
          restart();
        }
        await for (final bytes in file.openRead(offset, length)) {
          // Counts the bytes that were really read, the file may have been
          // replaced by a shorter one since the stat.
          offset += bytes.length;
          lastBytes.addAll(bytes);
          if (lastBytes.length > _fingerprintLength) {
            lastBytes.removeRange(0, lastBytes.length - _fingerprintLength);
          }
          decoder.add(bytes);
        }
      } on FileSystemException {
        // Deleted between the stat and the read.
        restart();
        return;
      } catch (_) {
        // Undecodable bytes. Continue behind this chunk with a fresh decoder.
        partial = '';
        decoder = newDecoder();
        rethrow;
      }
      lastStat = stat;
    }

    // While a rotated file is compressed, both it and its .gz exist.
    Future<List<String>> rotatedFiles() async {
      final files = await listFiles(includeCurrent: false);
      final all = files.toSet();
      return files.where((it) {
        return !it.endsWith('.gz') || !all.contains(_withoutGz(it));
      }).toList();
    }

    Future<List<String>> readRotated(String path) async {
      try {
        return await _readAllLinesFromFile(path, encoding, _recordSeparator);
      } on FileSystemException {
        if (path.endsWith('.gz')) {
          // Deleted by the retention policy.
          return const [];
        }
        // Compressed since it was listed.
        return readRotated('$path.gz');
      }
    }

    // A rotation moves the records of the current file into a new rotated
    // file. The history is only complete and free of duplicates when no
    // rotated file appeared while it was read, so it is read again until
    // that holds.
    final seen = <String>{};
    Future<bool> rotatedSince() async {
      final files = await rotatedFiles();
      return files.any((it) => !seen.contains(_withoutGz(it)));
    }

    if (last == null) {
      // Streams the rotated files, and after a rotation only the new ones.
      while (true) {
        for (final path in await rotatedFiles()) {
          if (seen.add(_withoutGz(path))) {
            yield* Stream.fromIterable(await readRotated(path));
          }
        }
        restart();
        records.clear();
        await readCurrent();
        if (!await rotatedSince()) {
          break;
        }
      }
    } else {
      final count = last < 0 ? 0 : last;
      while (true) {
        final rotated = await rotatedFiles();
        seen
          ..clear()
          ..addAll(rotated.map(_withoutGz));
        restart();
        records.clear();
        await readCurrent();

        final older = <List<String>>[];
        var missing = count - records.length;
        for (final path in rotated.reversed) {
          if (missing <= 0) {
            break;
          }
          final lines = await readRotated(path);
          older.add(lines);
          missing -= lines.length;
        }
        if (await rotatedSince()) {
          continue;
        }

        final history = [...older.reversed.expand((it) => it), ...records];
        final skip = history.length > count ? history.length - count : 0;
        records
          ..clear()
          ..addAll(history.skip(skip));
        break;
      }
    }

    final history = [...records];
    records.clear();
    yield* Stream.fromIterable(history);

    // Follow current file (baseFilePath) for new lines.
    //
    // Implementation note: This primarily reacts to file-system events and
    // uses a lightweight periodic poll as a fallback for filesystems that
    // don't reliably emit change events.
    final controller = StreamController<String>();
    StreamSubscription<FileSystemEvent>? sub;

    var polling = false;
    var pollAgain = false;

    void emitRecords() {
      for (final record in records) {
        controller.add(record);
      }
      records.clear();
    }

    Future<void> poll() async {
      if (polling) {
        // The running poll may already be past the new bytes.
        pollAgain = true;
        return;
      }
      polling = true;
      do {
        pollAgain = false;
        try {
          await readCurrent();
        } catch (e, stack) {
          emitRecords();
          controller.addError(e, stack);
        }
        emitRecords();
      } while (pollAgain);
      polling = false;
    }

    // The directory may not exist yet, or may be replaced later.
    void watch() {
      if (sub != null) {
        return;
      }
      if (!FileSystemEntity.isWatchSupported || !dir.existsSync()) {
        return;
      }
      final normalizedDirPath = _normalizeDirPath(dir.path);

      bool shouldPoll(FileSystemEvent event) {
        if (event.path.endsWith(fileName)) return true;
        return _normalizeDirPath(event.path) == normalizedDirPath;
      }

      sub = dir.watch().where(shouldPoll).listen(
        (_) {
          // Fire and forget.
          unawaited(poll());
        },
        onError: (Object _) {
          // The periodic poll takes over until the directory is back.
          sub?.cancel();
          sub = null;
        },
        onDone: () {
          sub = null;
        },
      );
    }

    watch();
    await poll();

    final pollingTimer = Timer.periodic(_pollInterval, (_) {
      watch();
      unawaited(poll());
    });

    controller.onCancel = () {
      sub?.cancel();
      pollingTimer.cancel();
    };

    yield* controller.stream;
  }
}

String _withoutGz(String path) {
  if (!path.endsWith('.gz')) {
    return path;
  }
  return path.substring(0, path.length - '.gz'.length);
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

String _normalizeDirPath(String path) {
  final separator = Platform.pathSeparator;
  if (!path.endsWith(separator)) return path;
  return path.substring(0, path.length - separator.length);
}

bool _statsEqual(FileStat previous, FileStat current) {
  if (previous.size != current.size) return false;
  if (previous.modified != current.modified) return false;
  if (previous.changed != current.changed) return false;
  if (previous.mode != current.mode) return false;
  if (previous.type != current.type) return false;
  return true;
}

Future<List<String>> _readAllLinesFromFile(
  String path,
  Encoding encoding,
  String recordSeparator,
) async {
  if (path.endsWith('.gz')) {
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
