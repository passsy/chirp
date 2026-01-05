/// Example: Shelf server with GCP structured logging.
///
/// This example demonstrates how to use GcpMessageFormatter with a Shelf
/// HTTP server for Cloud Run, Cloud Functions, or GKE deployments.
///
/// Run with: dart run bin/shelf_server.dart
///
/// In GCP, the JSON output is automatically parsed by Cloud Logging
/// and displayed with proper severity, labels, and source location.
import 'dart:async';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'chirp_shelf_request_middleware.dart';

void main() async {
  final isProduction = bool.hasEnvironment('PORT');

  if (isProduction) {
    // production
    Chirp.root = ChirpLogger().addConsoleWriter(
      formatter: JsonMessageFormatter(),
    );

    assert(() {
      // for Google Cloud Run structured logging
      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: GcpMessageFormatter(
          serviceName: 'my-api-service',
          serviceVersion: '1.0.0',
        ),
      );

      // for AWS CloudWatch
      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: AwsMessageFormatter(),
      );
      return true;
    }());
  } else {
    // development
    Chirp.root = ChirpLogger().addConsoleWriter(
      formatter: RainbowMessageFormatter(
        options: RainbowFormatOptions(showMethod: false, showLocation: false),
      ),
    );
  }

  final router = Router()
    ..get('/api/users/<userId>', _getUser)
    ..get('/api/users/<userId>', _getUser)
    ..get('/api/health', _healthCheck)
    ..all('/<ignored|.*>', _notFound);

  final handler = const Pipeline()
      .addMiddleware(requestLoggingMiddleware(
          logRequestStart: !isProduction,
          logRequestEnd: !isProduction,
          logger: isProduction ? Chirp.root : null))
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
  final client = DemoClient(port: port);

  // Health check
  await client.get('/api/health');

  // Get user (success)
  await client.get('/api/users/123');

  // Get user (not found)
  await client.post('/api/users/404');
  await client.put('/api/users/404');
  await client.head('/api/users/404');
  await client.delete('/api/users/404');
  await client.options('/api/users/404');

  // Get use (illegal id)
  await client.get('/api/users/-1');

  // Unknown route
  await client.get('/unknown/route');

  // Parallel requests (demonstrates interleaved logging)
  await Future.wait([
    client.get('/api/users/111'),
    client.get('/api/users/222'),
  ]);

  client.close();
}

/// Example handler: Get user by ID.
Future<Response> _getUser(Request request, String userId) async {
  request.logger.debug('Fetching user', data: {'userId': userId});

  // Simulate user lookup
  if (userId == '404') {
    request.logger.warning('User not found', data: {'userId': userId});
    return Response.notFound('User not found');
  }

  if ((int.tryParse(userId) ?? 0) < 0) {
    throw ArgumentError('Invalid user ID: $userId');
  }

  request.logger.debug('Simulating db delay');
  await Future.delayed(const Duration(milliseconds: 1001));

  request.logger.info('User found', data: {'userId': userId});
  return Response.ok('{"id": "$userId", "name": "John Doe"}',
      headers: {'Content-Type': 'application/json'});
}

/// Health check endpoint.
Response _healthCheck(Request request) {
  return Response.ok('OK');
}

/// 404 handler.
Response _notFound(Request request) {
  request.logger.warning('Route not found');
  Chirp.warning('Route not found, reported via root logger');
  return Response.notFound('Not Found');
}

// Example GCP Cloud Logging output (formatted for readability):
//
// {
//   "severity": "INFO",
//   "message": "Request started",
//   "timestamp": "2024-01-15T10:30:45.123Z",
//   "logging.googleapis.com/sourceLocation": {
//     "file": "package:simple_example/shelf_server.dart",
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

class DemoClient {
  DemoClient({
    required this.port,
  });

  final int port;
  final client = HttpClient();
  late final baseUrl = 'http://localhost:$port';

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
    chirp.log('Sending a pre-flight request to $path');
    final request = await client.openUrl('OPTIONS', Uri.parse('$baseUrl$path'));
    final response = await request.close();
    await response.drain<void>();
  }

  void close() {
    client.close();
  }
}
