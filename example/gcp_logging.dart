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
  Chirp.error('Order failed', data: {'orderId': 'ORD-123', 'reason': 'timeout'});
  Chirp.critical('Database connection lost', data: {'attempt': 3});
  Chirp.wtf('Impossible state detected', data: {'state': 'invalid'});
}

/// Example 3: Using named loggers with the root GCP formatter
void namedLoggers() {
  // Create a named logger that uses the root logger's configuration
  final paymentLogger = ChirpLogger(
    name: 'PaymentService',
    writers: Chirp.root.writers,
  );

  paymentLogger.info(
    'Processing payment',
    data: {
      'userId': 'user_789',
      'amount': 149.99,
      'currency': 'USD',
    },
  );

  paymentLogger.warning(
    'Large payment requires approval',
    data: {
      'userId': 'user_789',
      'amount': 149.99,
      'threshold': 100,
    },
  );
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

// Example service using extension methods
class PaymentService {
  void processPayment(String userId, double amount) {
    chirp.info(
      'Processing payment',
      data: {
        'userId': userId,
        'amount': amount,
        'currency': 'USD',
      },
    );

    // Simulate validation
    if (amount > 1000) {
      chirp.warning(
        'Large payment requires approval',
        data: {
          'userId': userId,
          'amount': amount,
          'threshold': 1000,
        },
      );
    }

    // Simulate processing
    try {
      // Payment logic here...
      chirp.info(
        'Payment processed successfully',
        data: {
          'userId': userId,
          'amount': amount,
          'transactionId': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        },
      );
    } catch (e, stackTrace) {
      chirp.error(
        'Payment processing failed',
        error: e,
        stackTrace: stackTrace,
        data: {
          'userId': userId,
          'amount': amount,
        },
      );
    }
  }
}

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
