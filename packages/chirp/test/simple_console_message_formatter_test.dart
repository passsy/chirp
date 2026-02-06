// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('SimpleConsoleMessageFormatter', () {
    test('formats basic log record with all fields', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        message: 'User logged in',
        loggerName: 'payment',
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:30:45.123 [info] [payment] - User logged in');
    });

    test('formats with caller information', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        message: 'Test',
        caller: StackTrace.fromString(
          '#0      MyClass.myMethod (file:///main.dart:42:5)\n'
          '#1      main (file:///main.dart:10:3)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:30:45.123 [info] main:42 myMethod MyClass - Test');
    });

    test('formats with instance information', () {
      final instance = _TestClass();
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        instance: instance,
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      final hash = identityHashCode(instance).toRadixString(16).padLeft(8, '0');
      expect(result, contains('_TestClass@$hash'));
    });

    test('formats with structured data', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        message: 'User action',
        data: {'userId': 'user_123', 'action': 'login'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:30:45.123 [info] - User action (userId: "user_123", action: "login")',
      );
    });

    test('formats with error', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        message: 'Payment failed',
        level: ChirpLogLevel.error,
        error: Exception('Payment failed'),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:30:45.123 [error] - Payment failed\n'
        'Exception: Payment failed',
      );
    });

    test('formats with stack trace', () {
      final formatter = SimpleConsoleMessageFormatter();
      final stackTrace = StackTrace.fromString(
        '#0      PaymentService.process (payment_service.dart:78:5)\n'
        '#1      handlePayment (main.dart:123:12)',
      );
      final record = testRecord(
        message: 'Error',
        level: ChirpLogLevel.error,
        stackTrace: stackTrace,
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:30:45.123 [error] - Error\n'
        '#0      PaymentService.process (payment_service.dart:78:5)\n'
        '#1      handlePayment (main.dart:123:12)',
      );
    });

    test('hides logger name for root logger', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        loggerName: 'root',
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, isNot(contains('[root]')));
    });

    test('hides logger name when showLoggerName is false', () {
      final formatter = SimpleConsoleMessageFormatter(showLoggerName: false);
      final record = testRecord(
        loggerName: 'payment',
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, isNot(contains('[payment]')));
    });

    test('hides caller when showCaller is false', () {
      final formatter = SimpleConsoleMessageFormatter(showCaller: false);
      final record = testRecord(
        caller: StackTrace.fromString(
          '#0      MyClass.myMethod (file:///main.dart:42:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, isNot(contains('main.dart:42')));
    });

    test('hides instance when showInstance is false', () {
      final instance = _TestClass();
      final formatter = SimpleConsoleMessageFormatter(showInstance: false);
      final record = testRecord(
        instance: instance,
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, isNot(contains('_TestClass@')));
    });

    test('hides data when showData is false', () {
      final formatter = SimpleConsoleMessageFormatter(showData: false);
      final record = testRecord(
        data: {'key': 'value'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, isNot(contains('key=value')));
    });

    test('handles empty data map', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        data: {},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // Should not have a newline for data when data is empty
      expect(result.split('\n').length, 1);
    });

    test('handles null caller', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord();

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, contains(' - Test'));
    });

    test('extracts method name when different from class', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        caller: StackTrace.fromString(
          '#0      differentMethod (file:///main.dart:42:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, contains('differentMethod'));
    });

    test('extracts method from class.method format', () {
      final instance = _TestClass();
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        instance: instance,
        caller: StackTrace.fromString(
          '#0      _TestClass.doSomething (file:///main.dart:42:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, contains('doSomething'));
    });

    test('supports span transformers', () {
      final formatter = SimpleConsoleMessageFormatter(
        spanTransformers: [
          (tree, record) {
            tree.findFirst<LogMessage>()?.replaceWith(PlainText('TRANSFORMED'));
          },
        ],
      );
      final record = testRecord(
        message: 'Original',
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:30:45.123 [info] - TRANSFORMED');
    });

    test('shows caller class name without hash when no instance', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        caller: StackTrace.fromString(
          '#0      CallerClass.method (file:///main.dart:42:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, contains('CallerClass'));
      expect(result, isNot(contains('@')));
    });

    test('shows instance type with hash when instance present', () {
      final instance = _TestClass();
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        instance: instance,
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      final hash = identityHashCode(instance).toRadixString(16).padLeft(8, '0');
      expect(result, contains('_TestClass@$hash'));
    });

    test('prioritizes instance type over caller class when both present', () {
      final instance = _TestClass();
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        instance: instance,
        caller: StackTrace.fromString(
          '#0      DifferentClass.method (file:///main.dart:42:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      final hash = identityHashCode(instance).toRadixString(16).padLeft(8, '0');
      // Should show _TestClass (instance) with hash, not DifferentClass (caller)
      expect(result, contains('_TestClass@$hash'));
      expect(result, isNot(contains('DifferentClass@')));
    });
  });

  group('FullTimestamp', () {
    test('formats date with full precision', () {
      final timestamp = FullTimestamp(DateTime(2024, 1, 10, 10, 30, 45, 123));
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      timestamp.render(buffer);

      expect(buffer.toString(), '2024-01-10 10:30:45.123');
    });

    test('pads single digits', () {
      final timestamp = FullTimestamp(DateTime(2024, 1, 5, 9, 3, 5, 7));
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      timestamp.render(buffer);

      expect(buffer.toString(), '2024-01-05 09:03:05.007');
    });

    test('toString returns debug representation', () {
      final date = DateTime(2024, 1, 10, 10, 30, 45, 123);
      final timestamp = FullTimestamp(date);

      expect(timestamp.toString(), 'FullTimestamp($date)');
    });
  });

  group('BracketedLoggerName', () {
    test('formats name in brackets', () {
      final span = BracketedLoggerName('payment');
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      span.render(buffer);

      expect(buffer.toString(), '[payment]');
    });

    test('toString returns debug representation', () {
      final span = BracketedLoggerName('payment');

      expect(span.toString(), 'BracketedLoggerName("payment")');
    });
  });

  group('KeyValueData', () {
    test('formats data as key=value pairs', () {
      final span = KeyValueData({'userId': 'user_123', 'action': 'login'});
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      span.render(buffer);

      final result = buffer.toString();
      expect(result, contains('userId=user_123'));
      expect(result, contains('action=login'));
    });

    test('renders nothing for empty data', () {
      final span = KeyValueData({});
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      span.render(buffer);

      expect(buffer.toString(), isEmpty);
    });

    test('toString returns debug representation', () {
      final data = {'key': 'value'};
      final span = KeyValueData(data);

      expect(span.toString(), 'KeyValueData($data)');
    });
  });
}

class _TestClass {}
