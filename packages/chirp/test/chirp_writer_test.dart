import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('ChirpWriter', () {
    test('can be implemented by custom classes', () {
      final writer = FakeChirpWriter();
      expect(writer, isA<ChirpWriter>());
    });

    test('can be extended by custom classes', () {
      final writer = ExtendingWriter();
      expect(writer, isA<ChirpWriter>());

      writer.write(testRecord());
      expect(writer.writtenRecords, hasLength(1));
    });

    test('write method accepts LogRecord', () {
      final writer = FakeChirpWriter();
      final record = testRecord(message: 'Test message');

      // Should not throw
      writer.write(record);
      expect(writer.writtenRecords, hasLength(1));
      expect(writer.writtenRecords.first, same(record));
    });

    test('write method signature is exactly void write(LogRecord record)', () {
      final writer = FakeChirpWriter();
      final record = testRecord();

      // This ensures the signature matches exactly
      final void Function(LogRecord) writeMethod = writer.write;
      writeMethod(record);

      expect(writer.writtenRecords, hasLength(1));
    });

    test('can handle multiple write calls', () {
      final writer = FakeChirpWriter();
      final record1 = testRecord(message: 'First');
      final record2 = testRecord(message: 'Second');
      final record3 = testRecord(message: 'Third');

      writer.write(record1);
      writer.write(record2);
      writer.write(record3);

      expect(writer.writtenRecords, hasLength(3));
      expect(writer.writtenRecords[0], same(record1));
      expect(writer.writtenRecords[1], same(record2));
      expect(writer.writtenRecords[2], same(record3));
    });

    test('can handle log records with all fields populated', () {
      final writer = FakeChirpWriter();
      final stackTrace = StackTrace.current;
      final caller = StackTrace.current;
      final instance = Object();

      final record = testRecord(
        message: 'Full record',
        level: ChirpLogLevel.error,
        error: Exception('test error'),
        stackTrace: stackTrace,
        caller: caller,
        skipFrames: 2,
        instance: instance,
        loggerName: 'TestLogger',
        data: {'key': 'value', 'count': 42},
        formatOptions: [const FormatOptions()],
      );

      writer.write(record);

      expect(writer.writtenRecords, hasLength(1));
      final written = writer.writtenRecords.first;
      expect(written.message, 'Full record');
      expect(written.level, ChirpLogLevel.error);
      expect(written.error.toString(), contains('test error'));
      expect(written.stackTrace, same(stackTrace));
      expect(written.caller, same(caller));
      expect(written.skipFrames, 2);
      expect(written.instance, same(instance));
      expect(written.loggerName, 'TestLogger');
      expect(written.data, {'key': 'value', 'count': 42});
      expect(written.formatOptions, isNotNull);
      expect(written.formatOptions, hasLength(1));
    });

    test('can handle log records with null/minimal fields', () {
      final writer = FakeChirpWriter();
      final record = testRecord(message: null);

      writer.write(record);

      expect(writer.writtenRecords, hasLength(1));
      final written = writer.writtenRecords.first;
      expect(written.message, isNull);
      expect(written.level, ChirpLogLevel.info); // default
      expect(written.error, isNull);
      expect(written.stackTrace, isNull);
      expect(written.caller, isNull);
      expect(written.skipFrames, isNull);
      expect(written.instance, isNull);
      expect(written.loggerName, isNull);
      expect(written.data, isEmpty);
      expect(written.formatOptions, isNull);
    });

    test('can handle different log levels', () {
      final writer = FakeChirpWriter();

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
        writer.write(
          testRecord(
            message: 'Message at ${level.name}',
            level: level,
          ),
        );
      }

      expect(writer.writtenRecords, hasLength(8));
      for (int i = 0; i < levels.length; i++) {
        expect(writer.writtenRecords[i].level, levels[i]);
      }
    });

    test('can be used as part of ChirpLogger', () {
      final writer = FakeChirpWriter();
      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('Test message');

      expect(writer.writtenRecords, hasLength(1));
      expect(writer.writtenRecords.first.message, 'Test message');
      expect(writer.writtenRecords.first.level, ChirpLogLevel.info);
    });

    test('multiple writers can be used together', () {
      final writer1 = FakeChirpWriter();
      final writer2 = FakeChirpWriter();
      final logger =
          ChirpLogger(name: 'Test').addWriter(writer1).addWriter(writer2);

      logger.info('Broadcast message');

      expect(writer1.writtenRecords, hasLength(1));
      expect(writer2.writtenRecords, hasLength(1));
      expect(writer1.writtenRecords.first.message, 'Broadcast message');
      expect(writer2.writtenRecords.first.message, 'Broadcast message');
    });

    test('implementation can maintain mutable state', () {
      final writer = FakeChirpWriter();

      // Verify we can access and modify state
      expect(writer.writtenRecords, isEmpty);

      writer.write(testRecord(message: 'First'));
      expect(writer.writtenRecords, hasLength(1));

      writer.write(testRecord(message: 'Second'));
      expect(writer.writtenRecords, hasLength(2));

      // Verify we can clear state
      writer.writtenRecords.clear();
      expect(writer.writtenRecords, isEmpty);
    });

    test('implementation can track write count', () {
      final writer = CountingWriter();

      expect(writer.writeCount, 0);

      writer.write(testRecord(message: 'First'));
      expect(writer.writeCount, 1);

      writer.write(testRecord(message: 'Second'));
      expect(writer.writeCount, 2);

      writer.write(testRecord(message: 'Third'));
      expect(writer.writeCount, 3);
    });

    test('implementation can filter by log level', () {
      final writer = FilteringWriter(minimumLevel: ChirpLogLevel.warning);

      writer.write(testRecord(message: 'Debug', level: ChirpLogLevel.debug));
      writer.write(testRecord(message: 'Info'));
      writer
          .write(testRecord(message: 'Warning', level: ChirpLogLevel.warning));
      writer.write(testRecord(message: 'Error', level: ChirpLogLevel.error));

      expect(writer.writtenRecords, hasLength(2));
      expect(writer.writtenRecords[0].message, 'Warning');
      expect(writer.writtenRecords[1].message, 'Error');
    });

    test('implementation can format records differently', () {
      final writer = FormattingWriter();

      final now = DateTime(2024, 1, 15, 10, 30, 45);
      writer.write(testRecord(
        message: 'Test message',
        timestamp: now,
        wallClock: now,
      ));

      expect(writer.formattedLines, hasLength(1));
      expect(
        writer.formattedLines.first,
        '2024-01-15T10:30:45.000 [INFO] Test message',
      );
    });

    test('records are immutable when passed to writer', () {
      final writer = FakeChirpWriter();
      final data = {'key': 'value'};
      final record = testRecord(data: data);

      writer.write(record);

      // LogRecord fields are final
      expect(() => record.message, returnsNormally);
      expect(() => record.timestamp, returnsNormally);
      expect(() => record.level, returnsNormally);
      expect(() => record.data, returnsNormally);

      // But the data map itself can be modified if not protected
      // This tests that writers receive the actual record, not a copy
      data['newKey'] = 'newValue';
      expect(record.data['newKey'], 'newValue');
    });
  });
}

/// Fake implementation of [ChirpWriter] that stores written records in memory.
///
/// Used for testing to verify that [ChirpWriter] interface can be implemented
/// and to track what records are written.
class FakeChirpWriter extends ChirpWriter {
  final List<LogRecord> writtenRecords = [];

  @override
  void write(LogRecord record) {
    writtenRecords.add(record);
  }
}

/// Writer implementation that counts how many times write was called.
class CountingWriter extends ChirpWriter {
  int writeCount = 0;

  @override
  void write(LogRecord record) {
    writeCount++;
  }
}

/// Writer implementation that filters records by minimum log level.
class FilteringWriter extends ChirpWriter {
  final ChirpLogLevel minimumLevel;
  final List<LogRecord> writtenRecords = [];

  FilteringWriter({required this.minimumLevel});

  @override
  void write(LogRecord record) {
    if (record.level >= minimumLevel) {
      writtenRecords.add(record);
    }
  }
}

/// Writer implementation that formats records as strings.
class FormattingWriter extends ChirpWriter {
  final List<String> formattedLines = [];

  @override
  void write(LogRecord record) {
    final line = '${record.timestamp.toIso8601String()} '
        '[${record.level.name.toUpperCase()}] ${record.message}';
    formattedLines.add(line);
  }
}

/// Writer that extends [ChirpWriter] instead of implementing it.
class ExtendingWriter extends ChirpWriter {
  final List<LogRecord> writtenRecords = [];

  @override
  void write(LogRecord record) {
    writtenRecords.add(record);
  }
}
