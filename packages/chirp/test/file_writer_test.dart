import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('SimpleFileFormatter', () {
    test('formats basic log record with timestamp, level, and message', () {
      final formatter = const SimpleFileFormatter();
      final record = testRecord(
        message: 'Hello, World!',
        timestamp: DateTime(2024, 1, 15, 10, 30, 45, 123),
        level: ChirpLogLevel.info,
      );

      final result = formatter.format(record);

      expect(
        result,
        equals('2024-01-15T10:30:45.123 [INFO    ] Hello, World!'),
      );
    });

    test('includes logger name when present', () {
      final formatter = const SimpleFileFormatter();
      final record = testRecord(
        message: 'Test',
        loggerName: 'MyApp.Service',
      );

      final result = formatter.format(record);

      expect(result, contains('[MyApp.Service]'));
    });

    test('excludes logger name when includeLoggerName is false', () {
      final formatter = const SimpleFileFormatter(includeLoggerName: false);
      final record = testRecord(
        message: 'Test',
        loggerName: 'MyApp.Service',
      );

      final result = formatter.format(record);

      expect(result, isNot(contains('[MyApp.Service]')));
    });

    test('includes structured data', () {
      final formatter = const SimpleFileFormatter();
      final record = testRecord(
        message: 'User logged in',
        data: {'userId': 'abc123', 'role': 'admin'},
      );

      final result = formatter.format(record);

      expect(result, contains('userId'));
      expect(result, contains('abc123'));
    });

    test('excludes data when includeData is false', () {
      final formatter = const SimpleFileFormatter(includeData: false);
      final record = testRecord(
        message: 'Test',
        data: {'key': 'value'},
      );

      final result = formatter.format(record);

      expect(result, isNot(contains('key')));
    });

    test('includes error and stack trace', () {
      final formatter = const SimpleFileFormatter();
      final record = testRecord(
        message: 'Operation failed',
        level: ChirpLogLevel.error,
        error: Exception('Something went wrong'),
        stackTrace: StackTrace.current,
      );

      final result = formatter.format(record);

      expect(result, contains('Error:'));
      expect(result, contains('Something went wrong'));
      expect(result, contains('file_writer_test.dart'));
    });

    test('formats all log levels correctly', () {
      final formatter = const SimpleFileFormatter();
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

        final result = formatter.format(record);
        expect(
          result,
          contains('[${level.name.toUpperCase().padRight(8)}]'),
          reason: 'Level $level should be formatted correctly',
        );
      }
    });
  });

  group('JsonFileFormatter', () {
    test('formats as valid JSON with required fields', () {
      final formatter = const JsonFileFormatter();
      final ts = DateTime(2024, 1, 15, 10, 30, 45);
      final record = testRecord(
        message: 'Test message',
        timestamp: ts,
        level: ChirpLogLevel.info,
      );

      final result = formatter.format(record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['timestamp'], '2024-01-15T10:30:45.000');
      expect(json['level'], 'info');
      expect(json['message'], 'Test message');
      expect(json.containsKey('logger'), isFalse,
          reason: 'logger should be omitted when null');
      expect(json.containsKey('data'), isFalse,
          reason: 'data should be omitted when empty');
    });

    test('includes all optional fields when present', () {
      final formatter = const JsonFileFormatter();
      final record = testRecord(
        message: 'Test',
        level: ChirpLogLevel.error,
        loggerName: 'MyLogger',
        data: {'key': 'value'},
        error: Exception('Test error'),
        stackTrace: StackTrace.current,
      );

      final result = formatter.format(record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['logger'], 'MyLogger');
      expect(json['data'], {'key': 'value'});
      expect(json['error'], contains('Test error'));
      expect(json['stackTrace'], isNotEmpty);
    });

    test('escapes special characters in strings to produce valid JSON', () {
      final formatter = const JsonFileFormatter();
      final originalMessage = 'Line1\nLine2\tTabbed\r"Quoted"\\Escaped';
      final record = testRecord(message: originalMessage);

      final result = formatter.format(record);

      // Verify it's valid JSON and message survives round-trip
      final json = jsonDecode(result) as Map<String, Object?>;
      expect(json['message'], originalMessage,
          reason: 'Message should survive JSON encode/decode round-trip');
    });

    test('handles nested data structures', () {
      final formatter = const JsonFileFormatter();
      final record = testRecord(
        message: 'Test',
        data: {
          'user': {'id': 123, 'name': 'John'},
          'tags': ['a', 'b', 'c'],
        },
      );

      final result = formatter.format(record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['data'], {
        'user': {'id': 123, 'name': 'John'},
        'tags': ['a', 'b', 'c'],
      });
    });

    test('handles null message', () {
      final formatter = const JsonFileFormatter();
      final record = testRecord(message: null);

      final result = formatter.format(record);
      final json = jsonDecode(result) as Map<String, Object?>;

      expect(json['message'], isNull);
    });
  });

  group('RotatingFileWriter', () {
    test('writes formatted log record to file', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePath: logPath);
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Test message'));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      expect(content, contains('Test message'),
          reason: 'Log file should contain the written message');
      expect(content, contains('[INFO'),
          reason: 'Log file should contain formatted level');
    });

    test('creates parent directories recursively if they do not exist',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/logs/subdir/deep/app.log';
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
      final writer1 = RotatingFileWriter(baseFilePath: logPath);
      writer1.write(testRecord(message: 'First message'));
      await writer1.close();

      // Write second message with new writer instance
      final writer2 = RotatingFileWriter(baseFilePath: logPath);
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
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        formatter: const JsonFileFormatter(),
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'JSON test'));

      await writer.flush();

      final content = File(logPath).readAsStringSync();
      final json = jsonDecode(content.trim()) as Map<String, Object?>;
      expect(json['message'], 'JSON test',
          reason: 'JsonFileFormatter should produce valid JSON');
    });

    test('integrates with ChirpLogger for real logging workflow', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePath: logPath);
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

    test('respects minLogLevel filtering inherited from ChirpWriter', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePath: logPath)
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
  });

  group('Size-based rotation', () {
    test('rotates when file exceeds max size', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.size(
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
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.size(
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

    test('adds counter suffix when multiple rotations occur in same second',
        () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.size(
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
      final allContent =
          files.map((f) => (f as File).readAsStringSync()).join();
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
  });

  group('Time-based rotation', () {
    test('rotates on hour change with hourly config', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.hourly(),
      );
      addTearDown(() => writer.close());

      // Write at 10:00
      writer.write(testRecord(
        message: 'Message at 10:00',
        timestamp: DateTime(2024, 1, 15, 10, 0, 0),
      ));

      // Write at 11:00 (should trigger rotation)
      writer.write(testRecord(
        message: 'Message at 11:00',
        timestamp: DateTime(2024, 1, 15, 11, 0, 0),
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
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.daily(),
      );
      addTearDown(() => writer.close());

      // Write on Jan 15
      writer.write(testRecord(
        message: 'Message on Jan 15',
        timestamp: DateTime(2024, 1, 15, 10, 0, 0),
      ));

      // Write on Jan 16 (should trigger rotation)
      writer.write(testRecord(
        message: 'Message on Jan 16',
        timestamp: DateTime(2024, 1, 16, 10, 0, 0),
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
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.daily(),
      );
      addTearDown(() => writer.close());

      // Write multiple times on same day (different hours)
      for (var i = 0; i < 5; i++) {
        final ts = DateTime(2024, 1, 15, 10 + i, 0, 0);
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
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig(
          rotationInterval: FileRotationInterval.weekly,
        ),
      );
      addTearDown(() => writer.close());

      // Write on Saturday Jan 13, 2024
      writer.write(testRecord(
        message: 'Message on Saturday',
        timestamp: DateTime(2024, 1, 13, 10, 0, 0),
      ));

      // Write on Monday Jan 15, 2024 (new week, should trigger rotation)
      writer.write(testRecord(
        message: 'Message on Monday',
        timestamp: DateTime(2024, 1, 15, 10, 0, 0),
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
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig(
          rotationInterval: FileRotationInterval.monthly,
        ),
      );
      addTearDown(() => writer.close());

      // Write on Jan 31
      writer.write(testRecord(
        message: 'Message in January',
        timestamp: DateTime(2024, 1, 31, 10, 0, 0),
      ));

      // Write on Feb 1 (new month, should trigger rotation)
      writer.write(testRecord(
        message: 'Message in February',
        timestamp: DateTime(2024, 2, 1, 10, 0, 0),
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
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.daily(compress: true),
      );
      addTearDown(() => writer.close());

      // Write on Jan 15
      writer.write(testRecord(
        message: 'Message to compress',
        timestamp: DateTime(2024, 1, 15, 10, 0, 0),
      ));

      // Write on Jan 16 (triggers rotation and compression)
      writer.write(testRecord(
        message: 'New day message',
        timestamp: DateTime(2024, 1, 16, 10, 0, 0),
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
      final fixedTime = DateTime(2024, 1, 15, 10, 0, 0);

      await withClock(Clock.fixed(fixedTime), () async {
        final tempDir = createTempDir();
        final logPath = '${tempDir.path}/app.log';
        // Use size-based config to avoid time-based rotation complications
        final writer = RotatingFileWriter(
          baseFilePath: logPath,
          rotationConfig: const FileRotationConfig.size(
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

  group('Max age retention', () {
    test('deletes rotated files older than maxAge', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      // Create writer and write first message (creates file at real time)
      final writer1 = RotatingFileWriter(
        baseFilePath: logPath,
        rotationConfig: const FileRotationConfig.size(
          maxSize: 50,
          maxAge: Duration(days: 7),
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
          baseFilePath: logPath,
          rotationConfig: const FileRotationConfig.size(
            maxSize: 50,
            maxAge: Duration(days: 7),
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
        baseFilePath: logPath,
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
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
      final writer = RotatingFileWriter(baseFilePath: logPath);
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
