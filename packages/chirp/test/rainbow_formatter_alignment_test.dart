// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('RainbowMessageFormatter output format', () {
    test('multiline data is formatted on separate lines', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      );
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'endpoint': '/api/profile',
        },
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Test message\n'
        'userId: "user_123"\n'
        'endpoint: "/api/profile"',
      );
    });

    test('inline data is formatted on same line', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = testRecord(
        message: 'Short',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'API',
        data: {'key': 'value'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:23:45.123 [info] API Short (key: "value")');
    });

    test('multiline message outputs each line', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Line 1\nLine 2\nLine 3',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:23:45.123 [info] Line 1\nLine 2\nLine 3');
    });

    test('message with metadata and data', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'VeryLongLoggerNameThatExceedsTheDefaultMetaWidth',
        caller: StackTrace.fromString(
          '#0      longMethodName (package:app/file.dart:100:5)',
        ),
        data: {'key': 'value'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] file:100 VeryLongLoggerNameThatExceedsTheDefaultMetaWidth longMethodName Test message (key: "value")',
      );
    });
  });

  group('RainbowMessageFormatter anonymous closure cleaning', () {
    test('removes anonymous closure from instance method', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      DeviceManager._startAutoConnectScanning.<anonymous closure>.<anonymous closure> (package:app/device_manager.dart:809:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        startsWith('10:23:45.123 [info] device_manager:809 _TestClass@'),
      );
      expect(
        result,
        contains(' _startAutoConnectScanning Test message'),
      );
      expect(result, isNot(contains('.<anonymous closure>')));
    });

    test('removes anonymous closure from static method', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        caller: StackTrace.fromString(
          '#0      UserService.logStatic.<anonymous closure> (package:app/user_service.dart:100:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] user_service:100 UserService logStatic Test message',
      );
    });

    test('removes anonymous closure from top-level function', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        caller: StackTrace.fromString(
          '#0      processData.<anonymous closure>.<anonymous closure> (package:app/utils.dart:42:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] utils:42 processData Test message',
      );
    });

    test('removes multiple nested anonymous closures', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      MyClass.myMethod.<anonymous closure>.<anonymous closure>.<anonymous closure> (package:app/my_class.dart:50:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        startsWith('10:23:45.123 [info] my_class:50 _TestClass@'),
      );
      expect(result, contains(' myMethod Test message'));
    });

    test('preserves method name when no anonymous closure present', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      MyClass.normalMethod (package:app/my_class.dart:50:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        startsWith('10:23:45.123 [info] my_class:50 _TestClass@'),
      );
      expect(result, contains(' normalMethod Test message'));
    });

    test(
        'handles instance method with matching class name and anonymous closures',
        () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      _TestClass.processData.<anonymous closure> (package:app/test_class.dart:100:5)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        startsWith('10:23:45.123 [info] test_class:100 _TestClass@'),
      );
      expect(result, contains(' processData Test message'));
    });
  });

  group('RainbowMessageFormatter color option', () {
    test('includes ANSI color codes when color is true (default)', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
            colorSupport: TerminalColorSupport.ansi256),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      // Should contain ANSI escape codes
      expect(result, contains(RegExp(r'\x1B\[')));
      // Verify stripped content is correct
      expect(_stripAnsiCodes(result), '10:23:45.123 [info] Test message');
    });

    test('excludes ANSI color codes when color is false', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:23:45.123 [info] Test message');
    });

    test('color:false produces plain text output', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        loggerName: 'TestLogger',
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        startsWith('10:23:45.123 [info] TestLogger _TestClass@'),
      );
      expect(result, endsWith(' Test message'));
    });
  });

  group('RainbowMessageFormatter format options', () {
    test('writes data on separate lines with multiline option', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      );
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'action': 'login',
        },
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Test message\n'
        'userId: "user_123"\n'
        'action: "login"',
      );
    });

    test('writes data inline when formatOptions contains dataInline', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'action': 'login',
        },
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Test message (userId: "user_123", action: "login")',
      );
    });

    test('inline data appears on same line as message', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );
      final entry = testRecord(
        message: 'User action',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
        },
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] User action (userId: "user_123")',
      );
    });

    test('inline data works with multiple properties', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );
      final entry = testRecord(
        message: 'Request',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'method': 'POST',
          'endpoint': '/api/users',
          'status': 200,
        },
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Request (method: "POST", endpoint: "/api/users", status: 200)',
      );
    });

    test('inline data with no data produces no inline annotation', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:23:45.123 [info] Test message');
    });
  });

  group('RainbowMessageFormatter instance formatting', () {
    test('instance label has single @ and 4-char hash', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      // Calculate expected short hash (last 4 hex digits)
      final hash = identityHashCode(instance).toRadixString(16).padLeft(4, '0');
      final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);

      // Should be exactly: "timestamp [info] _TestClass@XXXX message"
      expect(
        result,
        '10:23:45.123 [info] _TestClass@$shortHash Test message',
      );

      // Verify only one @ in the class portion
      final classMatch = RegExp('_TestClass@[0-9a-f]+').firstMatch(result);
      expect(classMatch, isNotNull);
      expect(classMatch!.group(0), '_TestClass@$shortHash');
    });

    test('instance hash is exactly 4 hex characters', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = testRecord(
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      // Extract the hash portion after _TestClass@
      final hashMatch = RegExp('_TestClass@([0-9a-f]+)').firstMatch(result);
      expect(hashMatch, isNotNull);
      final extractedHash = hashMatch!.group(1)!;
      expect(
        extractedHash.length,
        4,
        reason: 'Instance hash should be exactly 4 hex characters',
      );
    });
  });

  group('RainbowMessageFormatter exception formatting', () {
    test('exceptions are output on new line', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Operation failed',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Something went wrong'),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Operation failed\n'
        'Exception: Something went wrong',
      );
    });

    test('stack traces are output on separate lines', () {
      final formatter = RainbowMessageFormatter();
      final entry = testRecord(
        message: 'Error occurred',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Test error'),
        stackTrace: StackTrace.fromString(
          '#0      main (file.dart:10:5)\n#1      test (file.dart:20:3)',
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Error occurred\n'
        'Exception: Test error\n'
        '#0      main (file.dart:10:5)\n'
        '#1      test (file.dart:20:3)',
      );
    });
  });
}

class _TestClass {}

/// Strips ANSI color codes from a string
String _stripAnsiCodes(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKH]'), '');
}
