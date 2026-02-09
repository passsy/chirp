import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<List<String>> listLogFiles({
  required String baseFilePath,
  bool includeCurrent = true,
}) async {
  final current = File(baseFilePath);
  final dir = current.parent;
  final name = current.uri.pathSegments.last;

  if (!dir.existsSync()) return const [];

  final dotIndex = name.lastIndexOf('.');
  final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;

  final entries = <({String path, DateTime modified})>[];

  for (final entity in dir.listSync().whereType<File>()) {
    final fileName = entity.uri.pathSegments.last;

    if (fileName == name) {
      if (includeCurrent) {
        entries.add((path: entity.path, modified: entity.statSync().modified));
      }
      continue;
    }

    final isRotated = fileName.startsWith('$baseName.') &&
        (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(fileName) ||
            fileName.endsWith('.gz'));

    if (!isRotated) continue;

    entries.add((path: entity.path, modified: entity.statSync().modified));
  }

  // Oldest -> newest
  entries.sort((a, b) => a.modified.compareTo(b.modified));

  return entries.map((e) => e.path).toList(growable: false);
}

Stream<String> readLogs({
  required String baseFilePath,
  bool follow = false,
  Encoding encoding = utf8,
  DateTime? since,
  int? lastLines,
}) async* {
  final allFiles = await listLogFiles(baseFilePath: baseFilePath);

  // Filter by mtime if requested.
  final files = since == null
      ? allFiles
      : allFiles.where((p) {
          final f = File(p);
          if (!f.existsSync()) return false;
          return !f.statSync().modified.isBefore(since);
        }).toList(growable: false);

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

    if (!follow) return;
  } else {
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

    if (!follow) return;
  }

  if (!follow) return;

  // Follow current file (baseFilePath) for new lines.
  //
  // Implementation note: This intentionally does NOT use polling by default.
  // Instead it reacts to file-system events and only reads when the file
  // changes (or appears).
  final file = File(baseFilePath);
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

      final stream = file.openRead(offset, length).transform(encoding.decoder);
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

  Future<void> startWatching() async {
    sub = dir
        .watch(events: FileSystemEvent.all)
        .where((e) => e.path.endsWith(fileName))
        .listen((_) {
      // Fire and forget.
      unawaited(poll());
    });
  }

  try {
    await startWatching();
  } catch (_) {
    // Fallback for platforms/filesystems that don't support watch reliably.
    // Still keep this cheap: poll only every 1s.
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(poll());
    });
    controller.onCancel = () {
      timer.cancel();
    };
  }

  controller.onCancel = () {
    sub?.cancel();
  };

  yield* controller.stream;
}
