import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('JsonMessageFormatter', () {
    test('formats as JSON', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'MyClass',
        instance: instance,
      );

      final formatter = JsonMessageFormatter();
      final builder = ConsoleMessageBuffer();
      formatter.format(entry, builder);
      final result = builder.build();

      final hash = identityHashCode(instance).toRadixString(16);
      final decoded = jsonDecode(result) as Map<String, dynamic>;

      expect(decoded, {
        'timestamp': '2024-01-15T10:23:45.123',
        'level': 'info',
        'class': 'MyClass',
        'hash': hash,
        'message': 'Test message',
      });
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
      final builder = ConsoleMessageBuffer();
      formatter.format(entry, builder);
      final result = builder.build();

      final hash = identityHashCode(instance).toRadixString(16);
      final decoded = jsonDecode(result) as Map<String, dynamic>;

      expect(decoded, {
        'timestamp': '2024-01-15T10:23:45.123',
        'level': 'info',
        'class': 'MyClass',
        'hash': hash,
        'message': 'Test message',
        'error': 'Exception: Test error',
      });
    });

    test('includes stackTrace in JSON', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Test error'),
        stackTrace: StackTrace.fromString('#0      main (file.dart:10:5)'),
        loggerName: 'MyClass',
        instance: instance,
      );

      final formatter = JsonMessageFormatter();
      final builder = ConsoleMessageBuffer();
      formatter.format(entry, builder);
      final result = builder.build();

      final hash = identityHashCode(instance).toRadixString(16);
      final decoded = jsonDecode(result) as Map<String, dynamic>;

      expect(decoded, {
        'timestamp': '2024-01-15T10:23:45.123',
        'level': 'info',
        'class': 'MyClass',
        'hash': hash,
        'message': 'Test message',
        'error': 'Exception: Test error',
        'stackTrace': '#0      main (file.dart:10:5)',
      });
    });

    test('includes data in JSON', () {
      final instance = _MyClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'MyClass',
        instance: instance,
        data: {
          'userId': 'user_123',
          'action': 'login',
        },
      );

      final formatter = JsonMessageFormatter();
      final builder = ConsoleMessageBuffer();
      formatter.format(entry, builder);
      final result = builder.build();

      final hash = identityHashCode(instance).toRadixString(16);
      final decoded = jsonDecode(result) as Map<String, dynamic>;

      expect(decoded, {
        'timestamp': '2024-01-15T10:23:45.123',
        'level': 'info',
        'class': 'MyClass',
        'hash': hash,
        'message': 'Test message',
        'data': {
          'userId': 'user_123',
          'action': 'login',
        },
      });
    });
  });
}

class _MyClass {}
