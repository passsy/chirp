import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/message_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpMessageFormatter', () {
    test('CompactChirpMessageFormatter formats with class:hash', () {
      final entry = LogEntry(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        className: 'MyClass',
        instanceHash: 0xa4f2,
        instance: _MyClass(),
      );

      final formatter = CompactChirpMessageFormatter();
      final result = formatter.format(entry);

      expect(result, '10:23:45.123 _MyClass:a4f2 Test message');
    });

    test('CompactChirpMessageFormatter handles null className', () {
      final entry = LogEntry(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instanceHash: 0xa4f2,
      );

      final formatter = CompactChirpMessageFormatter();
      final result = formatter.format(entry);

      expect(result, '10:23:45.123 Unknown:a4f2 Test message');
    });

    test('CompactChirpMessageFormatter handles error', () {
      final entry = LogEntry(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Something went wrong'),
        className: 'MyClass',
        instanceHash: 0xa4f2,
        instance: _MyClass(),
      );

      final formatter = CompactChirpMessageFormatter();
      final result = formatter.format(entry);

      expect(result, contains('10:23:45.123 _MyClass:a4f2 Test message'));
      expect(result, contains('Exception: Something went wrong'));
    });
  });

  group('JsonChirpMessageFormatter', () {
    test('formats as JSON', () {
      final entry = LogEntry(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        className: 'MyClass',
        instanceHash: 0xa4f2,
        instance: _MyClass(),
      );

      final formatter = JsonChirpMessageFormatter();
      final result = formatter.format(entry);

      expect(result, contains('"message":"Test message"'));
      expect(result, contains('"class":"_MyClass"'));
      expect(result, contains('"hash":"a4f2"'));
      expect(result, contains('"timestamp":"2024-01-15T10:23:45.123"'));
    });

    test('includes error in JSON', () {
      final entry = LogEntry(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Test error'),
        className: 'MyClass',
        instanceHash: 0xa4f2,
        instance: _MyClass(),
      );

      final formatter = JsonChirpMessageFormatter();
      final result = formatter.format(entry);

      expect(result, contains('"error":"Exception: Test error"'));
    });
  });
}

class _MyClass {}
