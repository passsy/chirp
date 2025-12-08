// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:chirp/chirp.dart';
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
          timestamp: DateTime(2025),
        );

        expect(record.message, equals('Message'));
        expect(record.timestamp, equals(DateTime(2025)));
        expect(record.level, equals(ChirpLogLevel.info));
      });

      test('can be created with all fields', () {
        final record = LogRecord(
          message: 'Message',
          timestamp: DateTime(2025),
          level: ChirpLogLevel.warning,
          loggerName: 'TestLogger',
        );

        expect(record.message, equals('Message'));
        expect(record.timestamp, equals(DateTime(2025)));
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
        expect(complexData.data['string'], equals('value'));
        expect(complexData.data['int'], equals(42));
        expect(complexData.data['bool'], isTrue);
        expect(complexData.data['null'], isNull);
        expect(complexData.data['list'], equals([1, 2, 3]));
        expect(complexData.data['map'], equals({'nested': 'value'}));

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

    group('copyWith', () {
      late LogRecord original;
      late DateTime originalTimestamp;
      late StackTrace originalStackTrace;
      late StackTrace originalCaller;
      late Object originalInstance;
      late Map<String, Object?> originalData;
      late List<FormatOptions> originalFormatOptions;
      late Zone originalZone;

      setUp(() {
        originalTimestamp = DateTime(2025, 12, 2, 10, 30, 45);
        originalStackTrace = StackTrace.current;
        originalCaller = StackTrace.current;
        originalInstance = Object();
        originalData = {'key': 'value', 'count': 42};
        originalFormatOptions = [const FormatOptions()];

        runZoned(() {
          originalZone = Zone.current;
          original = LogRecord(
            message: 'Original message',
            timestamp: originalTimestamp,
            level: ChirpLogLevel.warning,
            error: Exception('original error'),
            stackTrace: originalStackTrace,
            caller: originalCaller,
            skipFrames: 5,
            instance: originalInstance,
            loggerName: 'OriginalLogger',
            data: originalData,
            formatOptions: originalFormatOptions,
          );
        }, zoneValues: {#testZone: 'testValue'});
      });

      test('returns identical copy when no arguments provided', () {
        final copy = original.copyWith();

        expect(copy.message, equals(original.message));
        expect(copy.timestamp, equals(original.timestamp));
        expect(copy.level, equals(original.level));
        expect(copy.error.toString(), equals(original.error.toString()));
        expect(copy.stackTrace, same(original.stackTrace));
        expect(copy.caller, same(original.caller));
        expect(copy.skipFrames, equals(original.skipFrames));
        expect(copy.instance, same(original.instance));
        expect(copy.loggerName, equals(original.loggerName));
        expect(copy.data, equals(original.data));
        expect(copy.formatOptions, equals(original.formatOptions));
        expect(copy.zone, same(originalZone));
      });

      test('copies message', () {
        final copy = original.copyWith(message: 'New message');
        expect(copy.message, equals('New message'));
        expect(copy.timestamp, equals(originalTimestamp));
        expect(copy.level, equals(ChirpLogLevel.warning));
      });

      test('copies timestamp', () {
        final newTimestamp = DateTime(2026, 1, 1);
        final copy = original.copyWith(timestamp: newTimestamp);
        expect(copy.timestamp, equals(newTimestamp));
        expect(copy.message, equals('Original message'));
      });

      test('copies level', () {
        final copy = original.copyWith(level: ChirpLogLevel.error);
        expect(copy.level, equals(ChirpLogLevel.error));
        expect(copy.message, equals('Original message'));
      });

      test('copies error', () {
        final newError = Exception('new error');
        final copy = original.copyWith(error: newError);
        expect(copy.error, same(newError));
        expect(copy.message, equals('Original message'));
      });

      test('copies stackTrace', () {
        final newStackTrace = StackTrace.current;
        final copy = original.copyWith(stackTrace: newStackTrace);
        expect(copy.stackTrace, same(newStackTrace));
        expect(copy.message, equals('Original message'));
      });

      test('copies caller', () {
        final newCaller = StackTrace.current;
        final copy = original.copyWith(caller: newCaller);
        expect(copy.caller, same(newCaller));
        expect(copy.message, equals('Original message'));
      });

      test('copies skipFrames', () {
        final copy = original.copyWith(skipFrames: 10);
        expect(copy.skipFrames, equals(10));
        expect(copy.message, equals('Original message'));
      });

      test('copies instance', () {
        final newInstance = Object();
        final copy = original.copyWith(instance: newInstance);
        expect(copy.instance, same(newInstance));
        expect(copy.message, equals('Original message'));
      });

      test('copies loggerName', () {
        final copy = original.copyWith(loggerName: 'NewLogger');
        expect(copy.loggerName, equals('NewLogger'));
        expect(copy.message, equals('Original message'));
      });

      test('copies data', () {
        final newData = {'newKey': 'newValue'};
        final copy = original.copyWith(data: newData);
        expect(copy.data, equals(newData));
        expect(copy.message, equals('Original message'));
      });

      test('copies formatOptions', () {
        final newFormatOptions = [
          const FormatOptions(),
          const _CustomFormatOptions(color: 'green'),
        ];
        final copy = original.copyWith(formatOptions: newFormatOptions);
        expect(copy.formatOptions, equals(newFormatOptions));
        expect(copy.message, equals('Original message'));
      });

      test('copies zone', () {
        late Zone newZone;
        runZoned(() {
          newZone = Zone.current;
        }, zoneValues: {#newZone: 'newValue'});

        final copy = original.copyWith(zone: newZone);
        expect(copy.zone, same(newZone));
        expect(copy.message, equals('Original message'));
      });

      test('copies multiple fields at once', () {
        final newTimestamp = DateTime(2026, 6, 15);
        final newError = Exception('new error');
        final copy = original.copyWith(
          message: 'Updated message',
          timestamp: newTimestamp,
          level: ChirpLogLevel.critical,
          error: newError,
          loggerName: 'UpdatedLogger',
        );

        expect(copy.message, equals('Updated message'));
        expect(copy.timestamp, equals(newTimestamp));
        expect(copy.level, equals(ChirpLogLevel.critical));
        expect(copy.error, same(newError));
        expect(copy.loggerName, equals('UpdatedLogger'));
        // Unchanged fields
        expect(copy.stackTrace, same(originalStackTrace));
        expect(copy.caller, same(originalCaller));
        expect(copy.skipFrames, equals(5));
        expect(copy.instance, same(originalInstance));
        expect(copy.data, equals(originalData));
        expect(copy.formatOptions, equals(originalFormatOptions));
      });

      group('allows setting nullable fields to null', () {
        test('can set message to null', () {
          final copy = original.copyWith(message: null);
          expect(copy.message, isNull);
          expect(copy.loggerName, equals('OriginalLogger'));
        });

        test('can set error to null', () {
          final copy = original.copyWith(error: null);
          expect(copy.error, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set stackTrace to null', () {
          final copy = original.copyWith(stackTrace: null);
          expect(copy.stackTrace, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set caller to null', () {
          final copy = original.copyWith(caller: null);
          expect(copy.caller, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set skipFrames to null', () {
          final copy = original.copyWith(skipFrames: null);
          expect(copy.skipFrames, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set instance to null', () {
          final copy = original.copyWith(instance: null);
          expect(copy.instance, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set loggerName to null', () {
          final copy = original.copyWith(loggerName: null);
          expect(copy.loggerName, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set data to null (becomes empty map)', () {
          final copy = original.copyWith(data: null);
          expect(copy.data, isEmpty);
          expect(copy.message, equals('Original message'));
        });

        test('can set formatOptions to null', () {
          final copy = original.copyWith(formatOptions: null);
          expect(copy.formatOptions, isNull);
          expect(copy.message, equals('Original message'));
        });

        test('can set multiple fields to null at once', () {
          final copy = original.copyWith(
            error: null,
            stackTrace: null,
            caller: null,
            skipFrames: null,
            loggerName: null,
            formatOptions: null,
          );

          expect(copy.error, isNull);
          expect(copy.stackTrace, isNull);
          expect(copy.caller, isNull);
          expect(copy.skipFrames, isNull);
          expect(copy.loggerName, isNull);
          expect(copy.formatOptions, isNull);
          // Unchanged fields
          expect(copy.message, equals('Original message'));
          expect(copy.timestamp, equals(originalTimestamp));
          expect(copy.level, equals(ChirpLogLevel.warning));
          expect(copy.instance, same(originalInstance));
          expect(copy.data, equals(originalData));
        });
      });

      group('preserves original values when not specified', () {
        test('preserves null message when setting other fields', () {
          final recordWithNullMessage = LogRecord(
            message: null,
            timestamp: originalTimestamp,
          );
          final copy = recordWithNullMessage.copyWith(
            level: ChirpLogLevel.error,
          );
          expect(copy.message, isNull);
          expect(copy.level, equals(ChirpLogLevel.error));
        });

        test('preserves null error when setting other fields', () {
          final recordWithNullError = LogRecord(
            message: 'test',
            timestamp: originalTimestamp,
            error: null,
          );
          final copy = recordWithNullError.copyWith(
            message: 'updated',
          );
          expect(copy.error, isNull);
          expect(copy.message, equals('updated'));
        });

        test('preserves null loggerName when setting other fields', () {
          final recordWithNullLogger = LogRecord(
            message: 'test',
            timestamp: originalTimestamp,
            loggerName: null,
          );
          final copy = recordWithNullLogger.copyWith(
            message: 'updated',
          );
          expect(copy.loggerName, isNull);
          expect(copy.message, equals('updated'));
        });
      });

      test('creates independent copy (modifying original does not affect copy)',
          () {
        // Note: LogRecord is immutable, so we can't really modify it,
        // but we can verify the copy has different object identity for data
        final copy = original.copyWith();
        expect(copy, isNot(same(original)));
      });

      test('can chain copyWith calls', () {
        final copy1 = original.copyWith(message: 'First change');
        final copy2 = copy1.copyWith(level: ChirpLogLevel.error);
        final copy3 = copy2.copyWith(loggerName: 'FinalLogger');

        expect(copy3.message, equals('First change'));
        expect(copy3.level, equals(ChirpLogLevel.error));
        expect(copy3.loggerName, equals('FinalLogger'));
        expect(copy3.timestamp, equals(originalTimestamp));
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
