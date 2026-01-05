import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('AwsMessageFormatter', () {
    ConsoleMessageBuffer createBuffer() {
      return ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(),
      );
    }

    test('formats basic log as JSON with timestamp, level, and message', () {
      final record = LogRecord(
        message: 'Server started',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30, 45, 123),
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded['level'], 'INFO');
      expect(decoded['message'], 'Server started');
    });

    test('maps log levels to AWS CloudWatch levels', () {
      final levels = {
        ChirpLogLevel.trace: 'TRACE',
        ChirpLogLevel.debug: 'DEBUG',
        ChirpLogLevel.info: 'INFO',
        ChirpLogLevel.notice: 'INFO', // notice maps to INFO
        ChirpLogLevel.success: 'INFO', // success maps to INFO
        ChirpLogLevel.warning: 'WARN',
        ChirpLogLevel.error: 'ERROR',
        ChirpLogLevel.critical: 'FATAL',
        ChirpLogLevel.wtf: 'FATAL', // wtf maps to FATAL
      };

      for (final entry in levels.entries) {
        final record = LogRecord(
          message: 'Test',
          timestamp: DateTime.utc(2024, 1, 15),
          level: entry.key,
        );

        final formatter = AwsMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, buffer);

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        expect(decoded['level'], entry.value,
            reason: 'Level ${entry.key.name} should map to ${entry.value}');
      }
    });

    test('uses UTC timestamp', () {
      final localTime = DateTime(2024, 1, 15, 12, 30, 45);
      final record = LogRecord(
        message: 'Test',
        timestamp: localTime,
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final timestamp = decoded['timestamp'] as String;

      expect(timestamp, endsWith('Z'));
      expect(timestamp, localTime.toUtc().toIso8601String());
    });

    test('includes logger name when provided', () {
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        loggerName: 'MyService',
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['logger'], 'MyService');
    });

    test('includes class and instance when instance is provided', () {
      final instance = _TestClass();
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        instance: instance,
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final expectedHash =
          identityHashCode(instance).toRadixString(16).padLeft(8, '0');

      expect(decoded['class'], '_TestClass');
      expect(decoded['instance'], '_TestClass@$expectedHash');
    });

    test('does not include logger, class, or instance when not provided', () {
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('logger'), isFalse);
      expect(decoded.containsKey('class'), isFalse);
      expect(decoded.containsKey('instance'), isFalse);
    });

    test('includes error when provided', () {
      final record = LogRecord(
        message: 'Operation failed',
        timestamp: DateTime.utc(2024, 1, 15),
        error: Exception('Something went wrong'),
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['error'], 'Exception: Something went wrong');
    });

    test('includes stackTrace when provided', () {
      final record = LogRecord(
        message: 'Error',
        timestamp: DateTime.utc(2024, 1, 15),
        stackTrace: StackTrace.fromString('#0      main (file.dart:10:5)'),
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['stackTrace'], '#0      main (file.dart:10:5)');
    });

    test('includes custom data fields at root level', () {
      final record = LogRecord(
        message: 'Request received',
        timestamp: DateTime.utc(2024, 1, 15),
        data: {
          'requestId': 'abc123',
          'method': 'GET',
          'path': '/api/users',
        },
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['requestId'], 'abc123');
      expect(decoded['method'], 'GET');
      expect(decoded['path'], '/api/users');
    });

    test('allows user data to override any field', () {
      final instance = _TestClass();
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        loggerName: 'MyLogger',
        instance: instance,
        data: {
          'timestamp': 'custom-timestamp',
          'level': 'custom-level',
          'message': 'custom-message',
          'logger': 'custom-logger',
          'class': 'custom-class',
          'instance': 'custom-instance',
        },
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // User data overrides all fields
      expect(decoded['timestamp'], 'custom-timestamp');
      expect(decoded['level'], 'custom-level');
      expect(decoded['message'], 'custom-message');
      expect(decoded['logger'], 'custom-logger');
      expect(decoded['class'], 'custom-class');
      expect(decoded['instance'], 'custom-instance');
    });

    test('outputs single-line JSON', () {
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        data: {'key': 'value'},
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final output = buffer.toString();
      expect(output.contains('\n'), isFalse);
    });

    test('converts non-serializable objects in data to string', () {
      final nonSerializable = _NonSerializableObject('test-value');
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        data: {
          'custom': nonSerializable,
        },
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();

      // Should not throw
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      expect(decoded['custom'], 'NonSerializableObject(test-value)');
    });

    group('sourceLocation', () {
      test('excludes sourceLocation by default', () {
        final record = LogRecord(
          message: 'Test',
          timestamp: DateTime.utc(2024, 1, 15),
          caller: StackTrace.fromString(
            '#0      MyClass.method (package:my_app/src/server.dart:42:10)',
          ),
        );

        final formatter = AwsMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, buffer);

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(decoded.containsKey('sourceLocation'), isFalse);
      });

      test('includes sourceLocation when enabled', () {
        final record = LogRecord(
          message: 'Test',
          timestamp: DateTime.utc(2024, 1, 15),
          caller: StackTrace.fromString(
            '#0      MyClass.method (package:my_app/src/server.dart:42:10)',
          ),
        );

        final formatter = AwsMessageFormatter(includeSourceLocation: true);
        final buffer = createBuffer();
        formatter.format(record, buffer);

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        final sourceLocation =
            decoded['sourceLocation'] as Map<String, dynamic>;

        expect(sourceLocation['file'], 'my_app/lib/src/server.dart');
        expect(sourceLocation['line'], 42);
        expect(sourceLocation['function'], 'MyClass.method');
      });

      test('requiresCallerInfo is true when includeSourceLocation is true', () {
        final formatter = AwsMessageFormatter(includeSourceLocation: true);
        expect(formatter.requiresCallerInfo, isTrue);
      });

      test('requiresCallerInfo is false when includeSourceLocation is false',
          () {
        // ignore: avoid_redundant_argument_values
        final formatter = AwsMessageFormatter(includeSourceLocation: false);
        expect(formatter.requiresCallerInfo, isFalse);
      });

      test('includes class from caller when sourceLocation is enabled', () {
        final record = LogRecord(
          message: 'Test',
          timestamp: DateTime.utc(2024, 1, 15),
          caller: StackTrace.fromString(
            '#0      MyClass.method (package:my_app/src/server.dart:42:10)',
          ),
        );

        final formatter = AwsMessageFormatter(includeSourceLocation: true);
        final buffer = createBuffer();
        formatter.format(record, buffer);

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(decoded['class'], 'MyClass');
        // No instance field when no instance object provided
        expect(decoded.containsKey('instance'), isFalse);
      });
    });

    test('handles null message', () {
      final record = LogRecord(
        message: null,
        timestamp: DateTime.utc(2024, 1, 15),
      );

      final formatter = AwsMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      expect(decoded['message'], isNull);
    });
  });
}

class _TestClass {}

class _NonSerializableObject {
  final String value;

  _NonSerializableObject(this.value);

  @override
  String toString() => 'NonSerializableObject($value)';
}
