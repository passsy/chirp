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
  }) : _baseFilePathProvider = baseFilePathProvider;

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
      final lines = <String>[];

      for (final path in files) {
        if (path.endsWith('.gz')) {
          final bytes = await File(path).readAsBytes();
          final decompressed = gzip.decode(bytes);
          final text = encoding.decode(decompressed);
          lines.addAll(const LineSplitter().convert(text));
        } else {
          lines.addAll(
            await File(path)
                .openRead()
                .transform(encoding.decoder)
                .transform(const LineSplitter())
                .toList(),
          );
        }
      }

      final start = (lines.length - lastLines).clamp(0, lines.length);
      for (final line in lines.sublist(start)) {
        yield line;
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
    // Implementation note: This intentionally does NOT use polling by default.
    // Instead it reacts to file-system events and only reads when the file
    // changes (or appears).
    final resolvedPath = await _resolveBaseFilePath();
    final file = File(resolvedPath);
    final dir = file.parent;
    final fileName = file.uri.pathSegments.last;

    var offset = file.existsSync() ? file.lengthSync() : 0;

    final controller = StreamController<String>();
    StreamSubscription<FileSystemEvent>? sub;

    String partial = '';
    var polling = false;

    Future<void> poll() async {
      if (polling) return;
      polling = true;
      try {
        if (!file.existsSync()) return;

        final length = file.lengthSync();
        if (length < offset) {
          // File got rotated/truncated.
          offset = 0;
        }
        if (length == offset) return;

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
      } finally {
        polling = false;
      }
    }

    // Initial read if there is already content.
    await poll();

    if (FileSystemEntity.isWatchSupported) {
      sub = dir.watch().where((e) => e.path.endsWith(fileName)).listen((_) {
        // Fire and forget.
        unawaited(poll());
      });
      controller.onCancel = () {
        sub?.cancel();
      };
    } else {
      // Fallback for platforms/filesystems that don't support watch.
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(poll());
      });
      controller.onCancel = () {
        timer.cancel();
      };
    }

    yield* controller.stream;
  }
}

RotatingFileReader createRotatingFileReader({
  required FutureOr<String> Function() baseFilePathProvider,
}) {
  return RotatingFileReaderIo(baseFilePathProvider: baseFilePathProvider);
}
