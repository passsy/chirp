// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  // Configure root logger with GCP formatter once
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-project',
          logName: 'application-logs',
        ),
      ),
    ],
  );

  print('=== Example 1: Basic Structured Logging ===');
  basicStructuredLogging();

  print('\n=== Example 2: Log Levels ===');
  logLevels();

  print('\n=== Example 3: Named Loggers ===');
  namedLoggers();

  print('\n=== Example 4: Real-world GCP Usage ===');
  realWorldGcpUsage();
}

/// Example 1: Basic structured logging with data fields using static methods
void basicStructuredLogging() {
  // Use Chirp static methods which use the configured root logger
  Chirp.info(
    'User logged in',
    data: {
      'userId': 'user_123',
      'email': 'user@example.com',
      'loginMethod': 'oauth',
    },
  );

  // Log error with structured data
  Chirp.error(
    'Failed to process payment',
    error: Exception('Insufficient funds'),
    data: {
      'userId': 'user_456',
      'amount': 99.99,
      'currency': 'USD',
      'paymentMethod': 'credit_card',
    },
  );
}

/// Example 2: Using all log levels via static methods
void logLevels() {
  Chirp.trace('Detailed execution trace', data: {'step': 1});
  Chirp.debug('Entering function', data: {'function': 'processOrder'});
  Chirp.info('Order received', data: {'orderId': 'ORD-123'});
  Chirp.warning('Inventory low', data: {'productId': 'PROD-456', 'stock': 5});
  Chirp.error('Order failed',
      data: {'orderId': 'ORD-123', 'reason': 'timeout'});
  Chirp.critical('Database connection lost', data: {'attempt': 3});
  Chirp.wtf('Impossible state detected', data: {'state': 'invalid'});
}

/// Example 3: Child loggers (winston-style)
void namedLoggers() {
  // Create a child logger with context that inherits root's writers
  final requestLogger = Chirp.root.child(context: {'requestId': 'REQ-789'});

  requestLogger.info(
    'Request started',
    data: {
      'method': 'POST',
      'path': '/payments',
    },
  );

  // Create a child with both name and context
  final paymentLogger = requestLogger.child(
    name: 'PaymentService',
    context: {
      'userId': 'user_789',
      'amount': 149.99,
    },
  );

  paymentLogger.info('Processing payment');

  paymentLogger.warning(
    'Large payment requires approval',
    data: {'threshold': 100},
  );

  // Context is merged: requestId from parent + userId/amount from child + threshold from log call
}

/// Example 4: Real-world GCP usage scenario
void realWorldGcpUsage() {
  // The root logger is already configured with GCP formatter in main()
  // In a real application, you might have multiple writers:
  // - One for local development (colored console output)
  // - One for GCP Cloud Logging (JSON format)
  // Here we're just demonstrating that the classes use the root logger

  final api = ApiHandler();
  api.handleRequest();
}

// Example classes using extension methods
class ApiHandler {
  void handleRequest() {
    chirp.info(
      'Incoming HTTP request',
      data: {
        'method': 'POST',
        'path': '/api/users',
        'ip': '192.168.1.100',
        'userAgent': 'Mozilla/5.0',
      },
    );

    // Simulate request processing
    final requestId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

    chirp.debug(
      'Validating request',
      data: {
        'requestId': requestId,
        'validations': ['auth', 'schema', 'rate_limit'],
      },
    );

    chirp.info(
      'Request completed',
      data: {
        'requestId': requestId,
        'statusCode': 201,
        'durationMs': 42,
      },
    );
  }
}
