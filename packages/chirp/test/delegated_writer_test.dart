import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('DelegatedChirpWriter', () {
    test('can be created with a function', () {
      final writer = DelegatedChirpWriter((record) {});
      expect(writer, isA<ChirpWriter>());
    });

    test('write delegates to the provided function', () {
      var called = false;
      LogRecord? receivedRecord;

      final writer = DelegatedChirpWriter((record) {
        called = true;
        receivedRecord = record;
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      writer.write(record);

      expect(called, isTrue);
      expect(receivedRecord, same(record));
    });

    test('can collect records in a list', () {
      final logs = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) => logs.add(record));

      final record1 = LogRecord(message: 'First', timestamp: DateTime.now());
      final record2 = LogRecord(message: 'Second', timestamp: DateTime.now());

      writer.write(record1);
      writer.write(record2);

      expect(logs, hasLength(2));
      expect(logs[0], same(record1));
      expect(logs[1], same(record2));
    });

    test('can format and output records', () {
      final formattedLines = <String>[];
      final writer = DelegatedChirpWriter((record) {
        final line = '${record.timestamp.toIso8601String()} '
            '[${record.level.name.toUpperCase()}] ${record.message}';
        formattedLines.add(line);
      });

      final now = DateTime(2024, 1, 15, 10, 30, 45);
      writer.write(LogRecord(
        message: 'Test message',
        timestamp: now,
        level: ChirpLogLevel.warning,
      ));

      expect(formattedLines, hasLength(1));
      expect(
        formattedLines.first,
        '2024-01-15T10:30:45.000 [WARNING] Test message',
      );
    });

    test('requiresCallerInfo defaults to false', () {
      final writer = DelegatedChirpWriter((record) {});
      expect(writer.requiresCallerInfo, isFalse);
    });

    test('requiresCallerInfo can be set to true', () {
      final writer = DelegatedChirpWriter(
        (record) {},
        requiresCallerInfo: true,
      );
      expect(writer.requiresCallerInfo, isTrue);
    });

    test('inherits interceptor support from ChirpWriter', () {
      final logs = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) => logs.add(record));

      expect(writer.interceptors, isEmpty);

      final interceptor = DelegatedChirpInterceptor((record) {
        return record.copyWith(message: '[INTERCEPTED] ${record.message}');
      });

      writer.addInterceptor(interceptor);

      expect(writer.interceptors, hasLength(1));
      expect(writer.interceptors.first, same(interceptor));
    });

    test('inherits minLogLevel support from ChirpWriter', () {
      final writer = DelegatedChirpWriter((record) {});

      expect(writer.minLogLevel, isNull);

      writer.setMinLogLevel(ChirpLogLevel.warning);

      expect(writer.minLogLevel, ChirpLogLevel.warning);
    });

    test('setMinLogLevel returns writer for chaining', () {
      final writer = DelegatedChirpWriter((record) {});

      final result = writer.setMinLogLevel(ChirpLogLevel.error);

      expect(result, same(writer));
    });

    test('addInterceptor returns writer for chaining', () {
      final writer = DelegatedChirpWriter((record) {});
      final interceptor = DelegatedChirpInterceptor((record) => record);

      final result = writer.addInterceptor(interceptor);

      expect(result, same(writer));
    });

    test('can be used with ChirpLogger', () {
      final logs = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) => logs.add(record));

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('Hello');
      logger.warning('World');

      expect(logs, hasLength(2));
      expect(logs[0].message, 'Hello');
      expect(logs[0].level, ChirpLogLevel.info);
      expect(logs[1].message, 'World');
      expect(logs[1].level, ChirpLogLevel.warning);
    });

    test('can be used alongside other writers', () {
      final logs1 = <LogRecord>[];
      final logs2 = <LogRecord>[];

      final writer1 = DelegatedChirpWriter((record) => logs1.add(record));
      final writer2 = DelegatedChirpWriter((record) => logs2.add(record));

      final logger = ChirpLogger(name: 'Test')
          .addWriter(writer1)
          .addWriter(writer2);

      logger.info('Broadcast');

      expect(logs1, hasLength(1));
      expect(logs2, hasLength(1));
      expect(logs1.first.message, 'Broadcast');
      expect(logs2.first.message, 'Broadcast');
    });

    test('handles records with all fields populated', () {
      LogRecord? captured;
      final writer = DelegatedChirpWriter((record) => captured = record);

      final stackTrace = StackTrace.current;
      final caller = StackTrace.current;
      final instance = Object();

      writer.write(LogRecord(
        message: 'Full record',
        timestamp: DateTime.now(),
        level: ChirpLogLevel.error,
        error: Exception('test error'),
        stackTrace: stackTrace,
        caller: caller,
        skipFrames: 2,
        instance: instance,
        loggerName: 'TestLogger',
        data: {'key': 'value'},
        formatOptions: [const FormatOptions()],
      ));

      expect(captured, isNotNull);
      expect(captured!.message, 'Full record');
      expect(captured!.level, ChirpLogLevel.error);
      expect(captured!.error.toString(), contains('test error'));
      expect(captured!.stackTrace, same(stackTrace));
      expect(captured!.caller, same(caller));
      expect(captured!.data, {'key': 'value'});
    });

    test('handles records with minimal fields', () {
      LogRecord? captured;
      final writer = DelegatedChirpWriter((record) => captured = record);

      writer.write(LogRecord(
        message: null,
        timestamp: DateTime.now(),
      ));

      expect(captured, isNotNull);
      expect(captured!.message, isNull);
      expect(captured!.level, ChirpLogLevel.info);
      expect(captured!.error, isNull);
      expect(captured!.stackTrace, isNull);
    });

    test('handles all log levels', () {
      final levels = <ChirpLogLevel>[];
      final writer = DelegatedChirpWriter((record) {
        levels.add(record.level);
      });

      final allLevels = [
        ChirpLogLevel.trace,
        ChirpLogLevel.debug,
        ChirpLogLevel.info,
        ChirpLogLevel.notice,
        ChirpLogLevel.warning,
        ChirpLogLevel.error,
        ChirpLogLevel.critical,
        ChirpLogLevel.wtf,
      ];

      for (final level in allLevels) {
        writer.write(LogRecord(
          message: 'Test',
          timestamp: DateTime.now(),
          level: level,
        ));
      }

      expect(levels, allLevels);
    });

    test('can track write count', () {
      var count = 0;
      final writer = DelegatedChirpWriter((record) => count++);

      writer.write(LogRecord(message: 'A', timestamp: DateTime.now()));
      writer.write(LogRecord(message: 'B', timestamp: DateTime.now()));
      writer.write(LogRecord(message: 'C', timestamp: DateTime.now()));

      expect(count, 3);
    });

    test('can send logs to external service (simulated)', () {
      final sentToService = <Map<String, dynamic>>[];

      final writer = DelegatedChirpWriter((record) {
        // Simulate sending to an external service
        sentToService.add({
          'message': record.message,
          'level': record.level.name,
          'timestamp': record.timestamp.toIso8601String(),
          'data': record.data,
        });
      });

      writer.write(LogRecord(
        message: 'User action',
        timestamp: DateTime(2024, 1, 15),
        level: ChirpLogLevel.info,
        data: {'userId': '123', 'action': 'login'},
      ));

      expect(sentToService, hasLength(1));
      expect(sentToService.first['message'], 'User action');
      expect(sentToService.first['level'], 'info');
      expect(sentToService.first['data']['userId'], '123');
    });

    test('writer-level interceptor transforms records', () {
      final logs = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) => logs.add(record))
          .addInterceptor(DelegatedChirpInterceptor((record) {
        return record.copyWith(message: '[TAGGED] ${record.message}');
      }));

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('Original');

      expect(logs, hasLength(1));
      expect(logs.first.message, '[TAGGED] Original');
    });

    test('writer-level interceptor can reject records', () {
      final logs = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) => logs.add(record))
          .addInterceptor(DelegatedChirpInterceptor((record) {
        // Only allow errors and above
        return record.level >= ChirpLogLevel.error ? record : null;
      }));

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('Should be filtered');
      logger.warning('Should be filtered');
      logger.error('Should pass');
      logger.critical('Should pass');

      expect(logs, hasLength(2));
      expect(logs[0].message, 'Should pass');
      expect(logs[1].message, 'Should pass');
    });

    test('removeInterceptor removes the interceptor', () {
      final writer = DelegatedChirpWriter((record) {});
      final interceptor = DelegatedChirpInterceptor((record) => record);

      writer.addInterceptor(interceptor);
      expect(writer.interceptors, hasLength(1));

      final removed = writer.removeInterceptor(interceptor);

      expect(removed, isTrue);
      expect(writer.interceptors, isEmpty);
    });

    test('removeInterceptor returns false for non-existent interceptor', () {
      final writer = DelegatedChirpWriter((record) {});
      final interceptor = DelegatedChirpInterceptor((record) => record);

      final removed = writer.removeInterceptor(interceptor);

      expect(removed, isFalse);
    });

    test('works with structured data', () {
      final logs = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) => logs.add(record));

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('Request received', data: {
        'method': 'GET',
        'path': '/api/users',
        'status': 200,
        'duration_ms': 45,
      });

      expect(logs, hasLength(1));
      expect(logs.first.data['method'], 'GET');
      expect(logs.first.data['path'], '/api/users');
      expect(logs.first.data['status'], 200);
      expect(logs.first.data['duration_ms'], 45);
    });

    group('debugging support', () {
      test('captures creation site by default', () {
        final writer = DelegatedChirpWriter((record) {});

        expect(writer.creationSite, isNotNull);
        expect(writer.creationSite!.line, greaterThan(0));
        expect(writer.creationSite!.file, contains('delegated_writer_test'));
      });

      test('toString includes creation site location', () {
        final writer = DelegatedChirpWriter((record) {});

        final str = writer.toString();
        expect(str, startsWith('DelegatedChirpWriter('));
        expect(str, contains('delegated_writer_test'));
        expect(str, contains(':'));
      });

      test('can disable creation site capture', () {
        final writer = DelegatedChirpWriter(
          (record) {},
          captureCreationSite: false,
        );

        expect(writer.creationSite, isNull);
        expect(writer.toString(), 'DelegatedChirpWriter');
      });

      test('creation site identifies correct line', () {
        // Create writer on a specific line and verify it's captured
        final writer1 = DelegatedChirpWriter((record) {});
        final line1 = writer1.creationSite!.line;

        // Next writer should have a different line
        final writer2 = DelegatedChirpWriter((record) {});
        final line2 = writer2.creationSite!.line;

        expect(line2, greaterThan(line1));
      });
    });
  });
}
