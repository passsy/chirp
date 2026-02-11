import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader_io.dart'
    as io_impl;
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader_stub.dart'
    as stub_impl;
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  /// Creates a temp directory and registers cleanup.
  Directory createTempDir() {
    final dir = Directory.systemTemp.createTempSync('chirp-log-reader-');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  test('createRotatingFileReader has same signature in io and stub', () {
    // Both conditional import files must have identical signatures.
    // Cross-assigning verifies they are the same type. A signature mismatch
    // in either file causes a compile error here.
    // ignore: unused_local_variable
    var fn = io_impl.createRotatingFileReader;
    fn = stub_impl.createRotatingFileReader;

    var fn2 = stub_impl.createRotatingFileReader;
    fn2 = io_impl.createRotatingFileReader;

    // Suppress unused variable warning
    expect(fn, isNotNull);
    expect(fn2, isNotNull);
  });

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

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
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

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles(includeCurrent: false);
      expect(files, [rotated.path]);
    });

    test('returns empty list when directory does not exist', () async {
      final reader = RotatingFileReader(
        baseFilePathProvider: () => '/tmp/chirp-nonexistent-dir/app.log',
      );
      final files = await reader.listFiles();
      expect(files, isEmpty);
    });

    test('returns empty list when no matching files exist', () async {
      final dir = createTempDir();

      // Create an unrelated file
      File('${dir.path}/unrelated.txt').writeAsStringSync('nope\n');

      final base = File('${dir.path}/app.log');
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles();
      expect(files, isEmpty);
    });

    test('includes compressed .gz rotated files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final gzFile = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
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

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
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

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['old1', 'old2', 'new1']);
    });

    test('returns empty stream when no files exist', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('returns empty stream when directory does not exist', () async {
      final reader = RotatingFileReader(
        baseFilePathProvider: () => '/tmp/chirp-nonexistent-dir/app.log',
      );
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('reads only current file when no rotated files exist', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('line1\nline2\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['line1', 'line2']);
    });

    test('reads empty current file', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('reads file without trailing newline', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('no-trailing-newline');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['no-trailing-newline']);
    });

    test('preserves empty lines', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n\n\nlast\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['first', '', '', 'last']);
    });

    test('reads compressed .gz files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final gzFile = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old1\nold2\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['old1', 'old2', 'current']);
    });

    test('reads mix of plain and compressed files in order', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final rotatedPlain = File('${dir.path}/app.2024-01-02_10-00-00.log');
      rotatedPlain.writeAsStringSync('plain\n');

      final rotatedGz = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      rotatedGz.writeAsBytesSync(gzip.encode(utf8.encode('compressed\n')));

      rotatedGz.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotatedPlain.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
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

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('read with last', () {
    test('returns last N records across multiple files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('c1\nc2\n');

      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      rotated.writeAsStringSync('a1\na2\na3\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 3).toList();
      expect(lines, ['a3', 'c1', 'c2']);
    });

    test('returns all records when last exceeds total', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('one\ntwo\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 100).toList();
      expect(lines, ['one', 'two']);
    });

    test('returns exactly N records when last equals total', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('one\ntwo\nthree\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 3).toList();
      expect(lines, ['one', 'two', 'three']);
    });

    test('returns single last record', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\nthird\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 1).toList();
      expect(lines, ['third']);
    });

    test('last: 0 returns nothing', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 0).toList();
      expect(lines, isEmpty);
    });

    test('last with no files returns empty', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 5).toList();
      expect(lines, isEmpty);
    });

    test('last spanning compressed and plain files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('new1\nnew2\n');

      final gzFile = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(
        gzip.encode(utf8.encode('old1\nold2\nold3\n')),
      );

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 4).toList();
      expect(lines, ['old2', 'old3', 'new1', 'new2']);
    });

    test('last with empty files in between', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final emptyRotated = File('${dir.path}/app.2024-01-02_10-00-00.log');
      emptyRotated.writeAsStringSync('');

      final oldRotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      oldRotated.writeAsStringSync('old\n');

      oldRotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      emptyRotated.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 2).toList();
      expect(lines, ['old', 'current']);
    });
  });

  group('tail', () {
    test('emits appended lines', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final received = <String>[];
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final sub = reader.tail(last: 10).listen(received.add);
      addTearDown(() => sub.cancel());

      // Append new content.
      base.writeAsStringSync('second\n', mode: FileMode.append, flush: true);

      // Wait for the filesystem event + read.
      await Future<void>.delayed(const Duration(milliseconds: 10));

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

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final tailFuture = reader.tail(last: 2).take(3).toList();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      base.writeAsStringSync('appended\n', mode: FileMode.append, flush: true);
      final received = await tailFuture;
      expect(received, containsAllInOrder(['old2', 'current', 'appended']));
    });

    test('emits lines after truncation', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\n');

      const pollInterval = Duration(milliseconds: 30);
      final received = <String>[];
      final reader = RotatingFileReader(
        baseFilePathProvider: () => base.path,
        pollInterval: pollInterval,
      );
      final sub = reader.tail(last: 0).listen(received.add);
      addTearDown(() => sub.cancel());

      // Truncate file to simulate rotation/truncation.
      base.writeAsStringSync('', flush: true);
      // Let the poller observe the truncation.
      await Future<void>.delayed(pollInterval);

      // Append new content after truncation.
      base.writeAsStringSync('after\n', mode: FileMode.append, flush: true);
      await Future<void>.delayed(pollInterval);
      expect(received, contains('after'));
    });

    test('works when file does not exist yet', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final received = <String>[];
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final sub = reader.tail().listen(received.add);
      addTearDown(() => sub.cancel());

      // Create the file after tail started.
      base.writeAsStringSync('appeared\n');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, contains('appeared'));
    });
  });

  group('recordSeparator', () {
    test('write and read multi-line record round-trips as single record',
        () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write a record that contains embedded newlines (like a stack trace).
      final record = testRecord(
        message: 'Something failed',
        level: ChirpLogLevel.error,
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      );
      writer.write(record);
      await writer.flush();

      // Read back through the writer's reader (uses matching separator).
      final records = await writer.reader.read().toList();
      expect(records, hasLength(1),
          reason: 'Multi-line record should be read back as a single entry');
      expect(records.first, contains('Something failed'));
      expect(records.first, contains('boom'));
      expect(records.first, contains('rotating_file_reader_test.dart'),
          reason: 'Stack trace should be part of the same record');
    });

    test('tail emits complete multi-line records', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write a multi-line record (error with stack trace).
      writer.write(testRecord(
        message: 'Error with trace',
        level: ChirpLogLevel.error,
        error: Exception('fail'),
        stackTrace: StackTrace.current,
      ));
      await writer.flush();

      // Take exactly 1 record from tail — completes once the record arrives.
      final records = await writer.reader.tail().take(1).toList();

      expect(records, hasLength(1),
          reason: 'Should emit exactly one record for a multi-line entry');
      expect(records.first, contains('Error with trace'));
      expect(records.first, contains('fail'));
    });

    test('backward compat with recordSeparator "\\n" behaves like LineSplitter',
        () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      // Write files with plain newline separator (old format).
      base.writeAsStringSync('line1\nline2\nline3\n');

      final reader = RotatingFileReader(
        baseFilePathProvider: () => base.path,
        recordSeparator: '\n',
      );
      final lines = await reader.read().toList();
      expect(lines, ['line1', 'line2', 'line3']);
    });

    test('read(last: N) returns N multi-line records, not N lines', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write 5 multi-line records (each contains embedded newlines).
      for (var i = 0; i < 5; i++) {
        writer.write(testRecord(
          message: 'Heartbeat #$i\nAll systems operational.',
          level: ChirpLogLevel.info,
        ));
      }
      await writer.flush();

      // Ask for the last 3 records.
      final records = await writer.reader.read(last: 3).toList();
      expect(records, hasLength(3),
          reason: 'last: 3 should return 3 records, not 3 lines');
      for (var i = 0; i < 3; i++) {
        expect(records[i], contains('Heartbeat #${i + 2}'));
        expect(records[i], contains('All systems operational.'),
            reason: 'Each record should contain the full multi-line message');
      }
    });

    test('tail(last: N) returns N multi-line records, not N lines', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write 5 multi-line records.
      for (var i = 0; i < 5; i++) {
        writer.write(testRecord(
          message: 'Heartbeat #$i\nAll systems operational.',
          level: ChirpLogLevel.info,
        ));
      }
      await writer.flush();

      // Tail the last 3 records, then take only those 3 (don't wait for new).
      final records = await writer.reader.tail(last: 3).take(3).toList();
      expect(records, hasLength(3),
          reason: 'last: 3 should return 3 records, not 3 lines');
      for (var i = 0; i < 3; i++) {
        expect(records[i], contains('Heartbeat #${i + 2}'));
        expect(records[i], contains('All systems operational.'),
            reason: 'Each record should contain the full multi-line message');
      }
    });

    test('JsonLogFormatter uses newline separator (no \\x1E)', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: const JsonLogFormatter(),
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Hello'));
      writer.write(testRecord(message: 'World'));
      await writer.flush();

      final content = File(logPath).readAsStringSync();
      // JsonLogFormatter inherits default '\n' separator, no \x1E
      expect(content, isNot(contains('\x1E')));
      // Each line ends with \n
      final lines = content.split('\n')..removeWhere((s) => s.isEmpty);
      expect(lines, hasLength(2));
      expect(jsonDecode(lines[0]), containsPair('message', 'Hello'));
      expect(jsonDecode(lines[1]), containsPair('message', 'World'));
    });
  });
}
