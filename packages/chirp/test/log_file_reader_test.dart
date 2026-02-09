import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('log file reader', () {
    test('listLogFiles returns rotated + current sorted oldest->newest',
        () async {
      final dir = Directory.systemTemp.createTempSync('chirp-log-reader-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final base = File('${dir.path}/app.log');
      final rotated1 = File('${dir.path}/app.2024-01-01_10-00-00.log');
      final rotated2 = File('${dir.path}/app.2024-01-02_10-00-00.log');

      rotated2.writeAsStringSync('r2\n');
      rotated1.writeAsStringSync('r1\n');
      base.writeAsStringSync('current\n');

      // Make modified times deterministic.
      rotated1.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotated2.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final files = await listLogFiles(baseFilePath: base.path);
      expect(files, [rotated1.path, rotated2.path, base.path]);
    });

    test('readLogs reads all files in order', () async {
      final dir = Directory.systemTemp.createTempSync('chirp-log-reader-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old1\nold2\n');
      base.writeAsStringSync('new1\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final lines = await readLogs(baseFilePath: base.path).toList();
      expect(lines, ['old1', 'old2', 'new1']);
    });

    test('readLogs(follow:true) emits appended lines', () async {
      final dir = Directory.systemTemp.createTempSync('chirp-log-reader-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final received = <String>[];
      final sub =
          readLogs(baseFilePath: base.path, follow: true).listen(received.add);
      addTearDown(() => sub.cancel());

      // Wait for initial read.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Append new content.
      base.writeAsStringSync('second\n', mode: FileMode.append);

      // Wait for polling interval.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(received, containsAllInOrder(['first', 'second']));
    });
  });
}
