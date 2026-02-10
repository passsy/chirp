import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  /// Creates a temp directory and registers cleanup.
  Directory createTempDir() {
    final dir = Directory.systemTemp.createTempSync('chirp-log-reader-');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  group('listFiles', () {
    test('returns rotated + current sorted oldest->newest', () async {
      final dir = createTempDir();

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

      final reader = RotatingFileReader(baseFilePath: base.path);
      final files = await reader.listFiles();
      expect(files, [rotated1.path, rotated2.path, base.path]);
    });

    test('excludes current file when includeCurrent is false', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old\n');
      base.writeAsStringSync('current\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final files = await reader.listFiles(includeCurrent: false);
      expect(files, [rotated.path]);
    });

    test('returns empty list when directory does not exist', () async {
      final reader = RotatingFileReader(
        baseFilePath: '/tmp/chirp-nonexistent-dir/app.log',
      );
      final files = await reader.listFiles();
      expect(files, isEmpty);
    });

    test('returns empty list when no matching files exist', () async {
      final dir = createTempDir();

      // Create an unrelated file
      File('${dir.path}/unrelated.txt').writeAsStringSync('nope\n');

      final base = File('${dir.path}/app.log');
      final reader = RotatingFileReader(baseFilePath: base.path);
      final files = await reader.listFiles();
      expect(files, isEmpty);
    });

    test('includes compressed .gz rotated files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final gzFile =
          File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final files = await reader.listFiles();
      expect(files, [gzFile.path, base.path]);
    });

    test('ignores unrelated files with similar prefix', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      // These should NOT match
      File('${dir.path}/app.log.bak').writeAsStringSync('backup\n');
      File('${dir.path}/application.log').writeAsStringSync('other\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final files = await reader.listFiles();
      expect(files, [base.path]);
    });
  });

  group('read', () {
    test('reads all files in order', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old1\nold2\n');
      base.writeAsStringSync('new1\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['old1', 'old2', 'new1']);
    });

    test('returns empty stream when no files exist', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('returns empty stream when directory does not exist', () async {
      final reader = RotatingFileReader(
        baseFilePath: '/tmp/chirp-nonexistent-dir/app.log',
      );
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('reads only current file when no rotated files exist', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('line1\nline2\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['line1', 'line2']);
    });

    test('reads empty current file', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('reads file without trailing newline', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('no-trailing-newline');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['no-trailing-newline']);
    });

    test('preserves empty lines', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n\n\nlast\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['first', '', '', 'last']);
    });

    test('reads compressed .gz files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final gzFile =
          File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old1\nold2\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['old1', 'old2', 'current']);
    });

    test('reads mix of plain and compressed files in order', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final rotatedPlain =
          File('${dir.path}/app.2024-01-02_10-00-00.log');
      rotatedPlain.writeAsStringSync('plain\n');

      final rotatedGz =
          File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      rotatedGz.writeAsBytesSync(gzip.encode(utf8.encode('compressed\n')));

      rotatedGz.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotatedPlain.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['compressed', 'plain', 'current']);
    });

    test('reads multiple rotated files across many rotations', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('e\n');

      final r1 = File('${dir.path}/app.2024-01-01_10-00-00.log');
      r1.writeAsStringSync('a\n');
      final r2 = File('${dir.path}/app.2024-01-02_10-00-00.log');
      r2.writeAsStringSync('b\n');
      final r3 = File('${dir.path}/app.2024-01-03_10-00-00.log');
      r3.writeAsStringSync('c\n');
      final r4 = File('${dir.path}/app.2024-01-04_10-00-00.log');
      r4.writeAsStringSync('d\n');

      r1.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      r2.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      r3.setLastModifiedSync(DateTime(2024, 1, 3, 10));
      r4.setLastModifiedSync(DateTime(2024, 1, 4, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 5, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read().toList();
      expect(lines, ['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('read with lastLines', () {
    test('returns last N lines across multiple files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('c1\nc2\n');

      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      rotated.writeAsStringSync('a1\na2\na3\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 3).toList();
      expect(lines, ['a3', 'c1', 'c2']);
    });

    test('returns all lines when lastLines exceeds total', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('one\ntwo\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 100).toList();
      expect(lines, ['one', 'two']);
    });

    test('returns exactly N lines when lastLines equals total', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('one\ntwo\nthree\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 3).toList();
      expect(lines, ['one', 'two', 'three']);
    });

    test('returns single last line', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\nthird\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 1).toList();
      expect(lines, ['third']);
    });

    test('lastLines: 0 returns nothing', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\n');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 0).toList();
      expect(lines, isEmpty);
    });

    test('lastLines with no files returns empty', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 5).toList();
      expect(lines, isEmpty);
    });

    test('lastLines spanning compressed and plain files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('new1\nnew2\n');

      final gzFile =
          File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old1\nold2\nold3\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 4).toList();
      expect(lines, ['old2', 'old3', 'new1', 'new2']);
    });

    test('lastLines with empty files in between', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final emptyRotated =
          File('${dir.path}/app.2024-01-02_10-00-00.log');
      emptyRotated.writeAsStringSync('');

      final oldRotated =
          File('${dir.path}/app.2024-01-01_10-00-00.log');
      oldRotated.writeAsStringSync('old\n');

      oldRotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      emptyRotated.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePath: base.path);
      final lines = await reader.read(lastLines: 2).toList();
      expect(lines, ['old', 'current']);
    });
  });

  group('tail', () {
    test('emits appended lines', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final received = <String>[];
      final reader = RotatingFileReader(baseFilePath: base.path);
      final sub = reader.tail(lastLines: 10).listen(received.add);
      addTearDown(() => sub.cancel());

      // Give the watcher a moment to attach.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Append new content.
      base.writeAsStringSync('second\n', mode: FileMode.append);

      // Wait for the filesystem event + read.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(received, containsAllInOrder(['first', 'second']));
    });

    test('emits historical lines then new lines', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old1\nold2\n');
      base.writeAsStringSync('current\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final received = <String>[];
      final reader = RotatingFileReader(baseFilePath: base.path);
      final sub = reader.tail(lastLines: 2).listen(received.add);
      addTearDown(() => sub.cancel());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      base.writeAsStringSync('appended\n', mode: FileMode.append);

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(received, containsAllInOrder(['old2', 'current', 'appended']));
    });

    test('works when file does not exist yet', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final received = <String>[];
      final reader = RotatingFileReader(baseFilePath: base.path);
      final sub = reader.tail().listen(received.add);
      addTearDown(() => sub.cancel());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Create the file after tail started.
      base.writeAsStringSync('appeared\n');

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(received, contains('appeared'));
    });
  });
}
