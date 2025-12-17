import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('DelegatedChirpInterceptor', () {
    test('can be created with a function', () {
      final interceptor = DelegatedChirpInterceptor((record) => record);
      expect(interceptor, isA<ChirpInterceptor>());
    });

    test('intercept delegates to the provided function', () {
      var called = false;
      LogRecord? receivedRecord;

      final interceptor = DelegatedChirpInterceptor((record) {
        called = true;
        receivedRecord = record;
        return record;
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final result = interceptor.intercept(record);

      expect(called, isTrue);
      expect(receivedRecord, same(record));
      expect(result, same(record));
    });

    test('can pass through records unchanged', () {
      final interceptor = DelegatedChirpInterceptor((record) => record);
      final record = LogRecord(message: 'Test', timestamp: DateTime.now());

      final result = interceptor.intercept(record);

      expect(result, same(record));
    });

    test('can transform records', () {
      final interceptor = DelegatedChirpInterceptor((record) {
        return record.copyWith(message: 'Transformed: ${record.message}');
      });

      final record = LogRecord(message: 'Original', timestamp: DateTime.now());
      final result = interceptor.intercept(record);

      expect(result, isNotNull);
      expect(result!.message, 'Transformed: Original');
      expect(result.timestamp, record.timestamp);
    });

    test('can reject records by returning null', () {
      final interceptor = DelegatedChirpInterceptor((record) => null);
      final record = LogRecord(message: 'Test', timestamp: DateTime.now());

      final result = interceptor.intercept(record);

      expect(result, isNull);
    });

    test('can filter by log level', () {
      final interceptor = DelegatedChirpInterceptor((record) {
        return record.level >= ChirpLogLevel.warning ? record : null;
      });

      final debugRecord = LogRecord(
        message: 'Debug',
        timestamp: DateTime.now(),
        level: ChirpLogLevel.debug,
      );
      final warningRecord = LogRecord(
        message: 'Warning',
        timestamp: DateTime.now(),
        level: ChirpLogLevel.warning,
      );
      final errorRecord = LogRecord(
        message: 'Error',
        timestamp: DateTime.now(),
        level: ChirpLogLevel.error,
      );

      expect(interceptor.intercept(debugRecord), isNull);
      expect(interceptor.intercept(warningRecord), isNotNull);
      expect(interceptor.intercept(errorRecord), isNotNull);
    });

    test('can redact sensitive data', () {
      final interceptor = DelegatedChirpInterceptor((record) {
        final message = record.message.toString();
        if (message.contains('password')) {
          return record.copyWith(
            message: message.replaceAll(RegExp(r'password=\S+'), 'password=***'),
          );
        }
        return record;
      });

      final sensitiveRecord = LogRecord(
        message: 'User login password=secret123 successful',
        timestamp: DateTime.now(),
      );
      final normalRecord = LogRecord(
        message: 'User logged out',
        timestamp: DateTime.now(),
      );

      final redactedResult = interceptor.intercept(sensitiveRecord);
      final normalResult = interceptor.intercept(normalRecord);

      expect(redactedResult!.message, 'User login password=*** successful');
      expect(normalResult!.message, 'User logged out');
    });

    test('can enrich records with additional data', () {
      final interceptor = DelegatedChirpInterceptor((record) {
        return record.copyWith(data: {
          ...record.data,
          'enriched': true,
          'timestamp_ms': record.timestamp.millisecondsSinceEpoch,
        });
      });

      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime(2024, 1, 15),
        data: {'original': 'value'},
      );

      final result = interceptor.intercept(record);

      expect(result!.data['original'], 'value');
      expect(result.data['enriched'], true);
      expect(result.data['timestamp_ms'], isA<int>());
    });

    test('requiresCallerInfo defaults to false', () {
      final interceptor = DelegatedChirpInterceptor((record) => record);
      expect(interceptor.requiresCallerInfo, isFalse);
    });

    test('requiresCallerInfo can be set to true', () {
      final interceptor = DelegatedChirpInterceptor(
        (record) => record,
        requiresCallerInfo: true,
      );
      expect(interceptor.requiresCallerInfo, isTrue);
    });

    test('can be used with ChirpLogger', () {
      final processedMessages = <String>[];
      final writtenRecords = <LogRecord>[];

      final interceptor = DelegatedChirpInterceptor((record) {
        processedMessages.add(record.message.toString());
        return record.copyWith(message: '[INTERCEPTED] ${record.message}');
      });

      final writer = DelegatedChirpWriter((record) {
        writtenRecords.add(record);
      });

      final logger = ChirpLogger(name: 'Test')
          .addInterceptor(interceptor)
          .addWriter(writer);

      logger.info('Hello');

      expect(processedMessages, ['Hello']);
      expect(writtenRecords, hasLength(1));
      expect(writtenRecords.first.message, '[INTERCEPTED] Hello');
    });

    test('interceptors chain correctly', () {
      final first = DelegatedChirpInterceptor((record) {
        return record.copyWith(message: '1:${record.message}');
      });

      final second = DelegatedChirpInterceptor((record) {
        return record.copyWith(message: '2:${record.message}');
      });

      final writtenRecords = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) {
        writtenRecords.add(record);
      });

      final logger = ChirpLogger(name: 'Test')
          .addInterceptor(first)
          .addInterceptor(second)
          .addWriter(writer);

      logger.info('msg');

      expect(writtenRecords.first.message, '2:1:msg');
    });

    test('null from interceptor stops the chain', () {
      final first = DelegatedChirpInterceptor((record) {
        return record.level >= ChirpLogLevel.warning ? record : null;
      });

      var secondCalled = false;
      final second = DelegatedChirpInterceptor((record) {
        secondCalled = true;
        return record;
      });

      final writtenRecords = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) {
        writtenRecords.add(record);
      });

      final logger = ChirpLogger(name: 'Test')
          .addInterceptor(first)
          .addInterceptor(second)
          .addWriter(writer);

      logger.debug('This should be filtered');

      expect(secondCalled, isFalse);
      expect(writtenRecords, isEmpty);
    });

    test('can be used with writer-level interceptors', () {
      final loggerInterceptor = DelegatedChirpInterceptor((record) {
        return record.copyWith(message: 'LOGGER:${record.message}');
      });

      final writerInterceptor = DelegatedChirpInterceptor((record) {
        return record.copyWith(message: 'WRITER:${record.message}');
      });

      final writtenRecords = <LogRecord>[];
      final writer = DelegatedChirpWriter((record) {
        writtenRecords.add(record);
      })..addInterceptor(writerInterceptor);

      final logger = ChirpLogger(name: 'Test')
          .addInterceptor(loggerInterceptor)
          .addWriter(writer);

      logger.info('msg');

      expect(writtenRecords.first.message, 'WRITER:LOGGER:msg');
    });

    test('can be created with a function', () {
      final interceptor = DelegatedChirpInterceptor(_passThrough);
      expect(interceptor, isA<ChirpInterceptor>());
    });

    test('handles all log levels', () {
      final levels = <ChirpLogLevel>[];
      final interceptor = DelegatedChirpInterceptor((record) {
        levels.add(record.level);
        return record;
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
        interceptor.intercept(LogRecord(
          message: 'Test',
          timestamp: DateTime.now(),
          level: level,
        ));
      }

      expect(levels, allLevels);
    });

    test('handles records with error and stack trace', () {
      final interceptor = DelegatedChirpInterceptor((record) {
        if (record.error != null) {
          return record.copyWith(
            message: '${record.message} - Error: ${record.error}',
          );
        }
        return record;
      });

      final record = LogRecord(
        message: 'Operation failed',
        timestamp: DateTime.now(),
        error: Exception('Something went wrong'),
        stackTrace: StackTrace.current,
      );

      final result = interceptor.intercept(record);

      expect(
        result!.message,
        contains('Operation failed - Error: Exception: Something went wrong'),
      );
      expect(result.error, isA<Exception>());
      expect(result.stackTrace, isNotNull);
    });

    group('debugging support', () {
      test('captures creation site by default', () {
        final interceptor = DelegatedChirpInterceptor((record) => record);

        expect(interceptor.creationSite, isNotNull);
        expect(interceptor.creationSite!.line, greaterThan(0));
        expect(
          interceptor.creationSite!.file,
          contains('delegated_interceptor_test'),
        );
      });

      test('toString includes creation site location', () {
        final interceptor = DelegatedChirpInterceptor((record) => record);

        final str = interceptor.toString();
        expect(str, startsWith('DelegatedChirpInterceptor('));
        expect(str, contains('delegated_interceptor_test'));
        expect(str, contains(':'));
      });

      test('can disable creation site capture', () {
        final interceptor = DelegatedChirpInterceptor(
          (record) => record,
          captureCreationSite: false,
        );

        expect(interceptor.creationSite, isNull);
        expect(interceptor.toString(), 'DelegatedChirpInterceptor');
      });

      test('creation site identifies correct line', () {
        // Create interceptor on a specific line and verify it's captured
        final interceptor1 = DelegatedChirpInterceptor((record) => record);
        final line1 = interceptor1.creationSite!.line;

        // Next interceptor should have a different line
        final interceptor2 = DelegatedChirpInterceptor((record) => record);
        final line2 = interceptor2.creationSite!.line;

        expect(line2, greaterThan(line1));
      });
    });
  });
}

/// A simple pass-through function for const constructor test.
LogRecord? _passThrough(LogRecord record) => record;
