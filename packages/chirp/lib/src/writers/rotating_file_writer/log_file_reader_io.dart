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
}) async* {
  final files = await listLogFiles(baseFilePath: baseFilePath);
  if (files.isEmpty) {
    if (!follow) return;
    // If following, keep polling until the file appears.
  }

  if (files.isNotEmpty) {
    for (final path in files) {
      if (path.endsWith('.gz')) {
        final bytes = await File(path).readAsBytes();
        final decompressed = gzip.decode(bytes);
        yield encoding.decode(decompressed);
      } else {
        yield* File(path)
            .openRead()
            .transform(encoding.decoder)
            .transform(const LineSplitter());
      }
    }
  }

  if (!follow) return;

  // Follow current file (baseFilePath) for new lines.
  final file = File(baseFilePath);
  var offset = file.existsSync() ? file.lengthSync() : 0;

  final controller = StreamController<String>();
  Timer? timer;
  String partial = '';

  Future<void> poll() async {
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
  }

  timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
    poll();
  });

  controller.onCancel = () {
    timer?.cancel();
  };

  yield* controller.stream;
}
