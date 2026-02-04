import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('SimpleFileFormatter', () {
    test('formats basic log record with timestamp, level, and message', () {
      const formatter = SimpleFileFormatter();
      final record = testRecord(
        message: 'Hello, World!',
        timestamp: DateTime(2024, 1, 15, 10, 30, 45, 123),
      );

      final result = formatter.format(record);

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

      final result = formatter.format(record);

      expect(result, contains('[MyApp.Service]'));
    });

    test('excludes logger name when includeLoggerName is false', () {
      const formatter = SimpleFileFormatter(includeLoggerName: false);
      final record = testRecord(
        message: 'Test',
        loggerName: 'MyApp.Service',
      );

      final result = formatter.format(record);

      expect(result, isNot(contains('[MyApp.Service]')));
    });

    test('includes structured data', () {
      const formatter = SimpleFileFormatter();
      final record = testRecord(
        message: 'User logged in',
        data: {'userId': 'abc123', 'role': 'admin'},
      );

      final result = formatter.format(record);

      expect(result, contains('userId'));
      expect(result, contains('abc123'));
    });

    test('excludes data when includeData is false', () {
      const formatter = SimpleFileFormatter(includeData: false);
      final record = testRecord(
        message: 'Test',
        data: {'key': 'value'},
      );

      final result = formatter.format(record);

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

      final result = formatter.format(record);

      expect(result, contains('Error:'));
      expect(result, contains('Something went wrong'));
      expect(result, contains('file_writer_test.dart'));
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
      const formatter = JsonFileFormatter();
      final ts = DateTime(2024, 1, 15, 10, 30, 45);
      final record = testRecord(
        message: 'Test message',
        timestamp: ts,
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
      const formatter = JsonFileFormatter();
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
      const formatter = JsonFileFormatter();
      const originalMessage = 'Line1\nLine2\tTabbed\r"Quoted"\\Escaped';
      final record = testRecord(message: originalMessage);

      final result = formatter.format(record);

      // Verify it's valid JSON and message survives round-trip
      final json = jsonDecode(result) as Map<String, Object?>;
      expect(json['message'], originalMessage,
          reason: 'Message should survive JSON encode/decode round-trip');
    });

    test('handles nested data structures', () {
      const formatter = JsonFileFormatter();
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
      const formatter = JsonFileFormatter();
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
      final logPath = '${tempDir.path}/app.jsonl';
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
          baseFilePath: logPath,
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

  group('Max age retention', () {
    test('deletes rotated files older than maxAge', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      // Create writer and write first message (creates file at real time)
      final writer1 = RotatingFileWriter(
        baseFilePath: logPath,
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
          baseFilePath: logPath,
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

    test('calling close() multiple times does not throw', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePath: logPath);

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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
        formatter: _ThrowingFormatter(),
        // onError is null - prints to stderr by default
      );
      addTearDown(() => writer.close());

      // This should not throw - error goes to stderr
      expect(
        () => writer.write(testRecord(message: 'Test')),
        returnsNormally,
        reason: 'Write should not throw - error should go to stderr',
      );
    });

    test('onError receives correct record for each failed write', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';

      final failedRecords = <LogRecord?>[];

      final writer = RotatingFileWriter(
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
        baseFilePath: logPath,
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
    });
  });

  group('FlushStrategy.buffered timer behavior', () {
    test('first write starts timer, flushes after flushInterval', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 50),
      );
      addTearDown(() => writer.close());

      // Write - starts timer
      writer.write(testRecord(message: 'Message 1'));

      // Immediately after write, file should not exist (buffered)
      expect(File(logPath).existsSync(), isFalse,
          reason: 'File should not exist immediately after write');

      // Wait for timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Now file should exist
      expect(File(logPath).existsSync(), isTrue,
          reason: 'File should exist after flushInterval');

      final content = File(logPath).readAsStringSync();
      expect(content, contains('Message 1'));
    });

    test('multiple writes before timer fires are batched together', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 100),
      );
      addTearDown(() => writer.close());

      // Write multiple messages quickly (before timer fires)
      writer.write(testRecord(message: 'Message 1'));
      writer.write(testRecord(message: 'Message 2'));
      writer.write(testRecord(message: 'Message 3'));

      // Immediately, nothing written yet
      expect(File(logPath).existsSync(), isFalse);

      // Wait for timer
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // All 3 messages should be written in one batch
      final content = File(logPath).readAsStringSync();
      expect(content, contains('Message 1'));
      expect(content, contains('Message 2'));
      expect(content, contains('Message 3'));

      final lines = content.trim().split('\n');
      expect(lines.length, 3, reason: 'All 3 messages batched in one flush');
    });

    test('timer resets after flush, next write starts new timer', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 50),
      );
      addTearDown(() => writer.close());

      // First batch
      writer.write(testRecord(message: 'Batch 1'));

      // Wait for first flush
      await Future<void>.delayed(const Duration(milliseconds: 100));

      var content = File(logPath).readAsStringSync();
      expect(content.trim().split('\n').length, 1);

      // Second batch - starts new timer
      writer.write(testRecord(message: 'Batch 2'));

      // Immediately, batch 2 not flushed yet
      content = File(logPath).readAsStringSync();
      expect(content.trim().split('\n').length, 1,
          reason: 'Batch 2 not yet flushed');

      // Wait for second timer
      await Future<void>.delayed(const Duration(milliseconds: 100));

      content = File(logPath).readAsStringSync();
      expect(content.trim().split('\n').length, 2,
          reason: 'Batch 2 should be flushed now');
      expect(content, contains('Batch 2'));
    });

    test('no timer fires when no writes happen', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 50),
      );
      addTearDown(() => writer.close());

      // Wait without writing anything
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // No file should be created
      expect(File(logPath).existsSync(), isFalse,
          reason: 'No file should be created when no writes happen');
    });

    test('error cancels pending timer and flushes buffer immediately', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
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
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 50),
      );
      addTearDown(() => writer.close());

      // Write error (flushes immediately)
      writer.write(testRecord(message: 'Error', level: ChirpLogLevel.error));

      expect(File(logPath).readAsStringSync().trim().split('\n').length, 1);

      // Write info after error - starts new timer
      writer.write(testRecord(message: 'Info after error'));

      // Info not flushed yet
      expect(File(logPath).readAsStringSync().trim().split('\n').length, 1);

      // Wait for new timer
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(File(logPath).readAsStringSync().trim().split('\n').length, 2);
    });

    test('close() flushes pending buffer even if timer not fired', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
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
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 100),
      );
      addTearDown(() => writer.close());

      // Write (timer starts)
      writer.write(testRecord(message: 'Message 1'));

      // Flush manually before timer fires
      await writer.flush();

      expect(File(logPath).readAsStringSync(), contains('Message 1'));
      final lineCount =
          File(logPath).readAsStringSync().trim().split('\n').length;

      // Wait past original timer time
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // No duplicate write from timer (it was cancelled)
      final newLineCount =
          File(logPath).readAsStringSync().trim().split('\n').length;
      expect(newLineCount, lineCount,
          reason: 'Timer should be cancelled, no duplicate write');
    });

    test('sustained logging: each flush resets timer for next batch', () async {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(
        baseFilePath: logPath,
        flushStrategy: FlushStrategy.buffered,
        flushInterval: const Duration(milliseconds: 30),
      );
      addTearDown(() => writer.close());

      // Write message, wait for flush, repeat
      writer.write(testRecord(message: 'Batch 1 - Msg 1'));
      writer.write(testRecord(message: 'Batch 1 - Msg 2'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // First batch flushed
      expect(File(logPath).readAsStringSync().trim().split('\n').length, 2);

      // Second batch
      writer.write(testRecord(message: 'Batch 2 - Msg 1'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Second batch flushed
      expect(File(logPath).readAsStringSync().trim().split('\n').length, 3);

      // Third batch
      writer.write(testRecord(message: 'Batch 3 - Msg 1'));
      writer.write(testRecord(message: 'Batch 3 - Msg 2'));
      writer.write(testRecord(message: 'Batch 3 - Msg 3'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Third batch flushed
      final finalLines =
          File(logPath).readAsStringSync().trim().split('\n').length;
      expect(finalLines, 6, reason: 'All 6 messages across 3 batches');
    });
  });

  group('FlushStrategy default', () {
    test('defaults to synchronous in debug mode (asserts enabled)', () {
      final tempDir = createTempDir();
      final logPath = '${tempDir.path}/app.log';
      final writer = RotatingFileWriter(baseFilePath: logPath);
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

/// A formatter that always throws, used to test error handling.
class _ThrowingFormatter implements FileMessageFormatter {
  @override
  String format(LogRecord record) {
    throw StateError('Simulated formatter error');
  }
}
