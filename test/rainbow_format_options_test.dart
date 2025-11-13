import 'package:chirp/src/format_option.dart';
import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/rainbow_message_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('RainbowFormatOptions merge behavior', () {
    test('formatter with multiline default shows data on separate lines', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
      );

      final result = formatter.format(entry);

      // Should have multiple lines
      expect(result.split('\n').length, greaterThan(1));
      // Data should be on separate lines with │
      expect(result, contains('│ userId=user_123'));
      expect(result, contains('│ action=login'));
    });

    test('formatter with inline default shows data on same line', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
      );

      final result = formatter.format(entry);

      // Should be single line
      expect(result.split('\n').length, 1);
      // Data should be inline in parentheses
      expect(result, contains('('));
      expect(result, contains('userId=user_123'));
      expect(result, contains('action=login'));
    });

    test('per-message inline option overrides multiline formatter default', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
        formatOptions: const [
          RainbowFormatOptions(data: DataPresentation.inline),
        ],
      );

      final result = formatter.format(entry);

      // Should be single line despite multiline formatter default
      expect(result.split('\n').length, 1);
      expect(result, contains('('));
      expect(result, contains('userId=user_123'));
    });

    test('per-message multiline option overrides inline formatter default', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123', 'action': 'login'},
        formatOptions: const [
          RainbowFormatOptions(),
        ],
      );

      final result = formatter.format(entry);

      // Should have multiple lines despite inline formatter default
      expect(result.split('\n').length, greaterThan(1));
      expect(result, contains('│ userId=user_123'));
      expect(result, contains('│ action=login'));
    });

    test('formatOptions with non-RainbowFormatOptions uses formatter default',
        () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
        formatOptions: const [
          FormatOptions(), // Not a RainbowFormatOptions
        ],
      );

      final result = formatter.format(entry);

      // Should use formatter default (inline)
      expect(result.split('\n').length, 1);
      expect(result, contains('(userId=user_123)'));
    });

    test('null formatOptions uses formatter default', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
      );

      final result = formatter.format(entry);

      // Should use formatter default (multiline)
      expect(result.split('\n').length, greaterThan(1));
      expect(result, contains('│ userId=user_123'));
    });

    test('empty formatOptions list uses formatter default', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(data: DataPresentation.inline),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
        formatOptions: const [],
      );

      final result = formatter.format(entry);

      // Should use formatter default (inline)
      expect(result.split('\n').length, 1);
      expect(result, contains('(userId=user_123)'));
    });

    test('first RainbowFormatOptions in list is used', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(),
      );

      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45),
        data: {'userId': 'user_123'},
        formatOptions: const [
          FormatOptions(),
          RainbowFormatOptions(data: DataPresentation.inline), // This one used
          RainbowFormatOptions(), // This one ignored
        ],
      );

      final result = formatter.format(entry);

      // Should use first RainbowFormatOptions (inline)
      expect(result.split('\n').length, 1);
      expect(result, contains('(userId=user_123)'));
    });
  });
}
