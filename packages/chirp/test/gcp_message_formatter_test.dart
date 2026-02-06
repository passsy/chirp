import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('GcpMessageFormatter', () {
    ConsoleMessageBuffer createBuffer() {
      return ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(),
      );
    }

    test('formats basic log as JSON with severity and message', () {
      final record = testRecord(
        message: 'Server started',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30, 45, 123),
        wallClock: DateTime.utc(2024, 1, 15, 10, 30, 45, 123),
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['severity'], 'INFO');
      expect(decoded['message'], 'Server started');
      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
    });

    test('maps log levels to GCP severity', () {
      final levels = {
        ChirpLogLevel.trace: 'DEFAULT', // severity 0 < 100
        ChirpLogLevel.debug: 'DEBUG', // severity 100
        ChirpLogLevel.info: 'INFO', // severity 200
        ChirpLogLevel.notice: 'NOTICE', // severity 300
        ChirpLogLevel.success: 'NOTICE', // severity 310
        ChirpLogLevel.warning: 'WARNING', // severity 400
        ChirpLogLevel.error: 'ERROR', // severity 500
        ChirpLogLevel.critical: 'CRITICAL', // severity 600
        ChirpLogLevel.wtf: 'EMERGENCY', // severity 1000
      };

      for (final entry in levels.entries) {
        final record = testRecord(
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          level: entry.key,
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        expect(decoded['severity'], entry.value,
            reason: 'Level ${entry.key.name} should map to ${entry.value}');
      }
    });

    test('includes custom data fields at root level', () {
      final record = testRecord(
        message: 'Request received',
        timestamp: DateTime.utc(2024, 1, 15, 10, 30, 45),
        wallClock: DateTime.utc(2024, 1, 15, 10, 30, 45),
        data: {
          'requestId': 'abc123',
          'method': 'GET',
          'path': '/api/users',
        },
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['requestId'], 'abc123');
      expect(decoded['method'], 'GET');
      expect(decoded['path'], '/api/users');
    });

    test('does not overwrite core fields (severity, message, timestamp)', () {
      final record = testRecord(
        message: 'Test',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        data: {
          'severity': 'SHOULD_NOT_OVERRIDE',
          'message': 'SHOULD_NOT_OVERRIDE',
          'timestamp': 'SHOULD_NOT_OVERRIDE',
        },
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['severity'], isNot('SHOULD_NOT_OVERRIDE'));
      expect(decoded['severity'], 'INFO');
      expect(decoded['message'], isNot('SHOULD_NOT_OVERRIDE'));
      expect(decoded['message'], 'Test');
      expect(decoded['timestamp'], isNot('SHOULD_NOT_OVERRIDE'));
      expect(decoded['timestamp'], '2024-01-15T00:00:00.000Z');
    });

    test('allows user to override logging.googleapis.com/labels', () {
      final record = testRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        loggerName: 'MyLogger', // This causes labels to be generated
        data: {
          'logging.googleapis.com/labels': {'custom': 'user-value'},
        },
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // User-provided labels should override formatter-generated labels
      final labels =
          decoded['logging.googleapis.com/labels'] as Map<String, dynamic>;
      expect(labels['custom'], 'user-value');
      expect(labels.containsKey('logger'), isFalse);
    });

    test('appends error and stack trace to message for Error Reporting', () {
      final record = testRecord(
        message: 'Operation failed',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.error,
        error: Exception('Something went wrong'),
        stackTrace: StackTrace.fromString('#0      main (file.dart:10:5)'),
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final message = decoded['message'] as String;

      expect(message, contains('Operation failed'));
      expect(message, contains('Exception: Something went wrong'));
      expect(message, contains('#0      main (file.dart:10:5)'));
    });

    test('includes sourceLocation when caller is provided', () {
      final record = testRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        caller: StackTrace.fromString(
          '#0      MyClass.method (package:my_app/src/server.dart:42:10)',
        ),
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final sourceLocation = decoded['logging.googleapis.com/sourceLocation']
          as Map<String, dynamic>;

      expect(sourceLocation['file'], 'my_app/lib/src/server.dart');
      expect(sourceLocation['line'], '42');
      expect(sourceLocation['function'], 'MyClass.method');
    });

    test('uses packageRelativePath for sourceLocation file', () {
      final record = testRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        caller: StackTrace.fromString(
          '#0      main (file:///Users/dev/project/bin/app.dart:10:5)',
        ),
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final sourceLocation = decoded['logging.googleapis.com/sourceLocation']
          as Map<String, dynamic>;

      expect(sourceLocation['file'], 'bin/app.dart');
    });

    test('excludes sourceLocation when includeSourceLocation is false', () {
      final record = testRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        caller: StackTrace.fromString(
          '#0      MyClass.method (package:my_app/src/server.dart:42:10)',
        ),
      );

      final formatter = GcpMessageFormatter(includeSourceLocation: false);
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(
        decoded.containsKey('logging.googleapis.com/sourceLocation'),
        isFalse,
      );
    });

    test('includes labels with logger, class, and instance', () {
      final instance = _TestClass();
      final record = testRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        loggerName: 'MyService',
        instance: instance,
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final labels =
          decoded['logging.googleapis.com/labels'] as Map<String, dynamic>;
      final expectedHash =
          identityHashCode(instance).toRadixString(16).padLeft(8, '0');

      expect(labels['logger'], 'MyService');
      expect(labels['class'], '_TestClass');
      expect(labels['instance'], '_TestClass@$expectedHash');
    });

    test('does not include instance when no instance provided', () {
      final record = testRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        loggerName: 'MyService',
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final labels =
          decoded['logging.googleapis.com/labels'] as Map<String, dynamic>;

      expect(labels['logger'], 'MyService');
      // class can still come from caller if sourceLocation is enabled
      expect(labels.containsKey('instance'), isFalse);
    });

    test('adds @type field for errors without stack trace', () {
      final record = testRecord(
        message: 'Error occurred',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.error,
        error: Exception('Test error'),
        // No stackTrace
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(
        decoded['@type'],
        'type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent',
      );
    });

    test('does not add @type field when error has stack trace', () {
      final record = testRecord(
        message: 'Error occurred',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.error,
        error: Exception('Test error'),
        stackTrace: StackTrace.fromString('#0      main (file.dart:10:5)'),
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('@type'), isFalse);
    });

    test('does not add @type field for non-error levels', () {
      final record = testRecord(
        message: 'Warning',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.warning,
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('@type'), isFalse);
    });

    test('includes serviceContext when serviceName is configured', () {
      final record = testRecord(
        message: 'Error occurred',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.error,
        error: Exception('Test error'),
      );

      final formatter = GcpMessageFormatter(
        serviceName: 'my-api',
        serviceVersion: '1.2.3',
      );
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final serviceContext = decoded['serviceContext'] as Map<String, dynamic>;

      expect(serviceContext['service'], 'my-api');
      expect(serviceContext['version'], '1.2.3');
    });

    test('does not include serviceContext when serviceName is not configured',
        () {
      final record = testRecord(
        message: 'Error occurred',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.error,
        error: Exception('Test error'),
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // @type is still included for Error Reporting
      expect(decoded.containsKey('@type'), isTrue);
      // But serviceContext requires explicit serviceName configuration
      expect(decoded.containsKey('serviceContext'), isFalse);
    });

    test('does not include Error Reporting fields when disabled', () {
      final record = testRecord(
        message: 'Error occurred',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        level: ChirpLogLevel.error,
        error: Exception('Test error'),
      );

      final formatter = GcpMessageFormatter(enableErrorReporting: false);
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('@type'), isFalse);
      expect(decoded.containsKey('serviceContext'), isFalse);
    });

    test('uses UTC timestamp', () {
      final localTime = DateTime(2024, 1, 15, 12, 30, 45);
      final record = testRecord(
        timestamp: localTime,
        wallClock: localTime,
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final timestamp = decoded['timestamp'] as String;

      expect(timestamp, endsWith('Z'));
      expect(timestamp, localTime.toUtc().toIso8601String());
    });

    test('requiresCallerInfo returns true when includeSourceLocation is true',
        () {
      // ignore: avoid_redundant_argument_values
      final formatter = GcpMessageFormatter(includeSourceLocation: true);
      expect(formatter.requiresCallerInfo, isTrue);
    });

    test('requiresCallerInfo returns false when includeSourceLocation is false',
        () {
      final formatter = GcpMessageFormatter(includeSourceLocation: false);
      expect(formatter.requiresCallerInfo, isFalse);
    });

    test('outputs single-line JSON (no newlines in output)', () {
      final record = testRecord(
        message: 'Test message',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        data: {'key': 'value'},
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();
      formatter.format(record, MessageBuffer(buffer));

      final output = buffer.toString();
      expect(output.contains('\n'), isFalse);
    });

    test('converts non-serializable objects in data to string', () {
      final nonSerializable = _NonSerializableObject('test-value');
      final record = testRecord(
        message: 'Request logged',
        timestamp: DateTime.utc(2024, 1, 15),
        wallClock: DateTime.utc(2024, 1, 15),
        data: {
          'request': nonSerializable,
          'nested': {
            'inner': _NonSerializableObject('nested-value'),
          },
          'list': [_NonSerializableObject('list-item')],
          'normalValue': 'this is fine',
          'number': 42,
        },
      );

      final formatter = GcpMessageFormatter();
      final buffer = createBuffer();

      // Should not throw
      formatter.format(record, MessageBuffer(buffer));

      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['request'], 'NonSerializableObject(test-value)');
      expect(
        (decoded['nested'] as Map<String, dynamic>)['inner'],
        'NonSerializableObject(nested-value)',
      );
      expect(
        (decoded['list'] as List).first,
        'NonSerializableObject(list-item)',
      );
      expect(decoded['normalValue'], 'this is fine');
      expect(decoded['number'], 42);
    });

    group('trace fields', () {
      test('allows user to set trace ID via data', () {
        final record = testRecord(
          message: 'Processing request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'logging.googleapis.com/trace':
                'projects/my-project/traces/463ac35c9f6413ad48485a3953bb6124',
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(
          decoded['logging.googleapis.com/trace'],
          'projects/my-project/traces/463ac35c9f6413ad48485a3953bb6124',
        );
      });

      test('allows user to set span ID via data', () {
        final record = testRecord(
          message: 'Processing request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'logging.googleapis.com/spanId': '0020000000000001',
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(decoded['logging.googleapis.com/spanId'], '0020000000000001');
      });

      test('allows user to set trace_sampled via data', () {
        final record = testRecord(
          message: 'Processing request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'logging.googleapis.com/trace_sampled': true,
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(decoded['logging.googleapis.com/trace_sampled'], true);
      });

      test('allows user to set all trace fields together', () {
        final record = testRecord(
          message: 'Processing request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'logging.googleapis.com/trace':
                'projects/my-project/traces/463ac35c9f6413ad48485a3953bb6124',
            'logging.googleapis.com/spanId': '0020000000000001',
            'logging.googleapis.com/trace_sampled': true,
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(
          decoded['logging.googleapis.com/trace'],
          'projects/my-project/traces/463ac35c9f6413ad48485a3953bb6124',
        );
        expect(decoded['logging.googleapis.com/spanId'], '0020000000000001');
        expect(decoded['logging.googleapis.com/trace_sampled'], true);
      });

      test('allows user to set insertId via data', () {
        final record = testRecord(
          message: 'Processing request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'logging.googleapis.com/insertId': 'unique-insert-id-123',
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(
          decoded['logging.googleapis.com/insertId'],
          'unique-insert-id-123',
        );
      });

      test('allows user to set operation via data', () {
        final record = testRecord(
          message: 'Processing request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'logging.googleapis.com/operation': {
              'id': 'operation-123',
              'producer': 'my-service',
              'first': true,
              'last': false,
            },
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        final operation =
            decoded['logging.googleapis.com/operation'] as Map<String, dynamic>;

        expect(operation['id'], 'operation-123');
        expect(operation['producer'], 'my-service');
        expect(operation['first'], true);
        expect(operation['last'], false);
      });
    });

    group('httpRequest field', () {
      test('extracts httpRequest from shelf-like Request object', () {
        final request = _MockShelfRequest(
          method: 'GET',
          requestedUri: Uri.parse('https://example.com/api/users?page=1'),
          protocolVersion: '1.1',
          contentLength: 0,
          headers: {
            'user-agent': 'Mozilla/5.0 (Test)',
            'referer': 'https://example.com/',
            'x-forwarded-for': '192.168.1.1, 10.0.0.1',
          },
        );

        final record = testRecord(
          message: 'Request received',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {'request': request},
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        final httpRequest = decoded['httpRequest'] as Map<String, dynamic>;

        expect(httpRequest['requestMethod'], 'GET');
        expect(
            httpRequest['requestUrl'], 'https://example.com/api/users?page=1');
        expect(httpRequest['protocol'], 'HTTP/1.1');
        expect(httpRequest['userAgent'], 'Mozilla/5.0 (Test)');
        expect(httpRequest['referer'], 'https://example.com/');
        expect(httpRequest['remoteIp'], '192.168.1.1');
        // Original request object should not be in the output
        expect(decoded.containsKey('request'), isFalse);
      });

      test('extracts httpRequest from shelf-like Response object', () {
        final response = _MockShelfResponse(
          statusCode: 200,
          contentLength: 1234,
        );

        final record = testRecord(
          message: 'Request completed',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {'response': response},
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        final httpRequest = decoded['httpRequest'] as Map<String, dynamic>;

        expect(httpRequest['status'], 200);
        expect(httpRequest['responseSize'], '1234');
        // Original response object should not be in the output
        expect(decoded.containsKey('response'), isFalse);
      });

      test('combines Request and Response into single httpRequest', () {
        final request = _MockShelfRequest(
          method: 'POST',
          requestedUri: Uri.parse('https://api.example.com/users'),
          protocolVersion: '1.1',
          contentLength: 256,
          headers: {'user-agent': 'TestClient/1.0'},
        );
        final response = _MockShelfResponse(
          statusCode: 201,
          contentLength: 512,
        );

        final record = testRecord(
          message: 'Request completed',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'request': request,
            'response': response,
            'durationMs': 45,
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        final httpRequest = decoded['httpRequest'] as Map<String, dynamic>;

        // From request
        expect(httpRequest['requestMethod'], 'POST');
        expect(httpRequest['requestUrl'], 'https://api.example.com/users');
        expect(httpRequest['protocol'], 'HTTP/1.1');
        expect(httpRequest['requestSize'], '256');
        expect(httpRequest['userAgent'], 'TestClient/1.0');
        // From response
        expect(httpRequest['status'], 201);
        expect(httpRequest['responseSize'], '512');
        // From durationMs
        expect(httpRequest['latency'], '0.045s');
        // Original objects should not be in the output
        expect(decoded.containsKey('request'), isFalse);
        expect(decoded.containsKey('response'), isFalse);
      });

      test('includes latency from durationMs', () {
        final response = _MockShelfResponse(statusCode: 200);

        final record = testRecord(
          message: 'Request completed',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'response': response,
            'durationMs': 1500,
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;
        final httpRequest = decoded['httpRequest'] as Map<String, dynamic>;

        expect(httpRequest['latency'], '1.5s');
      });

      test('does not create httpRequest for non-shelf objects', () {
        final record = testRecord(
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'request': 'just a string',
            'response': 42,
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(decoded.containsKey('httpRequest'), isFalse);
        expect(decoded['request'], 'just a string');
        expect(decoded['response'], 42);
      });

      test('preserves other data fields alongside httpRequest', () {
        final request = _MockShelfRequest(
          method: 'GET',
          requestedUri: Uri.parse('https://example.com/api'),
          headers: {},
        );

        final record = testRecord(
          message: 'Request',
          timestamp: DateTime.utc(2024, 1, 15),
          wallClock: DateTime.utc(2024, 1, 15),
          data: {
            'request': request,
            'requestId': 'abc123',
            'userId': 'user-456',
          },
        );

        final formatter = GcpMessageFormatter();
        final buffer = createBuffer();
        formatter.format(record, MessageBuffer(buffer));

        final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

        expect(decoded.containsKey('httpRequest'), isTrue);
        expect(decoded['requestId'], 'abc123');
        expect(decoded['userId'], 'user-456');
        expect(decoded.containsKey('request'), isFalse);
      });
    });
  });
}

class _TestClass {}

/// A class that does not have a toJson method and cannot be serialized.
class _NonSerializableObject {
  final String value;

  _NonSerializableObject(this.value);

  @override
  String toString() => 'NonSerializableObject($value)';
}

/// Mock shelf Request for testing duck typing detection.
class _MockShelfRequest {
  final String method;
  final Uri requestedUri;
  final String? protocolVersion;
  final int? contentLength;
  final Map<String, String> headers;

  _MockShelfRequest({
    required this.method,
    required this.requestedUri,
    this.protocolVersion,
    this.contentLength,
    this.headers = const {},
  });
}

/// Mock shelf Response for testing duck typing detection.
class _MockShelfResponse {
  final int statusCode;
  final int? contentLength;

  _MockShelfResponse({
    required this.statusCode,
    this.contentLength,
  });
}
