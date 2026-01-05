// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('JsonMessageFormatter', () {
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

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded['level'], 'info');
      expect(decoded['message'], 'Server started');
    });

    test('uses UTC timestamp', () {
      final localTime = DateTime(2024, 1, 15, 12, 30, 45);
      final record = LogRecord(
        message: 'Test',
        timestamp: localTime,
      );

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final timestamp = decoded['timestamp'] as String;

      expect(timestamp, endsWith('Z'));
      expect(timestamp, localTime.toUtc().toIso8601String());
    });

    test('uses Chirp level names', () {
      final levels = [
        ChirpLogLevel.trace,
        ChirpLogLevel.debug,
        ChirpLogLevel.info,
        ChirpLogLevel.notice,
        ChirpLogLevel.success,
        ChirpLogLevel.warning,
        ChirpLogLevel.error,
        ChirpLogLevel.critical,
        ChirpLogLevel.wtf,
      ];

      for (final level in levels) {
        final record = LogRecord(
          message: 'Test',
          timestamp: DateTime.utc(2024, 1, 15),
          level: level,
        );

        final formatter = JsonMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, buffer);

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        expect(decoded['level'], level.name,
            reason: 'Level ${level.name} should be preserved');
      }
    });

    test('includes logger name when provided', () {
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        loggerName: 'MyService',
      );

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['logger'], 'MyService');
    });

    test('includes instance and instanceHash when instance is provided', () {
      final instance = _TestClass();
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        instance: instance,
      );

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final expectedHash =
          identityHashCode(instance).toRadixString(16).padLeft(8, '0');

      // instance is the runtimeType, instanceHash is the identity hash
      expect(decoded['instance'], '_TestClass');
      expect(decoded['instanceHash'], expectedHash);
      // logger is NOT set when only instance is provided
      expect(decoded.containsKey('logger'), isFalse);
    });

    test('does not include logger, instance, or instanceHash when not provided',
        () {
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
      );

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('logger'), isFalse);
      expect(decoded.containsKey('instance'), isFalse);
      expect(decoded.containsKey('instanceHash'), isFalse);
    });

    test('logger and instance can both be present', () {
      final instance = _TestClass();
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        loggerName: 'MyService',
        instance: instance,
      );

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final expectedHash =
          identityHashCode(instance).toRadixString(16).padLeft(8, '0');

      // Both logger and instance are separate fields
      expect(decoded['logger'], 'MyService');
      expect(decoded['instance'], '_TestClass');
      expect(decoded['instanceHash'], expectedHash);
    });

    test('includes error when provided', () {
      final record = LogRecord(
        message: 'Operation failed',
        timestamp: DateTime.utc(2024, 1, 15),
        error: Exception('Something went wrong'),
      );

      final formatter = JsonMessageFormatter();
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

      final formatter = JsonMessageFormatter();
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

      final formatter = JsonMessageFormatter();
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
          'instance': 'custom-instance',
          'instanceHash': 'custom-instanceHash',
        },
      );

      final formatter = JsonMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, buffer);

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // User data overrides all fields
      expect(decoded['timestamp'], 'custom-timestamp');
      expect(decoded['level'], 'custom-level');
      expect(decoded['message'], 'custom-message');
      expect(decoded['logger'], 'custom-logger');
      expect(decoded['instance'], 'custom-instance');
      expect(decoded['instanceHash'], 'custom-instanceHash');
    });

    test('outputs single-line JSON', () {
      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        data: {'key': 'value'},
      );

      final formatter = JsonMessageFormatter();
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

      final formatter = JsonMessageFormatter();
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

        final formatter = JsonMessageFormatter();
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

        final formatter = JsonMessageFormatter(includeSourceLocation: true);
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
        final formatter = JsonMessageFormatter(includeSourceLocation: true);
        expect(formatter.requiresCallerInfo, isTrue);
      });

      test('requiresCallerInfo is false when includeSourceLocation is false',
          () {
        final formatter = JsonMessageFormatter(includeSourceLocation: false);
        expect(formatter.requiresCallerInfo, isFalse);
      });
    });

    test('handles null message', () {
      final record = LogRecord(
        message: null,
        timestamp: DateTime.utc(2024, 1, 15),
      );

      final formatter = JsonMessageFormatter();
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
