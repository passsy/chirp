/// Example: Tailing log files with RotatingFileReader.
///
/// Writes a log every second and tails the file with RotatingFileReader,
/// dumping new lines to stdout as they appear.
///
/// Run with: dart run bin/file_reader.dart
import 'dart:async';
import 'dart:io';

import 'package:chirp/chirp.dart';

void main() async {
  final logDir = Directory.systemTemp.createTempSync('chirp_tail_example_');
  final logPath = '${logDir.path}/app.log';

  print('Log file: $logPath\n');

  // Writer: logs to file with small rotation for demo
  final writer = RotatingFileWriter(
    baseFilePathProvider: () => logPath,
    formatter: const SimpleFileFormatter(),
    rotationConfig: FileRotationConfig.size(
      maxSize: 500, // tiny – rotates quickly for demo
      maxFiles: 3,
    ),
  );

  // Logger that writes to the file
  final logger = ChirpLogger(name: 'HeartbeatService').addWriter(writer);

  // Reader: tail the same file, printing every line to stdout
  final reader = RotatingFileReader(baseFilePathProvider: () => logPath);
  final subscription = reader.tail(lastLines: 20).listen(stdout.writeln);

  // Write a log line every second
  var counter = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
    counter++;
    logger.info('Heartbeat #$counter');
  });

  // Run until Ctrl-C
  final exitSignal = Completer<void>();
  ProcessSignal.sigint.watch().first.then((_) => exitSignal.complete());

  print('Writing a log every second. Press Ctrl-C to stop.\n');
  await exitSignal.future;

  timer.cancel();
  await subscription.cancel();
  await writer.close();
  logDir.deleteSync(recursive: true);
}
