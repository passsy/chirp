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
  })  : _baseFilePathProvider = baseFilePathProvider,
        _pollInterval = pollInterval;

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

    final entries = dir
        .listSync()
        .whereType<File>()
        .where((it) {
          final fileName = it.uri.pathSegments.last;
          if (fileName == name) {
            return includeCurrent;
          }
          return isRotatedLogFile(fileName, baseName: baseName);
        })
        .map((it) => (path: it.path, modified: it.statSync().modified))
        .toList()
      ..sort((a, b) => a.modified.compareTo(b.modified));

    return entries.map((e) => e.path).toList(growable: false);
  }

  @override
  Stream<String> read({
    int? lastLines,
    Encoding encoding = utf8,
  }) async* {
    final files = await listFiles();

    // When lastLines is requested, we need to materialize to compute the tail.
    if (lastLines != null) {
      if (lastLines <= 0) return;
      if (files.isEmpty) return;

      var remaining = lastLines;
      final chunks = <List<String>>[];

      for (final path in files.reversed) {
        if (remaining <= 0) break;

        final lines = await _readAllLinesFromFile(path, encoding);
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
        yield* Stream<String>.fromIterable(const LineSplitter().convert(text));
      } else {
        yield* File(path)
            .openRead()
            .transform(encoding.decoder)
            .transform(const LineSplitter());
      }
    }
  }

  @override
  Stream<String> tail({
    int? lastLines,
    Encoding encoding = utf8,
  }) async* {
    yield* read(lastLines: lastLines, encoding: encoding);

    // Follow current file (baseFilePath) for new lines.
    //
    // Implementation note: This primarily reacts to file-system events and
    // uses a lightweight periodic poll as a fallback for filesystems that
    // don't reliably emit change events.
    final resolvedPath = await _resolveBaseFilePath();
    final file = File(resolvedPath);
    final dir = file.parent;
    final fileName = file.uri.pathSegments.last;

    var offset = file.existsSync() ? file.lengthSync() : 0;
    FileStat? lastStat;
    var unchangedIterations = 0;

    final controller = StreamController<String>();
    StreamSubscription<FileSystemEvent>? sub;

    String partial = '';
    var polling = false;

    Future<void> poll() async {
      if (polling) return;
      polling = true;
      try {
        if (!file.existsSync()) {
          offset = 0;
          partial = '';
          lastStat = null;
          unchangedIterations = 0;
          return;
        }

        final stat = file.statSync();
        final length = stat.size;

        if (length < offset) {
          // File got rotated/truncated.
          offset = 0;
          partial = '';
        }

        final hasNewBytes = length > offset;
        final statChanged = lastStat != null &&
            !_statsEqual(lastStat!, stat) &&
            length <= offset;

        if (!hasNewBytes) {
          unchangedIterations++;
          if (statChanged && unchangedIterations >= _maxUnchangedStats) {
            // Follow-by-name fallback: treat as replaced and re-read.
            offset = 0;
            partial = '';
            unchangedIterations = 0;
          } else {
            lastStat = stat;
            return;
          }
        } else {
          unchangedIterations = 0;
        }

        final stream =
            file.openRead(offset, length).transform(encoding.decoder);
        await for (final chunk in stream) {
          final text = partial + chunk;
          final lines = text.split('\n');
          partial = lines.removeLast();
          for (final line in lines) {
            controller.add(line);
          }
        }

        offset = length;
        lastStat = stat;
      } finally {
        polling = false;
      }
    }

    // Initial read if there is already content.
    await poll();

    final pollingTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(poll());
    });

    if (FileSystemEntity.isWatchSupported) {
      final normalizedDirPath = _normalizeDirPath(dir.path);

      bool shouldPoll(FileSystemEvent event) {
        if (event.path.endsWith(fileName)) return true;
        return _normalizeDirPath(event.path) == normalizedDirPath;
      }

      sub = dir.watch().where(shouldPoll).listen((_) {
        // Fire and forget.
        unawaited(poll());
      });
    }

    controller.onCancel = () {
      sub?.cancel();
      pollingTimer.cancel();
    };

    yield* controller.stream;
  }
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
) async {
  if (path.endsWith('.gz')) {
    final bytes = await File(path).readAsBytes();
    final decompressed = gzip.decode(bytes);
    final text = encoding.decode(decompressed);
    return const LineSplitter().convert(text);
  }

  return File(path)
      .openRead()
      .transform(encoding.decoder)
      .transform(const LineSplitter())
      .toList();
}

const int _maxUnchangedStats = 5;
const Duration _defaultPollInterval = Duration(milliseconds: 1000);

RotatingFileReader createRotatingFileReader({
  required FutureOr<String> Function() baseFilePathProvider,
  Duration? pollInterval,
}) {
  return RotatingFileReaderIo(
    baseFilePathProvider: baseFilePathProvider,
    pollInterval: pollInterval ?? _defaultPollInterval,
  );
}
