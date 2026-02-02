// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('RainbowFormatOptions merge behavior', () {
    test('formatter with multiline default shows data on separate lines', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message\n'
        'userId: "user_123"\n'
        'action: "login"',
      );
    });

    test('formatter with inline default shows data on same line', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message (userId: "user_123", action: "login")',
      );
    });

    test('per-message inline option overrides multiline formatter default', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
        formatOptions: const [
          RainbowFormatOptions(data: DataPresentation.inline),
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message (userId: "user_123", action: "login")',
      );
    });

    test('per-message multiline option overrides inline formatter default', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
        formatOptions: const [
          RainbowFormatOptions(data: DataPresentation.multiline),
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message\n'
        'userId: "user_123"\n'
        'action: "login"',
      );
    });

    test('formatOptions with non-RainbowFormatOptions uses formatter default',
        () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
        formatOptions: const [
          FormatOptions(), // Not a RainbowFormatOptions
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message (userId: "user_123")',
      );
    });

    test('null formatOptions uses formatter default', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message\n'
        'userId: "user_123"',
      );
    });

    test('empty formatOptions list uses formatter default', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
        formatOptions: const [],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message (userId: "user_123")',
      );
    });

    test('first RainbowFormatOptions in list is used', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
        formatOptions: const [
          FormatOptions(),
          RainbowFormatOptions(data: DataPresentation.inline), // This one used
          RainbowFormatOptions(), // This one ignored
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.000 [info] Test message (userId: "user_123")',
      );
    });

    test('per-message showTime false hides timestamp for that entry only', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(),
      );

      final entry = testRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45),
        formatOptions: const [
          RainbowFormatOptions(
            showTime: false,
            showLocation: false,
            showLogger: false,
            showClass: false,
            showMethod: false,
          ),
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      // No timestamp prefix, just level and message
      expect(result.trimLeft(), '[info] Test message');
    });
  });
}
