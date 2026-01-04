/// Example: Shelf server with GCP structured logging.
///
/// This example demonstrates how to use GcpMessageFormatter with a Shelf
/// HTTP server for Cloud Run, Cloud Functions, or GKE deployments.
///
/// Run with: dart run bin/gcp_shelf_server.dart
///
/// In GCP, the JSON output is automatically parsed by Cloud Logging
/// and displayed with proper severity, labels, and source location.
import 'dart:async';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Zone key for request-scoped logging context.
const Symbol _requestLoggerKey = #requestLogger;

void main() async {
  // Configure Chirp for GCP structured logging
  // Chirp.root = ChirpLogger()
  // for development
  // .addConsoleWriter(
  // formatter: RainbowMessageFormatter(
  //   options: RainbowFormatOptions(showMethod: false, showLocation: false),
  // ),
  // )
  // for production
  // .addConsoleWriter(
  //   formatter: GcpMessageFormatter(
  //     serviceName: 'my-api-service',
  //     serviceVersion: '1.0.0',
  //   ),
  // );

  final router = Router()
    ..get('/api/users/<userId>', _getUser)
    ..get('/api/users/<userId>', _getUser)
    ..get('/api/health', _healthCheck)
    ..all('/<ignored|.*>', _notFound);

  // Build the pipeline with logging middleware
  final handler = const Pipeline()
      .addMiddleware(_requestLoggingMiddleware(logRequestStart: true))
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
  final port = server.port;
  Chirp.info('Server started', data: {
    'host': server.address.host,
    'port': port,
  });

  // Demo: Hit all endpoints to show logging output
  await _runDemoRequests(port);

  // Shutdown after demo
  await server.close();
  Chirp.info('Server stopped');
}

/// Runs demo requests against all endpoints.
Future<void> _runDemoRequests(int port) async {
  final client = HttpClient();
  final baseUrl = 'http://localhost:$port';

  Future<void> get(String path) async {
    final request = await client.getUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  Future<void> post(String path) async {
    final request = await client.postUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  Future<void> put(String path) async {
    final request = await client.putUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  Future<void> delete(String path) async {
    final request = await client.deleteUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  // ignore: unused_element
  Future<void> patch(String path) async {
    final request = await client.patchUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  Future<void> head(String path) async {
    final request = await client.headUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  Future<void> options(String path) async {
    final request = await client.openUrl('OPTIONS', Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  // Health check
  await get('/api/health');

  // Get user (success)
  await get('/api/users/123');

  // Get user (not found)
  await post('/api/users/404');
  await put('/api/users/404');
  await head('/api/users/404');
  await delete('/api/users/404');
  await options('/api/users/404');

  // Get use (illegal id)
  await get('/api/users/-1');

  // Unknown route
  await get('/unknown/route');

  client.close();
}

class RequestFormatter extends SpanBasedFormatter {
  @override
  LogSpan buildSpan(LogRecord record) {
    final request = record.data['request'] as Request?;
    final requestId = record.data['requestId'] as String?;
    final requestColor =
        colorForHash(requestId, saturation: ColorSaturation.low);

    final response = record.data['response'] as Response?;
    final durationMs = record.data['durationMs'] as int?;

    if (record.message == 'request start' ||
        record.message == 'request finish' ||
        record.message == 'request error') {
      final spans = <LogSpan>[];

      spans.add(
        AnsiStyled(
          child: Timestamp(record.timestamp),
          foreground: Ansi256.grey50_244,
        ),
      );

      if (requestId != null) {
        spans.add(Whitespace());
        if (response == null && record.error == null) {
          spans.add(
            AnsiStyled(
              child: PlainText('┌ '),
              foreground: Ansi256.grey50_244,
            ),
          );
        } else {
          spans.add(
            AnsiStyled(
              child: PlainText('└ '),
              foreground: Ansi256.grey50_244,
            ),
          );
        }
        spans.add(
          AnsiStyled(
            child: PlainText(requestId),
            foreground: requestColor,
          ),
        );
      }

      final responseColor = () {
        if (response == null) return DefaultColor();
        if (response.statusCode >= 500) return Ansi256.indianRed_167;
        if (response.statusCode >= 400) return Ansi256.darkGoldenrod_136;
        if (response.statusCode >= 300) return DefaultColor();
        return Ansi256.grey50_244;
      }();

      final bool alreadyLoggedRequestStart =
          record.formatOptions?.any((it) => it is _AlreadyLoggedRequestStart) ??
              false;

      if (request != null && !alreadyLoggedRequestStart) {
        spans.add(Whitespace());
        spans.add(AnsiStyled(
          child: PlainText(''.padRight(8 - request.method.length, '─')),
          foreground: Ansi256.grey50_244,
        ));
        spans.add(Whitespace());
        spans.add(PlainText(request.method));
        spans.add(Whitespace());
        spans.add(
          AnsiStyled(
            child: PlainText(request.requestedUri.path),
            foreground: requestColor,
          ),
        );
      }
      if (response != null) {
        if (alreadyLoggedRequestStart) {
          spans.add(Whitespace());
          spans.add(AnsiStyled(
            child: PlainText('────>'),
            foreground: Ansi256.grey50_244,
          ));
          spans.add(Whitespace());
        } else {
          spans.add(Whitespace());
          spans.add(AnsiStyled(
            child: PlainText('→'),
            foreground: Ansi256.grey50_244,
          ));
          spans.add(Whitespace());
        }

        spans.add(
          AnsiStyled(
            child: PlainText('${response.statusCode}'),
            foreground: responseColor,
          ),
        );
      }

      if (durationMs != null) {
        final color = () {
          if (durationMs >= 1000) return Ansi256.indianRed_167;
          if (durationMs >= 500) return Ansi256.darkGoldenrod_136;
          return Ansi256.grey50_244;
        }();

        spans.add(Whitespace());
        spans.add(AnsiStyled(
          child: SpanSequence(children: [
            if (durationMs >= 500) PlainText('⚠ '),
            PlainText('${durationMs}ms'),
          ]),
          foreground: color,
        ));
      }

      spans.add(Whitespace());
      final cleanData = {...record.data}
        ..remove('request')
        ..remove('response')
        ..remove('requestId')
        ..remove('durationMs');
      spans.add(
        AnsiStyled(
          child: Surrounded(
            prefix: PlainText('('),
            child: cleanData.isEmpty ? null : InlineData(cleanData),
            suffix: PlainText(')'),
          ),
          foreground: Ansi256.grey50_244,
        ),
      );

      return SpanSequence(children: spans);
    } else {
      final spans = <LogSpan>[];
      spans.add(
        AnsiStyled(
          child: Timestamp(record.timestamp),
          foreground: Ansi256.grey50_244,
        ),
      );
      spans.add(Whitespace());

      {
        final levelColor = () {
          if (record.level >= ChirpLogLevel.error) return Ansi256.indianRed_167;
          if (record.level >= ChirpLogLevel.warning)
            return Ansi256.darkGoldenrod_136;
          if (record.level >= ChirpLogLevel.success) return Ansi256.green3_34;
          return Ansi256.grey50_244;
        }();

        spans.add(
          AnsiStyled(
            child: PlainText('│'),
            foreground: Ansi256.grey50_244,
          ),
        );
        if (requestId != null) {
          spans.add(Whitespace());
          spans.add(
            AnsiStyled(
              child: PlainText(requestId),
              foreground:
                  colorForHash(requestId, saturation: ColorSaturation.low),
            ),
          );
        }
        spans.add(Whitespace());
        spans.add(
          AnsiStyled(
            child: Aligned(
              align: HorizontalAlign.right,
              child: PlainText('${record.level}'),
              width: 9,
            ),
            foreground: levelColor,
          ),
        );
        spans.add(Whitespace());
      }

      spans.add(PlainText(record.message?.toString() ?? 'null'));

      if (record.error != null) {
        spans.add(NewLine());
        spans.add(
          AnsiStyled(
            child: ErrorSpan(record.error),
            foreground: Ansi256.indianRed_167,
          ),
        );
      }
      if (record.stackTrace != null) {
        spans.add(NewLine());
        spans.add(
          AnsiStyled(
            child: StackTraceSpan(record.stackTrace!),
            foreground: Ansi256.indianRed_167,
          ),
        );
      }

      if (record.data.isNotEmpty) {
        final cleanData = {...record.data}
          ..remove('request')
          ..remove('response')
          ..remove('requestId')
          ..remove('durationMs');
        if (cleanData.isNotEmpty) {
          spans.add(Whitespace());
          spans.add(
            AnsiStyled(
              child: Surrounded(
                prefix: PlainText('('),
                child: InlineData(cleanData),
                suffix: PlainText(')'),
              ),
              foreground: Ansi256.grey50_244,
            ),
          );
        }
      }

      return SpanSequence(children: spans);
    }
  }
}

/// Middleware that creates a request-scoped logger and logs request/response.
Middleware _requestLoggingMiddleware({bool logRequestStart = false}) {
  final logger = ChirpLogger();
  logger.addConsoleWriter(formatter: RequestFormatter());
  // logger.addConsoleWriter(formatter: GcpMessageFormatter());

  return (Handler innerHandler) {
    return (Request request) async {
      final requestId = _generateRequestId();
      final stopwatch = Stopwatch()..start();

      // Create a child logger with request context

      final requestLogger = logger.child(
        context: {
          'requestId': requestId,
          'request': request,
        },
      );

      if (logRequestStart) {
        requestLogger.info('request start');
      }
      try {
        // Run the handler in a zone with the request logger
        final response = await runZoned(
          () => innerHandler(request),
          zoneValues: {_requestLoggerKey: requestLogger},
        );

        stopwatch.stop();

        requestLogger.info('request finish', data: {
          'response': response,
          'durationMs': stopwatch.elapsedMilliseconds,
        }, formatOptions: [
          if (logRequestStart) _AlreadyLoggedRequestStart(),
        ]);

        return response;
      } catch (e, stackTrace) {
        stopwatch.stop();

        requestLogger.error('Request fail with exception',
            error: e, stackTrace: stackTrace);
        requestLogger.error(
          'request error',
          error: e,
          stackTrace: stackTrace,
          data: {'durationMs': stopwatch.elapsedMilliseconds},
        );

        return Response.internalServerError(
          body: 'Internal Server Error',
        );
      }
    };
  };
}

class _AlreadyLoggedRequestStart extends FormatOptions {}

/// Gets the request-scoped logger from the current zone.
ChirpLogger get requestLogger {
  final logger = Zone.current[_requestLoggerKey];
  if (logger is ChirpLogger) return logger;
  return Chirp.root; // Fallback to root logger
}

/// Example handler: Get user by ID.
Future<Response> _getUser(Request request, String userId) async {
  requestLogger.debug('Fetching user', data: {'userId': userId});

  // Simulate user lookup
  if (userId == '404') {
    requestLogger.warning('User not found', data: {'userId': userId});
    return Response.notFound('User not found');
  }

  if ((int.tryParse(userId) ?? 0) < 0) {
    throw ArgumentError('Invalid user ID: $userId');
  }

  await Future.delayed(const Duration(milliseconds: 1001));

  requestLogger.info('User found', data: {'userId': userId});
  return Response.ok('{"id": "$userId", "name": "John Doe"}',
      headers: {'Content-Type': 'application/json'});
}

/// Health check endpoint.
Response _healthCheck(Request request) {
  requestLogger.debug('generating the health check response');
  return Response.ok('OK');
}

/// 404 handler.
Response _notFound(Request request) {
  requestLogger.warning('Route not found');
  return Response.notFound('Not Found');
}

/// Generates a simple request ID.
String _generateRequestId() {
  final timeString = Object().hashCode.toRadixString(36);
  final len = timeString.length;
  if (len <= 5) {
    return timeString.padLeft(5, '0');
  }
  return timeString.substring(len - 5, len);
}

// Example GCP Cloud Logging output (formatted for readability):
//
// {
//   "severity": "INFO",
//   "message": "Request started",
//   "timestamp": "2024-01-15T10:30:45.123Z",
//   "logging.googleapis.com/sourceLocation": {
//     "file": "package:simple_example/gcp_shelf_server.dart",
//     "line": "58",
//     "function": "_requestLoggingMiddleware.<anonymous closure>"
//   },
//   "logging.googleapis.com/labels": {
//     "logger": "ChirpLogger"
//   },
//   "requestId": "m5k9x2",
//   "method": "GET",
//   "path": "api/users/123"
// }
//
// {
//   "severity": "INFO",
//   "message": "Request completed",
//   "timestamp": "2024-01-15T10:30:45.145Z",
//   "logging.googleapis.com/sourceLocation": {...},
//   "logging.googleapis.com/labels": {...},
//   "requestId": "m5k9x2",
//   "method": "GET",
//   "path": "api/users/123",
//   "statusCode": 200,
//   "durationMs": 22
// }
