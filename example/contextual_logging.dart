// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  // Configure root logger with GCP formatter for production-like output
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-project',
          logName: 'api-logs',
        ),
      ),
    ],
  );

  print('=== Example 1: Per-Request Logger (Immutable Pattern) ===');
  immutablePerRequestLogger();

  print('\n=== Example 2: Mutable Logger (Add Data As You Go) ===');
  mutableLogger();

  print('\n=== Example 3: Real-World HTTP Request Handler ===');
  handleHttpRequest('POST', '/api/orders', 'user_789');

  print('\n=== Example 4: Nested Context (Transaction Scopes) ===');
  nestedContext();
}

/// Example 1: Create a new logger per request with all known context
void immutablePerRequestLogger() {
  // Create a child logger with all request context
  final requestLogger = Chirp.root.child(context: {
    'requestId': 'REQ-001',
    'userId': 'user_123',
    'sessionId': 'sess_456',
  });

  requestLogger.info('Request received');
  requestLogger.info('Validating request');
  requestLogger.info('Request processed successfully');

  // Each log automatically includes requestId, userId, sessionId
}

/// Example 2: Start with minimal context and add more as it becomes available
void mutableLogger() {
  // Start with just requestId
  final logger = Chirp.root.child(
    name: 'API',
    context: {'requestId': 'REQ-002'},
  );

  logger.info('Request received');

  // User authenticates - add userId
  final userId = authenticateUser();
  logger.context['userId'] = userId;
  logger.info('User authenticated');

  // Load user profile - add more context
  final userEmail = loadUserProfile(userId);
  logger.context['email'] = userEmail;
  logger.info('User profile loaded');

  // Can also add multiple fields at once
  logger.context.addAll({
    'endpoint': '/api/profile',
    'method': 'GET',
  });
  logger.info('Processing request');
}

/// Example 3: Real-world HTTP request handler
void handleHttpRequest(String method, String path, String userId) {
  final requestId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

  // Create child logger with initial request context
  final logger = Chirp.root.child(context: {
    'requestId': requestId,
    'method': method,
    'path': path,
  });

  logger.info('Incoming request');

  try {
    // Authenticate
    logger.context['userId'] = userId;
    logger.info('User authenticated');

    // Process the request
    if (path == '/api/orders' && method == 'POST') {
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      logger.context['orderId'] = orderId;

      logger.info('Creating order', data: {'items': 3, 'total': 299.99});

      // Simulate order processing
      logger.info('Validating inventory');
      logger.info('Processing payment');
      logger.info('Order created successfully', data: {'status': 'confirmed'});
    }

    logger.info('Request completed', data: {'statusCode': 201});
  } catch (e, stackTrace) {
    logger.error(
      'Request failed',
      error: e,
      stackTrace: stackTrace,
      data: {'statusCode': 500},
    );
  }
}

/// Example 4: Nested context - transaction within a request
void nestedContext() {
  // Request-level logger
  final requestLogger = Chirp.root.child(context: {
    'requestId': 'REQ-003',
    'userId': 'user_999',
  });

  requestLogger.info('Processing batch operation');

  // Create transaction-level loggers from request logger (nested children)
  for (var i = 1; i <= 3; i++) {
    final txLogger = requestLogger.child(context: {
      'transactionId': 'TX-00$i',
      'batchIndex': i,
    });

    txLogger.info('Starting transaction');
    txLogger.info('Transaction processing');
    txLogger.info('Transaction completed');
  }

  requestLogger.info('Batch operation completed');
}

// Helper functions to simulate app logic
String authenticateUser() {
  return 'user_123';
}

String loadUserProfile(String userId) {
  return '$userId@example.com';
}
