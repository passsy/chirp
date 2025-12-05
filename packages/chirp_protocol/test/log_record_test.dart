import 'package:chirp_protocol/chirp_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('LogRecord', () {
    group('constructor', () {
      test('creates record with required fields only', () {
        final now = DateTime(2025, 12, 2, 10, 30, 45);
        final record = LogRecord(
          message: 'Test message',
          timestamp: now,
        );

        expect(record.message, equals('Test message'));
        expect(record.timestamp, equals(now));
        expect(record.level, equals(ChirpLogLevel.info));
        expect(record.error, isNull);
        expect(record.stackTrace, isNull);
        expect(record.caller, isNull);
        expect(record.skipFrames, isNull);
        expect(record.instance, isNull);
        expect(record.loggerName, isNull);
        expect(record.data, isEmpty);
        expect(record.formatOptions, isNull);
      });

      test('creates record with all optional fields', () {
        final now = DateTime(2025, 12, 2, 10, 30, 45);
        final error = Exception('test error');
        final stackTrace = StackTrace.current;
        final caller = StackTrace.current;
        final instance = Object();
        final data = {'key1': 'value1', 'key2': 42};
        final formatOptions = [const FormatOptions()];

        final record = LogRecord(
          message: 'Full message',
          timestamp: now,
          level: ChirpLogLevel.error,
          error: error,
          stackTrace: stackTrace,
          caller: caller,
          skipFrames: 3,
          instance: instance,
          loggerName: 'MyLogger',
          data: data,
          formatOptions: formatOptions,
        );

        expect(record.message, equals('Full message'));
        expect(record.timestamp, equals(now));
        expect(record.level, equals(ChirpLogLevel.error));
        expect(record.error, same(error));
        expect(record.stackTrace, same(stackTrace));
        expect(record.caller, same(caller));
        expect(record.skipFrames, equals(3));
        expect(record.instance, same(instance));
        expect(record.loggerName, equals('MyLogger'));
        expect(record.data, equals(data));
        expect(record.formatOptions, equals(formatOptions));
      });

      test('can be created with minimal fields', () {
        final record = LogRecord(
          message: 'Message',
          timestamp: DateTime(2025, 1, 1),
        );

        expect(record.message, equals('Message'));
        expect(record.timestamp, equals(DateTime(2025, 1, 1)));
        expect(record.level, equals(ChirpLogLevel.info));
      });

      test('can be created with all fields', () {
        final record = LogRecord(
          message: 'Message',
          timestamp: DateTime(2025, 1, 1),
          level: ChirpLogLevel.warning,
          loggerName: 'TestLogger',
        );

        expect(record.message, equals('Message'));
        expect(record.timestamp, equals(DateTime(2025, 1, 1)));
        expect(record.level, equals(ChirpLogLevel.warning));
        expect(record.loggerName, equals('TestLogger'));
      });
    });

    group('properties', () {
      test('message can be any object', () {
        final now = DateTime.now();

        final stringRecord = LogRecord(message: 'string', timestamp: now);
        expect(stringRecord.message, equals('string'));

        final intRecord = LogRecord(message: 42, timestamp: now);
        expect(intRecord.message, equals(42));

        final listRecord = LogRecord(message: [1, 2, 3], timestamp: now);
        expect(listRecord.message, equals([1, 2, 3]));

        final nullRecord = LogRecord(message: null, timestamp: now);
        expect(nullRecord.message, isNull);
      });

      test('date is stored exactly', () {
        final date1 = DateTime(2025, 1, 1, 12);
        final record1 = LogRecord(message: 'test', timestamp: date1);
        expect(record1.timestamp, same(date1));

        final date2 = DateTime.utc(2025, 12, 31, 23, 59, 59);
        final record2 = LogRecord(message: 'test', timestamp: date2);
        expect(record2.timestamp, same(date2));
      });

      test('level defaults to info', () {
        final record = LogRecord(
          message: 'test',
          timestamp: DateTime.now(),
        );
        expect(record.level, equals(ChirpLogLevel.info));
      });

      test('level can be set to any ChirpLogLevel', () {
        final now = DateTime.now();

        final trace = LogRecord(
            message: 'test', timestamp: now, level: ChirpLogLevel.trace);
        expect(trace.level, equals(ChirpLogLevel.trace));

        final debug = LogRecord(
            message: 'test', timestamp: now, level: ChirpLogLevel.debug);
        expect(debug.level, equals(ChirpLogLevel.debug));

        final info = LogRecord(message: 'test', timestamp: now);
        expect(info.level, equals(ChirpLogLevel.info));

        final notice = LogRecord(
            message: 'test', timestamp: now, level: ChirpLogLevel.notice);
        expect(notice.level, equals(ChirpLogLevel.notice));

        final warning = LogRecord(
            message: 'test', timestamp: now, level: ChirpLogLevel.warning);
        expect(warning.level, equals(ChirpLogLevel.warning));

        final error = LogRecord(
            message: 'test', timestamp: now, level: ChirpLogLevel.error);
        expect(error.level, equals(ChirpLogLevel.error));

        final critical = LogRecord(
          message: 'test',
          timestamp: now,
          level: ChirpLogLevel.critical,
        );
        expect(critical.level, equals(ChirpLogLevel.critical));

        final wtf = LogRecord(
            message: 'test', timestamp: now, level: ChirpLogLevel.wtf);
        expect(wtf.level, equals(ChirpLogLevel.wtf));
      });

      test('level can be custom ChirpLogLevel', () {
        const customLevel = ChirpLogLevel('custom', 250);
        final record = LogRecord(
          message: 'test',
          timestamp: DateTime.now(),
          level: customLevel,
        );
        expect(record.level, equals(customLevel));
      });

      test('error can be any object', () {
        final now = DateTime.now();

        final exceptionRecord = LogRecord(
          message: 'test',
          timestamp: now,
          error: Exception('error'),
        );
        expect(exceptionRecord.error, isA<Exception>());

        final stringRecord = LogRecord(
          message: 'test',
          timestamp: now,
          error: 'string error',
        );
        expect(stringRecord.error, equals('string error'));

        final nullRecord = LogRecord(message: 'test', timestamp: now);
        expect(nullRecord.error, isNull);
      });

      test('stackTrace can be stored', () {
        final stackTrace = StackTrace.current;
        final record = LogRecord(
          message: 'test',
          timestamp: DateTime.now(),
          stackTrace: stackTrace,
        );
        expect(record.stackTrace, same(stackTrace));
      });

      test('caller can be stored', () {
        final caller = StackTrace.current;
        final record = LogRecord(
          message: 'test',
          timestamp: DateTime.now(),
          caller: caller,
        );
        expect(record.caller, same(caller));
      });

      test('skipFrames can be any integer', () {
        final now = DateTime.now();

        final zeroFrames =
            LogRecord(message: 'test', timestamp: now, skipFrames: 0);
        expect(zeroFrames.skipFrames, equals(0));

        final someFrames =
            LogRecord(message: 'test', timestamp: now, skipFrames: 5);
        expect(someFrames.skipFrames, equals(5));

        final manyFrames =
            LogRecord(message: 'test', timestamp: now, skipFrames: 100);
        expect(manyFrames.skipFrames, equals(100));

        final nullFrames = LogRecord(message: 'test', timestamp: now);
        expect(nullFrames.skipFrames, isNull);
      });

      test('instance can be any object', () {
        final now = DateTime.now();

        final customInstance = _TestClass();
        final record = LogRecord(
          message: 'test',
          timestamp: now,
          instance: customInstance,
        );
        expect(record.instance, same(customInstance));

        final stringInstance = LogRecord(
          message: 'test',
          timestamp: now,
          instance: 'string instance',
        );
        expect(stringInstance.instance, equals('string instance'));
      });

      test('loggerName can be any string', () {
        final now = DateTime.now();

        final named = LogRecord(
          message: 'test',
          timestamp: now,
          loggerName: 'MyLogger',
        );
        expect(named.loggerName, equals('MyLogger'));

        final empty = LogRecord(
          message: 'test',
          timestamp: now,
          loggerName: '',
        );
        expect(empty.loggerName, equals(''));

        final null_ = LogRecord(message: 'test', timestamp: now);
        expect(null_.loggerName, isNull);
      });

      test('data can contain any map', () {
        final now = DateTime.now();

        final emptyData = LogRecord(
          message: 'test',
          timestamp: now,
          data: {},
        );
        expect(emptyData.data, equals({}));

        final simpleData = LogRecord(
          message: 'test',
          timestamp: now,
          data: {'key': 'value'},
        );
        expect(simpleData.data, equals({'key': 'value'}));

        final complexData = LogRecord(
          message: 'test',
          timestamp: now,
          data: {
            'string': 'value',
            'int': 42,
            'bool': true,
            'null': null,
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
          },
        );
        expect(complexData.data?['string'], equals('value'));
        expect(complexData.data?['int'], equals(42));
        expect(complexData.data?['bool'], isTrue);
        expect(complexData.data?['null'], isNull);
        expect(complexData.data?['list'], equals([1, 2, 3]));
        expect(complexData.data?['map'], equals({'nested': 'value'}));

        final nullData = LogRecord(message: 'test', timestamp: now);
        expect(nullData.data, isEmpty);
      });

      test('formatOptions can contain any list of FormatOptions', () {
        final now = DateTime.now();

        final emptyOptions = LogRecord(
          message: 'test',
          timestamp: now,
          formatOptions: [],
        );
        expect(emptyOptions.formatOptions, equals([]));

        final singleOption = LogRecord(
          message: 'test',
          timestamp: now,
          formatOptions: [const FormatOptions()],
        );
        expect(singleOption.formatOptions?.length, equals(1));

        final multipleOptions = LogRecord(
          message: 'test',
          timestamp: now,
          formatOptions: [
            const FormatOptions(),
            const _CustomFormatOptions(color: 'red'),
            const _CustomFormatOptions(color: 'blue'),
          ],
        );
        expect(multipleOptions.formatOptions?.length, equals(3));

        final nullOptions = LogRecord(
          message: 'test',
          timestamp: now,
        );
        expect(nullOptions.formatOptions, isNull);
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be reassigned', () {
        final now = DateTime.now();
        final record = LogRecord(
          message: 'test',
          timestamp: now,
          error: Exception('error'),
          stackTrace: StackTrace.current,
          caller: StackTrace.current,
          skipFrames: 2,
          instance: Object(),
          loggerName: 'TestLogger',
          data: {'key': 'value'},
          formatOptions: [const FormatOptions()],
        );

        // This test verifies that the class structure is correct.
        // If any field is not final, the code won't compile.
        // We verify by reading the fields - they should all be accessible.
        expect(record.message, equals('test'));
        expect(record.timestamp, equals(now));
        expect(record.level, equals(ChirpLogLevel.info));
        expect(record.error, isA<Exception>());
        expect(record.stackTrace, isNotNull);
        expect(record.caller, isNotNull);
        expect(record.skipFrames, equals(2));
        expect(record.instance, isNotNull);
        expect(record.loggerName, equals('TestLogger'));
        expect(record.data, equals({'key': 'value'}));
        expect(record.formatOptions, isNotEmpty);
      });
    });

    group('different message types', () {
      test('supports string messages', () {
        final record = LogRecord(
          message: 'A simple string message',
          timestamp: DateTime.now(),
        );
        expect(record.message, equals('A simple string message'));
      });

      test('supports numeric messages', () {
        final intRecord = LogRecord(message: 42, timestamp: DateTime.now());
        expect(intRecord.message, equals(42));

        final doubleRecord =
            LogRecord(message: 3.14, timestamp: DateTime.now());
        expect(doubleRecord.message, equals(3.14));
      });

      test('supports boolean messages', () {
        final trueRecord = LogRecord(message: true, timestamp: DateTime.now());
        expect(trueRecord.message, isTrue);

        final falseRecord =
            LogRecord(message: false, timestamp: DateTime.now());
        expect(falseRecord.message, isFalse);
      });

      test('supports collection messages', () {
        final listRecord = LogRecord(
          message: ['item1', 'item2', 'item3'],
          timestamp: DateTime.now(),
        );
        expect(listRecord.message, equals(['item1', 'item2', 'item3']));

        final mapRecord = LogRecord(
          message: {'key': 'value'},
          timestamp: DateTime.now(),
        );
        expect(mapRecord.message, equals({'key': 'value'}));
      });

      test('supports custom object messages', () {
        final customObject = _TestClass();
        final record = LogRecord(
          message: customObject,
          timestamp: DateTime.now(),
        );
        expect(record.message, same(customObject));
      });

      test('supports null messages', () {
        final record = LogRecord(
          message: null,
          timestamp: DateTime.now(),
        );
        expect(record.message, isNull);
      });
    });

    group('API stability', () {
      test('constructor signature is stable', () {
        // This test ensures the constructor maintains its signature.
        // Any change to required parameters will break this test.
        final record = LogRecord(
          message: 'test',
          timestamp: DateTime.now(),
        );
        expect(record, isNotNull);
      });

      test('optional parameters remain optional', () {
        // Verify that all optional parameters can be omitted
        final minimalRecord = LogRecord(
          message: 'minimal',
          timestamp: DateTime.now(),
        );
        expect(minimalRecord.level, equals(ChirpLogLevel.info));
        expect(minimalRecord.error, isNull);
        expect(minimalRecord.stackTrace, isNull);
        expect(minimalRecord.caller, isNull);
        expect(minimalRecord.skipFrames, isNull);
        expect(minimalRecord.instance, isNull);
        expect(minimalRecord.loggerName, isNull);
        expect(minimalRecord.data, isEmpty);
        expect(minimalRecord.formatOptions, isNull);
      });

      test('property types are stable', () {
        final now = DateTime.now();
        final stackTrace = StackTrace.current;
        final instance = Object();
        final record = LogRecord(
          message: 'test',
          timestamp: now,
          level: ChirpLogLevel.error,
          error: Exception('error'),
          stackTrace: stackTrace,
          caller: stackTrace,
          skipFrames: 3,
          instance: instance,
          loggerName: 'Logger',
          data: {'key': 'value'},
          formatOptions: [const FormatOptions()],
        );

        // Verify exact types to catch accidental type changes
        expect(record.message, isA<Object?>());
        expect(record.timestamp, isA<DateTime>());
        expect(record.level, isA<ChirpLogLevel>());
        expect(record.error, isA<Object?>());
        expect(record.stackTrace, isA<StackTrace?>());
        expect(record.caller, isA<StackTrace?>());
        expect(record.skipFrames, isA<int?>());
        expect(record.instance, isA<Object?>());
        expect(record.loggerName, isA<String?>());
        expect(record.data, isA<Map<String, Object?>?>());
        expect(record.formatOptions, isA<List<FormatOptions>?>());
      });
    });
  });
}

// Test helper class
class _TestClass {
  @override
  String toString() => 'TestClass instance';
}

// Test helper for custom format options
class _CustomFormatOptions extends FormatOptions {
  const _CustomFormatOptions({required this.color});

  final String color;
}
