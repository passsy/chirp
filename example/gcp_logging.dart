// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  print('=== Example 1: Basic Structured Logging ===');
  basicStructuredLogging();

  print('\n=== Example 2: Log Levels ===');
  logLevels();

  print('\n=== Example 3: GCP Formatter ===');
  gcpFormatter();

  print('\n=== Example 4: Real-world GCP Usage ===');
  realWorldGcpUsage();
}

/// Example 1: Basic structured logging with data fields
void basicStructuredLogging() {
  final logger = ChirpLogger(name: 'API');

  // Log with structured data
  logger.info(
    'User logged in',
    data: {
      'userId': 'user_123',
      'email': 'user@example.com',
      'loginMethod': 'oauth',
    },
  );

  // Log error with structured data
  logger.error(
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

/// Example 2: Using different log levels
void logLevels() {
  final logger = ChirpLogger(name: 'Service');

  logger.debug('Entering function', data: {'function': 'processOrder'});
  logger.info('Order received', data: {'orderId': 'ORD-123'});
  logger.warning('Inventory low', data: {'productId': 'PROD-456', 'stock': 5});
  logger
      .error('Order failed', data: {'orderId': 'ORD-123', 'reason': 'timeout'});
  logger.critical('Database connection lost', data: {'attempt': 3});
}

/// Example 3: GCP-compatible formatter
void gcpFormatter() {
  // Configure Chirp to use GCP formatter
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-project-id',
          logName: 'application-logs',
        ),
      ),
    ],
  );

  final service = PaymentService();
  service.processPayment('user_789', 149.99);
}

/// Example 4: Real-world GCP usage scenario
void realWorldGcpUsage() {
  // In production, you'd configure this once at app startup
  Chirp.root = ChirpLogger(
    writers: [
      // Console output for local development with colored formatting
      ConsoleChirpMessageWriter(
        formatter: CompactChirpMessageFormatter(),
      ),
      // GCP JSON output that gets picked up by Cloud Logging
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-gcp-project',
          logName: 'app-logs',
        ),
        output: (msg) {
          // In production, this would write to stdout where GCP picks it up
          print('[GCP] $msg');
        },
      ),
    ],
  );

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
