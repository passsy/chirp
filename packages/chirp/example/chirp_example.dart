// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

/// Example demonstrating basic Chirp logging functionality.
void main() {
  // Configure the root logger with a colorful formatter
  Chirp.root = ChirpLogger()
      .addConsoleWriter(formatter: RainbowMessageFormatter());

  // Basic logging with different levels
  Chirp.info('Application started');
  Chirp.debug('Debug information for developers');
  Chirp.warning('Something might need attention');

  // Structured logging with data
  Chirp.info(
    'User logged in',
    data: {'userId': 'user_123', 'email': 'user@example.com'},
  );

  // Error logging with stack trace
  try {
    throw Exception('Something went wrong');
  } catch (e, stackTrace) {
    Chirp.error('An error occurred', error: e, stackTrace: stackTrace);
  }

  // Child loggers with context
  final requestLogger = Chirp.root.child(context: {
    'requestId': 'REQ-123',
    'endpoint': '/api/users',
  });
  requestLogger.info('Processing request');

  // Instance tracking with the chirp extension
  final service = ExampleService();
  service.doWork();
}

/// Example class demonstrating instance tracking with the chirp extension.
class ExampleService {
  void doWork() {
    // Using chirp extension tracks the instance
    chirp.info('ExampleService is doing work');
    chirp.success('Work completed successfully');
  }
}
