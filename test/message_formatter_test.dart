import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpMessageFormatter', () {
    test('CompactChirpMessageFormatter formats with class:hash', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'MyClass',
        instance: instance,
      );

      final formatter = CompactChirpMessageFormatter();
      final builder = ConsoleMessageBuilder();
      formatter.format(entry, builder);
      final result = builder.build();

      final hash = identityHashCode(instance).toRadixString(16).padLeft(4, '0');
      final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);
      expect(result, '10:23:45.123 MyClass@$shortHash Test message');
    });

    test('CompactChirpMessageFormatter handles null loggerName', () {
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final formatter = CompactChirpMessageFormatter();
      final builder = ConsoleMessageBuilder();
      formatter.format(entry, builder);
      final result = builder.build();

      expect(result, contains('10:23:45.123'));
      expect(result, contains('Test message'));
    });

    test('CompactChirpMessageFormatter handles error', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Something went wrong'),
        loggerName: 'MyClass',
        instance: instance,
      );

      final formatter = CompactChirpMessageFormatter();
      final builder = ConsoleMessageBuilder();
      formatter.format(entry, builder);
      final result = builder.build();

      expect(result, contains('10:23:45.123 MyClass@'));
      expect(result, contains('Test message'));
      expect(result, contains('Exception: Something went wrong'));
    });
  });

  group('JsonChirpMessageFormatter', () {
    test('formats as JSON', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'MyClass',
        instance: instance,
      );

      final formatter = JsonMessageFormatter();
      final builder = ConsoleMessageBuilder();
      formatter.format(entry, builder);
      final result = builder.build();

      expect(result, contains('"message":"Test message"'));
      expect(result, contains('"class":"MyClass"'));
      expect(result, contains('"timestamp":"2024-01-15T10:23:45.123"'));
    });

    test('includes error in JSON', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Test error'),
        loggerName: 'MyClass',
        instance: instance,
      );

      final formatter = JsonMessageFormatter();
      final builder = ConsoleMessageBuilder();
      formatter.format(entry, builder);
      final result = builder.build();

      expect(result, contains('"error":"Exception: Test error"'));
    });
  });
}

class _MyClass {}
