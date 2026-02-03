/// Example: Writing logs to files with rotation.
///
/// Run with: dart run bin/file_writer.dart
import 'dart:io';

import 'package:chirp/chirp.dart';

void main() async {
  // Create a temporary directory for the example
  final logDir = Directory.systemTemp.createTempSync('chirp_example_');
  final simplePath = '${logDir.path}/app.log';
  final jsonPath = '${logDir.path}/app.json';

  print('Log directory: ${logDir.path}\n');

  // Simple text format writer
  final simpleWriter = RotatingFileWriter(
    baseFilePath: simplePath,
    formatter: const SimpleFileFormatter(),
    rotationConfig: const FileRotationConfig.size(
      maxSize: 500, // 500 bytes - tiny for demo
      maxFiles: 3,
    ),
  );

  // JSON format writer
  final jsonWriter = RotatingFileWriter(
    baseFilePath: jsonPath,
    formatter: const JsonFileFormatter(),
    rotationConfig: const FileRotationConfig.size(
      maxSize: 500, // 500 bytes - tiny for demo
      maxFiles: 3,
    ),
  );

  // Configure logger to write to both files
  Chirp.root = ChirpLogger()
      .addConsoleWriter()
      .addWriter(simpleWriter)
      .addWriter(jsonWriter);

  // Write enough logs to trigger rotation
  for (var i = 1; i <= 20; i++) {
    Chirp.info(
      'Processing request $i',
      data: {'requestId': 'req_$i', 'userId': 'user_${i % 5}'},
    );
  }

  // Flush and close
  await simpleWriter.close();
  await jsonWriter.close();

  // Show created files
  print('\n--- Created files ---');
  final files = logDir.listSync()..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final size = (file as File).lengthSync();
    print('$name ($size bytes)');
  }

  // Show content of current log files
  print('\n--- app.log (simple format) ---');
  print(File(simplePath).readAsStringSync());

  print('\n--- app.json (JSON format) ---');
  for (final line in File(jsonPath).readAsStringSync().trim().split('\n')) {
    print(line);
  }

  // Cleanup
  // logDir.deleteSync(recursive: true);
}
