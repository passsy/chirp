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
  final logDir = '${Directory.systemTemp.absolute.path}/chirp_reader_example';
  final logPath = '${logDir}/app.log';

  print('Log file: $logPath\n');

  // Writer: logs to file with small rotation for demo
  final writer = RotatingFileWriter(
    baseFilePathProvider: () => logPath,
    formatter: const SimpleFileFormatter(),
    rotationConfig: FileRotationConfig.size(
      maxSize: 1000, // tiny – rotates quickly for demo
      maxFiles: 5,
    ),
  );

  // Logger that writes to the file
  final logger = ChirpLogger(name: 'HeartbeatService').addWriter(writer);

  // Reader: tail the same file, printing every line to stdout
  final subscription = writer.reader.tail(last: 19).listen(stdout.writeln);

  // Write a log line every second
  var counter = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
    counter++;
    logger.info('Heartbeat #$counter\n'
        '${counter % 3 == 0 ? 'All systems operational.' : 'Minor issue detected, investigating.'}');
  });

  // Run until Ctrl-C
  final exitSignal = Completer<void>();
  ProcessSignal.sigint.watch().first.then((_) => exitSignal.complete());

  print('Writing a log every second. Press Ctrl-C to stop.\n');
  await exitSignal.future;

  timer.cancel();
  await subscription.cancel();
  await writer.close();
  Directory(logDir).deleteSync(recursive: true);
}
