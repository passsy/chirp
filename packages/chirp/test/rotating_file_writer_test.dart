import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer_io.dart'
    as io_impl;
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer_stub.dart'
    as stub_impl;
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'fake_async_with_drain.dart';
import 'test_log_record.dart';

void main() {
  group('SimpleFileFormatter', () {
    test('requiresCallerInfo defaults to false', () {
      const formatter = SimpleFileFormatter();

      expect(formatter.requiresCallerInfo, isFalse);
    });

    test('formats basic log record with timestamp, level, and message', () {
      const formatter = SimpleFileFormatter();
      final record = testRecord(
        message: 'Hello, World!',
        timestamp: DateTime(2024, 1, 15, 10, 30, 45, 123),
      );

      final result = formatRecord(formatter, record);

      expect(
        result,
        equals('2024-01-15T10:30:45.123 [INFO    ] Hello, World!'),
      );
    });

    test('includes logger name when present', () {
      const formatter = SimpleFileFormatter();
      final record = testRecord(
        message: 'Test',
        loggerName: 'MyApp.Service',
      );

      final result = formatRecord(formatter, record);

      expect(result, contains('[MyApp.Service]'));
    });

    test('excludes logger name when includeLoggerName is false', () {
      const formatter = SimpleFileFormatter(includeLoggerName: false);
      final record = testRecord(
        message: 'Test',
        loggerName: 'MyApp.Service',
      );

      final result = formatRecord(formatter, record);

      expect(result, isNot(contains('[MyApp.Service]')));
    });

    test('includes structured data', () {
      const formatter = SimpleFileFormatter();
      final record = testRecord(
        message: 'User logged in',
        data: {'userId': 'abc123', 'role': 'admin'},
      );

      final result = formatRecord(formatter, record);

      expect(result, contains('userId'));
      expect(result, contains('abc123'));
    });

    test('excludes data when includeData is false', () {
      const formatter = SimpleFileFormatter(includeData: false);
      final record = testRecord(
        message: 'Test',
        data: {'key': 'value'},
      );

      final result = formatRecord(formatter, record);

      expect(result, isNot(contains('key')));
    });

    test('includes error and stack trace', () {
      const formatter = SimpleFileFormatter();
      final record = testRecord(
        message: 'Operation failed',
        level: ChirpLogLevel.error,
        error: Exception('Something went wrong'),
        stackTrace: StackTrace.current,
      );

      final result = formatRecord(formatter, record);

      expect(result, contains('Error:'));
      expect(result, contains('Something went wrong'));
      expect(result, contains('rotating_file_writer_test.dart'));
    });

    test('formats all log levels correctly', () {
      const formatter = SimpleFileFormatter();
      final levels = [
        ChirpLogLevel.trace,
        ChirpLogLevel.debug,
        ChirpLogLevel.info,
        ChirpLogLevel.notice,
        ChirpLogLevel.warning,
        ChirpLogLevel.error,
        ChirpLogLevel.critical,
        ChirpLogLevel.wtf,
      ];

      for (final level in levels) {
        final record = testRecord(message: 'Test', level: level);

        final result = formatRecord(formatter, record);
        expect(
          result,
          contains('[${level.name.toUpperCase().padRight(8)}]'),
          reason: 'Level $level should be formatted correctly',
        );
      }
    });
  });

  group('FileMessageBuffer', () {
    test('writeData formats inline yaml data', () {
      final buffer = FileMessageBuffer();

      buffer.writeData({'user id': 'abc123', 'count': 2});

      expect(buffer.toString(), '"user id": "abc123", count: 2');
    });

    test('writeData ignores null and empty data', () {
      final buffer = FileMessageBuffer();

      buffer.writeData(null);
      buffer.writeData({});

      expect(buffer.toString(), isEmpty);
    });

    test('ensureLineBreak adds newline only when needed', () {
      final empty = FileMessageBuffer();

      empty.ensureLineBreak();
      expect(empty.toString(), isEmpty);

      final buffer = FileMessageBuffer();
      buffer.write('line');
      buffer.ensureLineBreak();
      buffer.ensureLineBreak();
      expect(buffer.toString(), 'line\n');

      final withNewline = FileMessageBuffer();
      withNewline.writeln('line');
      withNewline.ensureLineBreak();
      expect(withNewline.toString(), 'line\n');
    });
  });

  group('JsonLogFormatter', () {
    test('requiresCallerInfo is always true', () {
      const formatter = JsonLogFormatter();

      expect(formatter.requiresCallerInfo, isTrue);
    });

    test('formats as valid JSON with required fields', () {
      const formatter = JsonLogFormatter();
      final ts = DateTime.utc(2024, 1, 15, 10, 30, 45);
      final record = testRecord(
        message: 'Test message',
        timestamp: ts,
      );

      final result = formatRecord(formatter, record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['timestamp'], '2024-01-15T10:30:45.000Z');
      expect(json['level'], 'info');
      expect(json['message'], 'Test message');
      expect(json.containsKey('logger'), isFalse,
          reason: 'logger should be omitted when null');
    });

    test('includes all optional fields when present', () {
      const formatter = JsonLogFormatter();
      final record = testRecord(
        message: 'Test',
        level: ChirpLogLevel.error,
        loggerName: 'MyLogger',
        data: {'key': 'value'},
        error: Exception('Test error'),
        stackTrace: StackTrace.current,
      );

      final result = formatRecord(formatter, record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['logger'], 'MyLogger');
      expect(json['key'], 'value');
      expect(json['error'], contains('Test error'));
      expect(json['stackTrace'], isNotEmpty);
    });

    test('escapes special characters in strings to produce valid JSON', () {
      const formatter = JsonLogFormatter();
      const originalMessage = 'Line1\nLine2\tTabbed\r"Quoted"\\Escaped';
      final record = testRecord(message: originalMessage);

      final result = formatRecord(formatter, record);

      // Verify it's valid JSON and message survives round-trip
      final json = jsonDecode(result) as Map<String, Object?>;
      expect(json['message'], originalMessage,
          reason: 'Message should survive JSON encode/decode round-trip');
    });

    test('handles nested data structures', () {
      const formatter = JsonLogFormatter();
      final record = testRecord(
        message: 'Test',
        data: {
          'user': {'id': 123, 'name': 'John'},
          'tags': ['a', 'b', 'c'],
        },
      );

      final result = formatRecord(formatter, record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['user'], {'id': 123, 'name': 'John'});
      expect(json['tags'], ['a', 'b', 'c']);
    });

    test('handles null message', () {
      const formatter = JsonLogFormatter();
      final record = testRecord(message: null);

      final result = formatRecord(formatter, record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['message'], isNull);
    });
  });

  group('RotatingFileWriter', () {
    test('writes formatted log record to file', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Test message'));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('Test message'),
          reason: 'Log file should contain the written message');
      expect(content, contains('[INFO'),
          reason: 'Log file should contain formatted level');
    });

    test('reader returns a RotatingFileReader for the same files', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Hello from writer'));
      await writer.flush();

      final lines = await writer.reader.read().toList();
      expect(lines, contains(contains('Hello from writer')));
    });

    test('reader works with async baseFilePathProvider', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final completer = Completer<String>();
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => completer.future,
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Async path message'));
      completer.complete(logPath);
      await writer.flush();

      final lines = await writer.reader.read().toList();
      expect(lines, contains(contains('Async path message')));
    });

    test('lazy baseFilePathProvider buffers until path is resolved', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/lazy/app.log';

        final completer = Completer<String>();
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => completer.future,
        );

        // Write before we resolve the path - should be buffered.
        writer.write(testRecord(message: 'Buffered before path'));

        // Resolve the path later.
        completer.complete(logPath);
        async.flushMicrotasks();

        writer.flush();
        async.flushMicrotasks();

        final content = File(logPath).readAsStringSync();
        expect(content, contains('Buffered before path'));

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('lazy baseFilePathProvider writes errors without manual flush', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/lazy-error/app.log';

        final completer = Completer<String>();
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => completer.future,
        );

        // Write an error before the path is resolved - should be buffered.
        writer.write(
          testRecord(message: 'Error before path', level: ChirpLogLevel.error),
        );

        // File should not exist yet.
        expect(File(logPath).existsSync(), isFalse);

        // Resolve the path - pending records drain automatically.
        completer.complete(logPath);
        async.flushMicrotasks();

        // Error was written without calling flush().
        final content = File(logPath).readAsStringSync();
        expect(content, contains('Error before path'));

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('lazy baseFilePathProvider drains buffer after flushInterval', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/lazy-buffered/app.log';

        final completer = Completer<String>();
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => completer.future,
          flushStrategy: FlushStrategy.buffered,
          flushInterval: const Duration(seconds: 10),
        );

        // Write an info record before the path is resolved.
        writer.write(testRecord(message: 'Buffered info'));

        // Resolve the path.
        completer.complete(logPath);
        async.flushMicrotasks();

        // Advance time, but not past the flushInterval.
        async.elapse(const Duration(seconds: 9));

        // The record hasn't been flushed yet because flushInterval hasn't
        // elapsed.
        expect(
          File(logPath).existsSync() ? File(logPath).readAsStringSync() : '',
          isEmpty,
          reason: 'Buffer should not have been flushed after 9s '
              '(flushInterval is 10s)',
        );

        // Advance past the flushInterval.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        final content = File(logPath).readAsStringSync();
        expect(content, contains('Buffered info'));

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('creates parent directories recursively if they do not exist',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/logs/subdir/deep/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Test'));

      await writer.flush();

      expect(File(logPath).existsSync(), isTrue,
          reason: 'File should exist after write even with nested directories');
      expect(Directory('${tempDir.path}/logs/subdir/deep').existsSync(), isTrue,
          reason: 'Parent directories should be created');
    });

    test('appends to existing file instead of overwriting', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      // Write first message with one writer instance
      final writer1 = RotatingFileWriter(baseFilePathProvider: () => logPath);
      writer1.write(testRecord(message: 'First message'));
      await writer1.close();

      // Write second message with new writer instance
      final writer2 = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer2.close());
      writer2.write(testRecord(message: 'Second message'));
      await writer2.flush();

      final content = File(logPath).readAsStringSync();
      final lines = content.trim().split('\n');
      expect(lines.length, 2, reason: 'File should have 2 log lines');
      expect(lines[0], contains('First message'));
      expect(lines[1], contains('Second message'));
    });

    test('uses custom formatter when provided', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.jsonl';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: const JsonLogFormatter(),
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'JSON test'));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      final json = jsonDecode(content.trim()) as Map<String, Object?>;
      expect(json['message'], 'JSON test',
          reason: 'JsonLogFormatter should produce valid JSON');
    });

    test('integrates with ChirpLogger for real logging workflow', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      final logger = ChirpLogger(name: 'TestLogger').addWriter(writer);

      logger.info('Integration test message');

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('Integration test message'));
      expect(content, contains('[TestLogger]'),
          reason: 'Logger name should appear in output');
      expect(content, contains('[INFO'),
          reason: 'Log level should appear in output');
    });

    test('formatter can require caller info', () {
      final formatter = _CapturingFormatter([]);

      expect(formatter.requiresCallerInfo, isFalse);

      final withCallerInfo = _CapturingFormatter([], requiresCallerInfo: true);
      expect(withCallerInfo.requiresCallerInfo, isTrue);
    });

    test('requiresCallerInfo false does not capture caller', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final records = <LogRecord>[];
      final formatter = _CapturingFormatter(records);
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: formatter,
      );
      addTearDown(() => writer.close());

      final logger = ChirpLogger(name: 'TestLogger').addWriter(writer);

      logger.info('Caller info test');

      await writer.flush();

      expect(writer.requiresCallerInfo, isFalse);
      expect(records, hasLength(1));
      expect(records[0].caller, isNull);
    });

    test('requiresCallerInfo delegates to formatter and captures caller',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final records = <LogRecord>[];
      final formatter = _CapturingFormatter(
        records,
        requiresCallerInfo: true,
      );
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: formatter,
      );
      addTearDown(() => writer.close());

      final logger = ChirpLogger(name: 'TestLogger').addWriter(writer);

      logger.info('Caller info test');

      await writer.flush();

      expect(writer.requiresCallerInfo, isTrue);
      expect(records, hasLength(1));
      expect(records[0].caller, isNotNull);
      expect(
        records[0].caller.toString(),
        contains('rotating_file_writer_test.dart'),
      );
    });

    test('requiresCallerInfo captures caller in file output', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: const _CallerLocationFormatter(),
      );
      addTearDown(() => writer.close());

      final logger = ChirpLogger(name: 'TestLogger').addWriter(writer);

      logger.info('Caller info test');

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('rotating_file_writer_test'));
    });

    test('respects minLogLevel filtering inherited from ChirpWriter', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath)
        ..setMinLogLevel(ChirpLogLevel.warning);
      addTearDown(() => writer.close());

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('INFO - should be filtered');
      logger.debug('DEBUG - should be filtered');
      logger.warning('WARNING - should appear');
      logger.error('ERROR - should appear');

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, isNot(contains('should be filtered')),
          reason: 'Messages below warning level should not be written');
      expect(content, contains('WARNING - should appear'));
      expect(content, contains('ERROR - should appear'));
    });

    test('minLevel constructor parameter filters messages', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        minLevel: ChirpLogLevel.warning,
      );
      addTearDown(() => writer.close());

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('INFO - should be filtered');
      logger.debug('DEBUG - should be filtered');
      logger.warning('WARNING - should appear');
      logger.error('ERROR - should appear');

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, isNot(contains('should be filtered')),
          reason: 'Messages below warning level should not be written');
      expect(content, contains('WARNING - should appear'));
      expect(content, contains('ERROR - should appear'));
    });

    test('minLevel sets minLogLevel property', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        minLevel: ChirpLogLevel.error,
      );
      addTearDown(() => writer.close());

      expect(writer.minLogLevel, ChirpLogLevel.error,
          reason: 'minLevel should set the minLogLevel property');
    });

    test('minLevel null does not set minLogLevel', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      expect(writer.minLogLevel, isNull,
          reason: 'minLogLevel should be null by default');
    });
  });

  group('Size-based rotation', () {
    test('rotates when file exceeds max size', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.size(
          maxSize: 100, // Very small for testing
          maxFiles: 10,
        ),
      );
      addTearDown(() => writer.close());

      // Write enough to trigger rotation
      for (var i = 0; i < 10; i++) {
        final ts = DateTime(2024, 1, 15, 10, 30, i);
        writer.write(testRecord(
          message: 'Message $i - This is a longer message to trigger rotation',
          timestamp: ts,
        ));
      }

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      final rotatedFiles = files.where((f) => f.path != logPath).toList();

      expect(File(logPath).existsSync(), isTrue,
          reason: 'Current log file should always exist');
      expect(rotatedFiles.length, greaterThanOrEqualTo(1),
          reason: 'At least one rotated file should be created');

      // Rotated files should have timestamp in name
      for (final file in rotatedFiles) {
        expect(file.path, contains('2024-01-15'),
            reason: 'Rotated filename should contain timestamp');
      }
    });

    test('respects max file count by deleting oldest files', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.size(
          maxSize: 50,
          maxFiles: 3,
        ),
      );
      addTearDown(() => writer.close());

      // Write enough to create many rotations (should trigger cleanup)
      for (var i = 0; i < 20; i++) {
        final ts = DateTime(2024, 1, 15, 10, 30, i);
        writer.write(testRecord(
          message: 'Message $i - Extra padding for size',
          timestamp: ts,
        ));
      }

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, lessThanOrEqualTo(3),
          reason:
              'maxFiles=3 should keep at most 3 files (1 current + 2 rotated)');
    });

    test('maxFileCount=1 throws ArgumentError', () {
      expect(
        () => FileRotationConfig.size(maxSize: 50, maxFiles: 1),
        throwsArgumentError,
        reason:
            'maxFileCount=1 is invalid (need at least 2: current + 1 rotated)',
      );
    });

    test('maxFileCount=0 throws ArgumentError', () {
      expect(
        () => FileRotationConfig.size(maxSize: 50, maxFiles: 0),
        throwsArgumentError,
        reason: 'maxFileCount=0 is invalid and should throw',
      );
    });

    test('negative maxFileCount throws ArgumentError', () {
      expect(
        () => FileRotationConfig.size(maxSize: 50, maxFiles: -5),
        throwsArgumentError,
        reason: 'Negative maxFileCount is invalid and should throw',
      );
    });

    test('adds counter suffix when multiple rotations occur in same second',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.size(
          maxSize: 10, // Smaller than any log entry
          maxFiles: 10,
        ),
      );
      addTearDown(() => writer.close());

      // Write 5 entries with same timestamp - each triggers rotation
      final ts = DateTime(2024, 1, 15, 10, 30, 45);
      for (var i = 1; i <= 5; i++) {
        writer.write(testRecord(message: 'Message $i', timestamp: ts));
      }

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 5,
          reason: 'Should have 5 files: 4 rotated + 1 current');

      // Verify no data loss - all messages should exist across files
      final allContent = files.map((f) => f.readAsStringSync()).join();
      for (var i = 1; i <= 5; i++) {
        expect(allContent, contains('Message $i'),
            reason: 'Message $i should not be lost due to filename collision');
      }

      // Verify counter suffixes are used (match _1.log, _2.log etc at end)
      final fileNames = files.map((f) => f.uri.pathSegments.last).toList();
      expect(fileNames.where((n) => RegExp(r'_1\.log$').hasMatch(n)).length, 1,
          reason: 'Should have one file with _1 suffix');
      expect(fileNames.where((n) => RegExp(r'_2\.log$').hasMatch(n)).length, 1,
          reason: 'Should have one file with _2 suffix');
    });

    test('retention counts rotated files with counter suffix', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.size(
          maxSize: 1024 * 1024,
          maxFiles: 2,
        ),
      );
      addTearDown(() => writer.close());

      final rotated = File('${tempDir.path}/app.2024-01-15_10-30-45.log');
      final rotatedCounter =
          File('${tempDir.path}/app.2024-01-15_10-30-45_1.log');
      rotated.writeAsStringSync('older');
      rotatedCounter.writeAsStringSync('oldest');
      rotated.setLastModifiedSync(DateTime(2024, 1, 2));
      // ignore: avoid_redundant_argument_values
      rotatedCounter.setLastModifiedSync(DateTime(2024, 1, 1));

      writer.write(testRecord(
        message: 'Trigger rotation',
        timestamp: DateTime(2024, 1, 15, 10, 30, 46),
      ));
      await writer.forceRotate();
      await writer.close();

      expect(rotated.existsSync(), isFalse,
          reason: 'Rotated file should be deleted when maxFiles is exceeded');
      expect(rotatedCounter.existsSync(), isFalse,
          reason: 'Counter-suffix rotated file should be deleted by retention');
    });
  });

  group('Time-based rotation', () {
    test('rotates on hour change with hourly config', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.hourly(),
      );
      addTearDown(() => writer.close());

      // Write at 10:00
      writer.write(testRecord(
        message: 'Message at 10:00',
        timestamp: DateTime(2024, 1, 15, 10),
      ));

      // Write at 11:00 (should trigger rotation)
      writer.write(testRecord(
        message: 'Message at 11:00',
        timestamp: DateTime(2024, 1, 15, 11),
      ));

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 2,
          reason:
              'Hour change should create exactly 2 files: current + rotated');

      // Verify content separation
      final currentContent = File(logPath).readAsStringSync();
      expect(currentContent, contains('Message at 11:00'),
          reason: 'Current file should have the newer message');

      final rotatedFile = files.firstWhere((f) => f.path != logPath);
      expect(rotatedFile.readAsStringSync(), contains('Message at 10:00'),
          reason: 'Rotated file should have the older message');
    });

    test('rotates on day change with daily config', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.daily(),
      );
      addTearDown(() => writer.close());

      // Write on Jan 15
      writer.write(testRecord(
        message: 'Message on Jan 15',
        timestamp: DateTime(2024, 1, 15, 10),
      ));

      // Write on Jan 16 (should trigger rotation)
      writer.write(testRecord(
        message: 'Message on Jan 16',
        timestamp: DateTime(2024, 1, 16, 10),
      ));

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 2,
          reason: 'Day change should create exactly 2 files');

      // Rotated file should have date in name and contain old message
      final rotatedFile = files.firstWhere(
        (f) => f.path.contains('2024-01-15'),
        orElse: () => throw StateError(
            'Expected rotated file with 2024-01-15 in name. Found: ${files.map((f) => f.path).join(", ")}'),
      );
      expect(rotatedFile.readAsStringSync(), contains('Message on Jan 15'));

      // Current file should have new message
      expect(File(logPath).readAsStringSync(), contains('Message on Jan 16'));
    });

    test('does not rotate when all writes are in same time period', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.daily(),
      );
      addTearDown(() => writer.close());

      // Write multiple times on same day (different hours)
      for (var i = 0; i < 5; i++) {
        final ts = DateTime(2024, 1, 15, 10 + i);
        writer.write(testRecord(message: 'Message $i', timestamp: ts));
      }

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1,
          reason: 'No rotation should occur within same day');

      // All messages should be in the single file
      final content = File(logPath).readAsStringSync();
      for (var i = 0; i < 5; i++) {
        expect(content, contains('Message $i'),
            reason: 'All messages should be in the single file');
      }
    });

    test('rotates on week change with weekly config', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig(
          rotationInterval: FileRotationInterval.weekly,
        ),
      );
      addTearDown(() => writer.close());

      // Write on Saturday Jan 13, 2024
      writer.write(testRecord(
        message: 'Message on Saturday',
        timestamp: DateTime(2024, 1, 13, 10),
      ));

      // Write on Monday Jan 15, 2024 (new week, should trigger rotation)
      writer.write(testRecord(
        message: 'Message on Monday',
        timestamp: DateTime(2024, 1, 15, 10),
      ));

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 2,
          reason: 'Week change should create 2 files: current + rotated');

      // Verify content separation
      final currentContent = File(logPath).readAsStringSync();
      expect(currentContent, contains('Message on Monday'));

      final rotatedFile = files.firstWhere((f) => f.path != logPath);
      expect(rotatedFile.readAsStringSync(), contains('Message on Saturday'));
    });

    test('rotates on month change with monthly config', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig(
          rotationInterval: FileRotationInterval.monthly,
        ),
      );
      addTearDown(() => writer.close());

      // Write on Jan 31
      writer.write(testRecord(
        message: 'Message in January',
        timestamp: DateTime(2024, 1, 31, 10),
      ));

      // Write on Feb 1 (new month, should trigger rotation)
      writer.write(testRecord(
        message: 'Message in February',
        timestamp: DateTime(2024, 2, 1, 10),
      ));

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 2,
          reason: 'Month change should create 2 files: current + rotated');

      // Verify content separation
      final currentContent = File(logPath).readAsStringSync();
      expect(currentContent, contains('Message in February'));

      final rotatedFile = files.firstWhere((f) => f.path != logPath);
      expect(rotatedFile.readAsStringSync(), contains('Message in January'));
    });
  });

  group('Compression', () {
    test('compresses rotated files to .gz when compress=true', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.daily(compress: true),
      );
      addTearDown(() => writer.close());

      // Write on Jan 15
      writer.write(testRecord(
        message: 'Message to compress',
        timestamp: DateTime(2024, 1, 15, 10),
      ));

      // Write on Jan 16 (triggers rotation and compression)
      writer.write(testRecord(
        message: 'New day message',
        timestamp: DateTime(2024, 1, 16, 10),
      ));

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      final gzFiles = files.where((f) => f.path.endsWith('.gz')).toList();
      final uncompressedRotated = files
          .where((f) => f.path != logPath && !f.path.endsWith('.gz'))
          .toList();

      expect(gzFiles.length, 1,
          reason: 'Exactly one compressed rotated file should exist');
      expect(uncompressedRotated, isEmpty,
          reason: 'Original rotated file should be deleted after compression');

      // Verify gzip file contains the old message after decompression
      final gzContent = gzFiles.first.readAsBytesSync();
      final decompressed = gzip.decode(gzContent);
      final text = utf8.decode(decompressed);
      expect(text, contains('Message to compress'),
          reason: 'Decompressed content should contain the rotated message');
      expect(text, isNot(contains('New day message')),
          reason: 'Compressed file should not contain new day message');
    });
  });

  group('Force rotation', () {
    test('forceRotate triggers immediate rotation', () async {
      // Use withClock to control time
      final fixedTime = DateTime(2024, 1, 15, 10);

      await withClock(Clock.fixed(fixedTime), () async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        // Use size-based config to avoid time-based rotation complications
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          rotationConfig: FileRotationConfig.size(
            maxSize: 1024 * 1024, // Large enough to not trigger
          ),
        );
        addTearDown(() => writer.close());

        // Write some content
        writer.write(testRecord(
          message: 'Before force rotate',
          timestamp: fixedTime,
        ));

        // Force rotation
        writer.forceRotate();

        // Write after rotation
        writer.write(testRecord(
          message: 'After force rotate',
          timestamp: fixedTime,
        ));

        await writer.close();

        // Should have current file and rotated file
        final files = tempDir.listSync().whereType<File>().toList();
        expect(files.length, 2);

        // Current file should have "After" message
        expect(
            File(logPath).readAsStringSync(), contains('After force rotate'));

        // Rotated file should have "Before" message
        final rotatedFile = files.firstWhere((f) => f.path != logPath);
        expect(rotatedFile.readAsStringSync(), contains('Before force rotate'));
      });
    });
  });

  group('forceRotate in buffered mode', () {
    test('flushes buffered records to pre-rotation file', () async {
      await fakeAsyncWithDrain((async) async {
        final fixedTime = DateTime(2024, 1, 15, 10);
        await withClock(Clock.fixed(fixedTime), () async {
          final tempDir = createTempDir();
          final logPath = '${tempDir.path}/app.log';
          final writer = RotatingFileWriter(
            baseFilePathProvider: () => logPath,
            flushStrategy: FlushStrategy.buffered,
            flushInterval: const Duration(seconds: 10),
            rotationConfig: FileRotationConfig.size(maxSize: 1024 * 1024),
          );

          // Write buffered records (timer won't fire for 10s)
          writer.write(testRecord(message: 'Before rotate'));

          // Force rotation — should flush buffer to the old file first
          await writer.forceRotate();
          await drainEvent();

          // Write after rotation
          writer.write(
            testRecord(message: 'After rotate', level: ChirpLogLevel.error),
          );

          final files = tempDir.listSync().whereType<File>().toList();
          expect(files.length, 2, reason: 'Should have current + rotated file');

          final currentContent = File(logPath).readAsStringSync();
          expect(currentContent, contains('After rotate'));
          expect(currentContent, isNot(contains('Before rotate')),
              reason: 'Pre-rotation record should not be in current file');

          final rotatedFile = files.firstWhere((f) => f.path != logPath);
          expect(rotatedFile.readAsStringSync(), contains('Before rotate'),
              reason: 'Pre-rotation record should be in rotated file');

          await writer.close();
          await drainEvent();
        });
      });
    });
  });

  group('Max age retention', () {
    test('deletes rotated files older than maxAge', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      // Create writer and write first message (creates file at real time)
      final writer1 = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.size(
          maxSize: 50,
          maxAge: const Duration(days: 7),
        ),
      );

      // Write enough to trigger rotation (creates rotated file at real time)
      for (var i = 0; i < 5; i++) {
        writer1.write(testRecord(
          message: 'Old message $i - padding',
          timestamp: DateTime(2024, 1, 15, 10, 0, i),
        ));
      }
      await writer1.close();

      // Verify rotated files exist
      final filesBeforeAging = tempDir.listSync().whereType<File>().toList();
      final rotatedBefore =
          filesBeforeAging.where((f) => f.path != logPath).toList();
      expect(rotatedBefore, isNotEmpty,
          reason: 'Should have rotated files before aging');

      // Now open new writer with clock far in the future (10 days later)
      // The rotated files' real modification time is "now", but clock says
      // it's 10 days from now, so files appear older than 7 day maxAge
      final futureTime = DateTime.now().add(const Duration(days: 10));
      await withClock(Clock.fixed(futureTime), () async {
        final writer2 = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          rotationConfig: FileRotationConfig.size(
            maxSize: 50,
            maxAge: const Duration(days: 7),
          ),
        );

        // Write to trigger rotation which applies retention policy
        for (var i = 0; i < 5; i++) {
          writer2.write(testRecord(
            message: 'New message $i - padding',
            timestamp: futureTime.add(Duration(seconds: i)),
          ));
        }
        await writer2.close();
      });

      // Should still have current log file
      expect(File(logPath).existsSync(), isTrue);

      // Old rotated files (from writer1) should be deleted due to maxAge
      // Only new rotated files (from writer2) and current file should remain
      for (final oldFile in rotatedBefore) {
        expect(oldFile.existsSync(), isFalse,
            reason:
                'Old rotated file ${oldFile.path} should be deleted by maxAge policy');
      }
    });
  });

  group('Encoding', () {
    test('uses custom encoding when provided', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        encoding: latin1,
      );
      addTearDown(() => writer.close());

      // Write ASCII message (works with both utf8 and latin1)
      writer.write(testRecord(message: 'Hello ASCII'));

      await writer.flush();

      // Read file as raw bytes and decode with latin1
      final bytes = File(logPath).readAsBytesSync();
      final content = latin1.decode(bytes);
      expect(content, contains('Hello ASCII'));
    });

    test('writes with default utf8 encoding', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      // Write UTF-8 specific characters
      const message = 'UTF-8: äöü ñ 你好';
      writer.write(testRecord(message: message));

      await writer.flush();

      // Read as UTF-8 and verify
      final bytes = File(logPath).readAsBytesSync();
      final content = utf8.decode(bytes);
      expect(content, contains(message));
    });
  });

  group('Edge cases', () {
    test('writes log line with empty message without error', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: ''));

      await writer.flush();

      expect(File(logPath).existsSync(), isTrue,
          reason: 'File should be created even with empty message');
      final content = File(logPath).readAsStringSync();
      expect(content, contains('[INFO    ]'),
          reason:
              'Log line should have timestamp and level even with empty message');
    });

    test('writes null message as "null" string', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: null));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('null'),
          reason: 'null message should be written as "null"');
    });

    test('writes very long messages completely', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      final longMessage = 'x' * 10000;
      writer.write(testRecord(message: longMessage));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains(longMessage),
          reason: '10000 char message should be written completely');
    });

    test('preserves special characters in messages', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      const message = 'Tabs:\there Quotes:"here" Backslash:\\here';
      writer.write(testRecord(message: message));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains(message),
          reason: 'Special characters should be preserved in file');
    });

    test('preserves unicode characters (emoji, CJK, Cyrillic)', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      const emoji = '\u{1F600}';
      const chinese = '\u4E2D\u6587';
      const russian = '\u0420\u0443\u0441\u0441\u043A\u0438\u0439';
      writer.write(testRecord(message: 'Unicode: $emoji $chinese $russian'));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains(emoji), reason: 'Emoji should be preserved');
      expect(content, contains(chinese),
          reason: 'Chinese characters should be preserved');
      expect(content, contains(russian),
          reason: 'Russian characters should be preserved');
    });

    test('calling close() multiple times does not throw', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);

      writer.write(testRecord(message: 'Test message'));

      // First close
      await writer.close();

      // Second and third close should not throw
      await writer.close();
      await writer.close();

      // File should still contain the message
      final content = File(logPath).readAsStringSync();
      expect(content, contains('Test message'));
    });
  });

  group('Error handling', () {
    test('calls onError callback when formatter throws', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      Object? capturedError;
      StackTrace? capturedStackTrace;
      LogRecord? capturedRecord;

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: _ThrowingFormatter(),
        onError: (error, stackTrace, record) {
          capturedError = error;
          capturedStackTrace = stackTrace;
          capturedRecord = record;
        },
      );
      addTearDown(() => writer.close());

      final failingRecord = testRecord(message: 'This should fail');
      writer.write(failingRecord);

      expect(capturedError, isNotNull, reason: 'onError should be called');
      expect(capturedError, isA<StateError>());
      expect(capturedStackTrace, isNotNull,
          reason: 'Stack trace should be provided');
      expect(capturedRecord, equals(failingRecord),
          reason: 'The failing record should be passed to onError');
    });

    test('does not throw when onError handles the error', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: _ThrowingFormatter(),
        onError: (_, __, ___) {}, // Silence errors
      );
      addTearDown(() => writer.close());

      // Should not throw - error is handled by onError
      expect(
        () => writer.write(testRecord(message: 'Test')),
        returnsNormally,
      );
    });

    test('prints to stderr by default when onError is null', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: _ThrowingFormatter(),
        // onError is null - prints to stderr by default
      );
      addTearDown(() => writer.close());

      // Capture print output so it doesn't pollute test output.
      final printed = <String>[];
      runZoned(
        () {
          expect(
            () => writer.write(testRecord(message: 'Test')),
            returnsNormally,
            reason: 'Write should not throw - error should go to stderr',
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            printed.add(line);
          },
        ),
      );

      expect(printed, isNotEmpty,
          reason: 'Default error handler should print to stdout');
      expect(printed.first, contains('Simulated formatter error'));
    });

    test('onError receives correct record for each failed write', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      final failedRecords = <LogRecord?>[];

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: _ThrowingFormatter(),
        onError: (error, stackTrace, record) {
          failedRecords.add(record);
        },
      );
      addTearDown(() => writer.close());

      final record1 = testRecord(message: 'Fail 1');
      final record2 = testRecord(message: 'Fail 2');
      writer.write(record1);
      writer.write(record2);

      expect(failedRecords.length, 2,
          reason: 'Both failed writes should trigger onError');
      expect(failedRecords[0]?.message, 'Fail 1');
      expect(failedRecords[1]?.message, 'Fail 2');
    });
  });

  group('FlushStrategy.buffered', () {
    test('buffers records and flushes on close', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(
            seconds: 10), // Long interval so it doesn't auto-flush
      );
      addTearDown(() => writer.close());

      // Write several records
      for (var i = 0; i < 5; i++) {
        writer.write(testRecord(message: 'Buffered message $i'));
      }

      // File may not exist yet or be empty (buffered)
      // Close should flush all records
      await writer.close();

      final content = File(logPath).readAsStringSync();
      for (var i = 0; i < 5; i++) {
        expect(content, contains('Buffered message $i'),
            reason: 'All buffered messages should be written after close');
      }
    });

    test('writes error-level logs synchronously for immediate visibility',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(seconds: 10), // Long interval
      );
      addTearDown(() => writer.close());

      // Write only error messages (no buffered records to flush first)
      writer.write(
          testRecord(message: 'Error message', level: ChirpLogLevel.error));
      writer.write(testRecord(
          message: 'Critical message', level: ChirpLogLevel.critical));

      // Without flushing, error messages should already be on disk
      final content = File(logPath).readAsStringSync();
      expect(content, contains('Error message'),
          reason: 'Error should be written synchronously');
      expect(content, contains('Critical message'),
          reason: 'Critical should be written synchronously');

      await writer.close();
    });

    test('flushes buffered records before writing error to maintain order',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(seconds: 10), // Long interval
      );
      addTearDown(() => writer.close());

      // Write info messages (buffered), then an error (triggers sync flush)
      writer.write(testRecord(message: 'Info 1'));
      writer.write(testRecord(message: 'Info 2'));
      writer.write(testRecord(message: 'Error', level: ChirpLogLevel.error));

      // All messages should be on disk, in chronological order
      final content = File(logPath).readAsStringSync();
      final lines = content.trim().split('\n');

      expect(lines.length, 3, reason: 'All 3 messages should be written');
      expect(lines[0], contains('Info 1'),
          reason: 'First buffered message should be first');
      expect(lines[1], contains('Info 2'),
          reason: 'Second buffered message should be second');
      expect(lines[2], contains('Error'),
          reason: 'Error message should be last');

      await writer.close();
    });

    test('flush() writes all pending records', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(seconds: 10),
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Before flush'));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('Before flush'),
          reason: 'Message should be written after explicit flush');
    });

    test('supports rotation in buffered mode', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 10),
        rotationConfig: FileRotationConfig.daily(),
      );
      addTearDown(() => writer.close());

      // Write on Jan 15
      writer.write(testRecord(
        message: 'Message on Jan 15',
        timestamp: DateTime(2024, 1, 15, 10),
      ));

      // Write on Jan 16 (should trigger rotation)
      writer.write(testRecord(
        message: 'Message on Jan 16',
        timestamp: DateTime(2024, 1, 16, 10),
      ));

      await writer.close();

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 2,
          reason: 'Daily rotation should create 2 files in buffered mode');

      // Verify content separation: pre-rotation record in rotated file,
      // post-rotation record in current file.
      final currentContent = File(logPath).readAsStringSync();
      expect(currentContent, contains('Message on Jan 16'),
          reason: 'Current file should have post-rotation message');
      expect(currentContent, isNot(contains('Message on Jan 15')),
          reason: 'Current file should not have pre-rotation message');

      final rotatedFile = files.firstWhere((f) => f.path != logPath);
      expect(rotatedFile.readAsStringSync(), contains('Message on Jan 15'),
          reason: 'Rotated file should have pre-rotation message');
    });
  });

  group('FlushStrategy.buffered timer behavior', () {
    test('first write starts timer, flushes after flushInterval', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
          flushInterval: const Duration(milliseconds: 50),
        );

        // Write - starts timer
        writer.write(testRecord(message: 'Message 1'));

        // Immediately after write, file should not exist (buffered)
        expect(File(logPath).existsSync(), isFalse,
            reason: 'File should not exist immediately after write');

        // Wait for timer to fire
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        // Now file should exist
        expect(File(logPath).existsSync(), isTrue,
            reason: 'File should exist after flushInterval');

        final content = File(logPath).readAsStringSync();
        expect(content, contains('Message 1'));

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('multiple writes before timer fires are batched together', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
          flushInterval: const Duration(milliseconds: 100),
        );

        // Write multiple messages quickly (before timer fires)
        writer.write(testRecord(message: 'Message 1'));
        writer.write(testRecord(message: 'Message 2'));
        writer.write(testRecord(message: 'Message 3'));

        // Immediately, nothing written yet
        expect(File(logPath).existsSync(), isFalse);

        // Wait for timer
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // All 3 messages should be written in one batch
        final content = File(logPath).readAsStringSync();
        expect(content, contains('Message 1'));
        expect(content, contains('Message 2'));
        expect(content, contains('Message 3'));

        final lines = content.trim().split('\n');
        expect(lines.length, 3, reason: 'All 3 messages batched in one flush');

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('timer resets after flush, next write starts new timer', () async {
      await fakeAsyncWithDrain((async) async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
        );

        // First batch
        writer.write(testRecord(message: 'Batch 1'));
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        final content = File(logPath).readAsStringSync();
        expect(content, contains('Batch 1'));
        expect(content, isNot(contains('Batch 2')));

        // Second batch - starts new timer
        writer.write(testRecord(message: 'Batch 2'));

        // Immediately, batch 2 not flushed yet
        expect(File(logPath).readAsStringSync(), isNot(contains('Batch 2')),
            reason: 'Batch 2 not yet flushed');

        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        final content2 = File(logPath).readAsStringSync();
        expect(content2, contains('Batch 1'));
        expect(content2, contains('Batch 2'));

        await writer.close();
        await drainEvent();
      });
    });

    test('no timer fires when no writes happen', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
          flushInterval: const Duration(milliseconds: 50),
        );

        // Wait without writing anything
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // No file should be created
        expect(File(logPath).existsSync(), isFalse,
            reason: 'No file should be created when no writes happen');

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('error cancels pending timer and flushes buffer immediately', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(seconds: 10), // Long interval
      );
      addTearDown(() => writer.close());

      // Write info messages (buffered, timer starts)
      writer.write(testRecord(message: 'Info 1'));
      writer.write(testRecord(message: 'Info 2'));

      // Nothing flushed yet
      expect(File(logPath).existsSync(), isFalse);

      // Write error - should flush buffer immediately, then write error
      writer.write(testRecord(message: 'Error', level: ChirpLogLevel.error));

      // All messages should be on disk now, in order
      final content = File(logPath).readAsStringSync();
      final lines = content.trim().split('\n');
      expect(lines.length, 3);
      expect(lines[0], contains('Info 1'));
      expect(lines[1], contains('Info 2'));
      expect(lines[2], contains('Error'));
    });

    test('writes after error start a new timer', () async {
      await fakeAsyncWithDrain((async) async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
        );

        // Write error (flushes immediately)
        writer.write(testRecord(message: 'Error', level: ChirpLogLevel.error));

        var content = File(logPath).readAsStringSync();
        expect(content, contains('Error'));
        expect(content, isNot(contains('Info after error')));

        // Write info after error - starts new timer
        writer.write(testRecord(message: 'Info after error'));

        // Info not flushed yet
        expect(File(logPath).readAsStringSync(),
            isNot(contains('Info after error')));

        // Wait for new timer
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        content = File(logPath).readAsStringSync();
        expect(content, contains('Error'));
        expect(content, contains('Info after error'));

        writer.close();
        await drainEvent();
      });
    });

    test('close() flushes pending buffer even if timer not fired', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(seconds: 10), // Long interval
      );

      // Write (timer starts but won't fire for 10s)
      writer.write(testRecord(message: 'Message 1'));
      writer.write(testRecord(message: 'Message 2'));

      // Nothing flushed yet
      expect(File(logPath).existsSync(), isFalse);

      // Close should flush
      await writer.close();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('Message 1'));
      expect(content, contains('Message 2'));
    });

    test('flush() flushes pending buffer and cancels timer', () async {
      await fakeAsyncWithDrain((async) async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
          flushInterval: const Duration(seconds: 5),
        );

        // Write (timer starts)
        writer.write(testRecord(message: 'Message 1'));

        // Flush manually before timer fires
        await writer.flush();
        await drainEvent();

        final content = File(logPath).readAsStringSync();
        expect(content, contains('Message 1'));

        // Wait past original timer time
        async.elapse(const Duration(seconds: 10));
        await drainEvent();

        // No duplicate write from timer (it was cancelled)
        expect(File(logPath).readAsStringSync(), content,
            reason: 'Timer should be cancelled, no duplicate write');

        await writer.close();
        await drainEvent();
      });
    });

    test('records written during async flush are flushed after it completes',
        () async {
      await fakeAsyncWithDrain((async) async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
        );

        // Write a record - starts timer
        writer.write(testRecord(message: 'Batch 1'));

        // Timer fires, starts async flush (_pendingFlush becomes non-null)
        async.elapse(const Duration(seconds: 1));

        // While the async flush is in-flight, write another record.
        // This goes into _buffer but no timer is running (it already fired).
        writer.write(testRecord(message: 'During flush'));

        // Let the first flush complete — whenComplete should restart the timer
        await drainEvent();

        // Batch 1 should be on disk now
        final content1 = File(logPath).readAsStringSync();
        expect(content1, contains('Batch 1'));
        expect(content1, isNot(contains('During flush')),
            reason: 'Record written during flush should still be buffered');

        // Advance time for the restarted timer to fire
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        // Now the second record should be flushed
        final content2 = File(logPath).readAsStringSync();
        expect(content2, contains('Batch 1'));
        expect(content2, contains('During flush'),
            reason: 'Record written during flush should be flushed '
                'after the restarted timer fires');

        await writer.close();
        await drainEvent();
      });
    });

    test('sustained logging: each flush resets timer for next batch', () async {
      await fakeAsyncWithDrain((async) async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
        );

        // Batch 1
        writer.write(testRecord(message: 'Batch 1 - Msg 1'));
        writer.write(testRecord(message: 'Batch 1 - Msg 2'));
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        var content = File(logPath).readAsStringSync();
        expect(content, contains('Batch 1 - Msg 1'));
        expect(content, contains('Batch 1 - Msg 2'));

        // Batch 2
        writer.write(testRecord(message: 'Batch 2 - Msg 1'));
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        content = File(logPath).readAsStringSync();
        expect(content, contains('Batch 2 - Msg 1'));

        // Batch 3
        writer.write(testRecord(message: 'Batch 3 - Msg 1'));
        writer.write(testRecord(message: 'Batch 3 - Msg 2'));
        writer.write(testRecord(message: 'Batch 3 - Msg 3'));
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        // All batches flushed
        content = File(logPath).readAsStringSync();
        expect(content, contains('Batch 1 - Msg 1'));
        expect(content, contains('Batch 1 - Msg 2'));
        expect(content, contains('Batch 2 - Msg 1'));
        expect(content, contains('Batch 3 - Msg 1'));
        expect(content, contains('Batch 3 - Msg 2'));
        expect(content, contains('Batch 3 - Msg 3'));

        await writer.close();
        await drainEvent();
      });
    });
  });

  group('pending records during locked operations', () {
    test('close() writes records that arrived during flush()', () async {
      await fakeAsyncWithDrain((async) async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
        );

        // Write a record and let it flush
        writer.write(testRecord(message: 'First'));
        async.elapse(const Duration(seconds: 1));
        await drainEvent();

        expect(File(logPath).readAsStringSync(), contains('First'));

        // Start a flush — this acquires the lock
        final flushFuture = writer.flush();

        // While flush holds the lock, write() buffers to _pendingRecords
        writer.write(testRecord(message: 'During flush'));

        await flushFuture;
        await drainEvent();

        // Now close — should drain _pendingRecords before closing
        await writer.close();
        await drainEvent();

        final content = File(logPath).readAsStringSync();
        expect(content, contains('First'));
        expect(content, contains('During flush'),
            reason: 'Records written during flush() should be preserved '
                'by close()');
      });
    });
  });

  test('createRotatingFileWriter has same signature in io and stub', () {
    // Both conditional import files must have identical signatures.
    // Cross-assigning verifies they are the same type. A signature mismatch
    // in either file causes a compile error here.
    // ignore: unused_local_variable
    var fn = io_impl.createRotatingFileWriter;
    fn = stub_impl.createRotatingFileWriter;

    var fn2 = stub_impl.createRotatingFileWriter;
    fn2 = io_impl.createRotatingFileWriter;

    // Suppress unused variable warning
    expect(fn, isNotNull);
    expect(fn2, isNotNull);
  });

  group('baseFilePathProvider validation', () {
    test('throws when sync provider returns path ending with /', () {
      final tempDir = createTempDir();
      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => '${tempDir.path}/logs/',
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));

      expect(capturedError, isA<ArgumentError>());
      // No file or directory should have been created
      expect(
        Directory('${tempDir.path}/logs').existsSync(),
        isFalse,
        reason: 'No directory should be created when path is invalid',
      );
    });

    test('error message for trailing slash mentions file path', () {
      final tempDir = createTempDir();
      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => '${tempDir.path}/logs/',
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));

      expect(capturedError, isA<ArgumentError>());
      expect(
        capturedError.toString(),
        contains('must return a file path, not a directory'),
      );
    });

    test('throws when sync provider returns path ending with backslash', () {
      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => r'C:\logs\',
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));

      expect(capturedError, isA<ArgumentError>());
      expect(
        capturedError.toString(),
        contains('must return a file path, not a directory'),
      );
    });

    test('throws when sync provider returns path of existing directory', () {
      final tempDir = createTempDir();
      final dirPath = '${tempDir.path}/existingdir';
      Directory(dirPath).createSync();

      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => dirPath,
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));

      expect(capturedError, isA<ArgumentError>());
      expect(
        capturedError.toString(),
        contains('is an existing directory, not a file'),
      );
    });

    test('throws when async provider returns path ending with /', () async {
      final tempDir = createTempDir();
      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () async => '${tempDir.path}/logs/',
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));
      // Wait for async path resolution
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<ArgumentError>());
      expect(
        capturedError.toString(),
        contains('must return a file path, not a directory'),
      );
    });

    test('throws when async provider returns existing directory', () async {
      final tempDir = createTempDir();
      final dirPath = '${tempDir.path}/existingdir';
      Directory(dirPath).createSync();

      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () async => dirPath,
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<ArgumentError>());
      expect(
        capturedError.toString(),
        contains('is an existing directory, not a file'),
      );
    });

    test('async validation error is thrown on every subsequent write',
        () async {
      final tempDir = createTempDir();
      final writer = RotatingFileWriter(
        baseFilePathProvider: () async => '${tempDir.path}/logs/',
        onError: (_, __, ___) {},
      );
      addTearDown(() => writer.close());

      // First write buffers while async resolves
      writer.write(testRecord(message: 'first'));
      await Future<void>.delayed(Duration.zero);

      // Every subsequent write throws the original error synchronously
      expect(
        () => writer.write(testRecord(message: 'second')),
        throwsArgumentError,
      );
      expect(
        () => writer.write(testRecord(message: 'third')),
        throwsArgumentError,
      );
    });

    test('async provider failure is thrown on every subsequent write',
        () async {
      final writer = RotatingFileWriter(
        baseFilePathProvider: () async => throw StateError('disk not found'),
        onError: (_, __, ___) {},
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'first'));
      await Future<void>.delayed(Duration.zero);

      expect(
        () => writer.write(testRecord(message: 'second')),
        throwsStateError,
      );
      expect(
        () => writer.write(testRecord(message: 'third')),
        throwsStateError,
      );
    });

    test('accepts file path without extension', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/logfile';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'no extension'));
      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('no extension'));
    });

    test('accepts path where parent directory does not exist yet', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/nonexistent/deep/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'deep path'));
      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('deep path'));
    });

    test('rejects path that is just a slash', () {
      Object? capturedError;
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => '/',
        onError: (error, _, __) {
          capturedError = error;
        },
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'test'));

      expect(capturedError, isA<ArgumentError>());
    });
  });

  group('clearLogs', () {
    test('deletes current log file', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);

      writer.write(testRecord(message: 'some log'));
      await writer.flush();
      expect(File(logPath).existsSync(), isTrue);

      await writer.clearLogs();

      expect(File(logPath).existsSync(), isFalse,
          reason: 'Current log file should be deleted');
    });

    test('deletes rotated log files', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        rotationConfig: FileRotationConfig.size(maxSize: 10),
      );

      // Write enough to trigger rotation
      for (var i = 0; i < 5; i++) {
        writer.write(testRecord(message: 'Record number $i'));
      }
      await writer.flush();

      // Verify rotated files exist
      final files = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(files.length, greaterThan(1),
          reason: 'Should have rotated files before clearing');

      await writer.clearLogs();

      final remainingFiles =
          Directory(tempDir.path).listSync().whereType<File>().toList();
      expect(remainingFiles, isEmpty,
          reason: 'All log files should be deleted');
    });

    test('writer remains usable after clearLogs', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'before clear'));
      await writer.flush();

      await writer.clearLogs();
      expect(File(logPath).existsSync(), isFalse);

      // Write again after clearing
      writer.write(testRecord(message: 'after clear'));
      await writer.flush();

      expect(File(logPath).existsSync(), isTrue,
          reason: 'File should be recreated on next write');
      final content = File(logPath).readAsStringSync();
      expect(content, contains('after clear'));
      expect(content, isNot(contains('before clear')),
          reason: 'Old content should not be present');
    });

    test('is a no-op when no files exist', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);

      // clearLogs without ever writing should not throw
      await writer.clearLogs();

      expect(File(logPath).existsSync(), isFalse);
    });

    test('waits for async baseFilePathProvider before clearing', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final completer = Completer<String>();
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => completer.future,
      );

      // Write a record (buffered, path not resolved yet)
      writer.write(testRecord(message: 'pending record'));

      // Start clearing before path resolves
      final clearFuture = writer.clearLogs();

      // Resolve the path — clearLogs should pick it up
      completer.complete(logPath);

      await clearFuture;

      // File should not exist — clearLogs waited for path then deleted
      expect(File(logPath).existsSync(), isFalse,
          reason: 'clearLogs should wait for path resolution and delete files');
    });
  });

  group('file deleted externally', () {
    test('recreates file when deleted between synchronous writes', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.synchronous,
      );
      addTearDown(() => writer.close());

      // First write creates the file
      writer.write(testRecord(message: 'before delete'));
      await writer.flush();
      expect(File(logPath).existsSync(), isTrue);
      expect(File(logPath).readAsStringSync(), contains('before delete'));

      // External process deletes the file
      File(logPath).deleteSync();
      expect(File(logPath).existsSync(), isFalse);

      // Next write should recreate the file
      writer.write(testRecord(message: 'after delete'));
      await writer.flush();

      expect(File(logPath).existsSync(), isTrue,
          reason: 'File should be recreated after external deletion');
      final content = File(logPath).readAsStringSync();
      expect(content, contains('after delete'),
          reason: 'New record should be written to recreated file');
    });

    test('recreates file when deleted between buffered writes', () {
      fakeAsync((async) {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => logPath,
          flushStrategy: FlushStrategy.buffered,
        );

        // First write - use error level so it flushes immediately
        writer.write(
          testRecord(message: 'before delete', level: ChirpLogLevel.error),
        );
        expect(File(logPath).existsSync(), isTrue);
        expect(File(logPath).readAsStringSync(), contains('before delete'));

        // External process deletes the file
        File(logPath).deleteSync();
        expect(File(logPath).existsSync(), isFalse);

        // Next error write should recreate the file
        writer.write(
          testRecord(message: 'after delete', level: ChirpLogLevel.error),
        );

        expect(File(logPath).existsSync(), isTrue,
            reason: 'File should be recreated after external deletion');
        final content = File(logPath).readAsStringSync();
        expect(content, contains('after delete'));

        writer.close();
        async.flushMicrotasks();
      });
    });

    test('recreates file and parent directories when both are deleted',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/logs/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.synchronous,
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'before delete'));
      await writer.flush();
      expect(File(logPath).existsSync(), isTrue);

      // External process deletes the entire directory
      Directory('${tempDir.path}/logs').deleteSync(recursive: true);
      expect(File(logPath).existsSync(), isFalse);
      expect(Directory('${tempDir.path}/logs').existsSync(), isFalse);

      // Next write should recreate directory and file
      writer.write(testRecord(message: 'after dir delete'));
      await writer.flush();

      expect(File(logPath).existsSync(), isTrue,
          reason: 'File and parent dir should be recreated');
      expect(File(logPath).readAsStringSync(), contains('after dir delete'));
    });

    test('does not lose records written before deletion is detected', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        flushStrategy: FlushStrategy.synchronous,
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'record 1'));
      await writer.flush();

      // Delete the file
      File(logPath).deleteSync();

      // Write multiple records after deletion
      writer.write(testRecord(message: 'record 2'));
      writer.write(testRecord(message: 'record 3'));
      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('record 2'));
      expect(content, contains('record 3'));
    });
  });

  group('FlushStrategy default', () {
    test('defaults to synchronous in debug mode (asserts enabled)', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePathProvider: () => logPath);
      addTearDown(() => writer.close());

      // In test (debug) mode, default should be synchronous
      expect(writer.flushStrategy, FlushStrategy.synchronous);
    });
  });
}

/// Creates a temporary directory for a test and registers cleanup.
Directory createTempDir() {
  final tempDir =
      Directory.systemTemp.createTempSync('chirp_file_writer_test_');
  addTearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
  return tempDir;
}

String formatRecord(ChirpFormatter formatter, LogRecord record) {
  final buffer = FileMessageBuffer();
  formatter.format(record, MessageBuffer(buffer));
  return buffer.toString();
}

/// A formatter that always throws, used to test error handling.
class _ThrowingFormatter extends ChirpFormatter {
  @override
  bool get requiresCallerInfo => false;

  @override
  void format(LogRecord record, MessageBuffer buffer) {
    throw StateError('Simulated formatter error');
  }
}

class _CapturingFormatter extends ChirpFormatter {
  final List<LogRecord> records;
  final bool _requiresCallerInfo;

  _CapturingFormatter(
    this.records, {
    bool requiresCallerInfo = false,
  }) : _requiresCallerInfo = requiresCallerInfo;

  @override
  bool get requiresCallerInfo => _requiresCallerInfo;

  @override
  void format(LogRecord record, MessageBuffer buffer) {
    records.add(record);
    buffer.write(record.message?.toString() ?? '');
  }
}

class _CallerLocationFormatter extends ChirpFormatter {
  const _CallerLocationFormatter();

  @override
  bool get requiresCallerInfo => true;

  @override
  void format(LogRecord record, MessageBuffer buffer) {
    final callerInfo = record.callerInfo;
    if (callerInfo == null) {
      buffer.write('no-caller');
      return;
    }
    buffer.write(callerInfo.callerLocation);
  }
}
