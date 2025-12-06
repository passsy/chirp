/// Example: Child loggers with inherited context.
///
/// Run with: dart run bin/child_loggers.dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger().addConsoleWriter();

  // Create a request-scoped logger with context
  final requestLogger = Chirp.root.child(context: {
    'requestId': 'REQ-123',
    'userId': 'user_456',
  });

  requestLogger.info('Request received');
  requestLogger.info('Authenticating user');

  // Nest children for deeper context (e.g., transaction scope)
  final txLogger = requestLogger.child(context: {
    'transactionId': 'TXN-789',
  });

  // Logs include requestId, userId, AND transactionId
  txLogger.info('Transaction started');
  txLogger.info('Transaction committed');

  requestLogger.info('Request completed');
}

// Output:
// 14:32:05.123 [info] Request received (requestId: "REQ-123", userId: "user_456")
// 14:32:05.124 [info] Authenticating user (requestId: "REQ-123", userId: "user_456")
// 14:32:05.125 [info] Transaction started (requestId: "REQ-123", userId: "user_456", transactionId: "TXN-789")
// 14:32:05.126 [info] Transaction committed (requestId: "REQ-123", userId: "user_456", transactionId: "TXN-789")
// 14:32:05.127 [info] Request completed (requestId: "REQ-123", userId: "user_456")
