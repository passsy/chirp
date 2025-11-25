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
      final builder = ConsoleMessageBuffer();
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
      final builder = ConsoleMessageBuffer();
      formatter.format(entry, builder);
      final result = builder.build();

      // No instance = no hash suffix
      expect(result, '10:23:45.123 Unknown Test message');
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
      final builder = ConsoleMessageBuffer();
      formatter.format(entry, builder);
      final result = builder.build();

      final hash = identityHashCode(instance).toRadixString(16).padLeft(4, '0');
      final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);
      expect(
        result,
        '10:23:45.123 MyClass@$shortHash Test message\n'
        'Exception: Something went wrong',
      );
    });
  });
}

class _MyClass {}
