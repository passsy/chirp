// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  // Example 1: Basic usage - call .log() on a Chirp instance
  print('=== Example 1: Basic Chirp.log() ===');
  final logger = Chirp(name: 'MyApp');
  logger.log('Application started');
  logger.log('Processing data...');
  logger.log('Error occurred', error: Exception('Something went wrong'));

  // Example 2: Extension usage - log from any object
  print('\n=== Example 2: Extension (.chirp) ===');
  final service = UserService();
  service.fetchUser('user123');

  // Example 3: Error logging with stack trace
  print('\n=== Example 3: Error Logging ===');
  service.simulateError();

  // Example 4: Named loggers for different subsystems
  print('\n=== Example 4: Named Loggers ===');
  final httpLogger = Chirp(name: 'HTTP');
  final dbLogger = Chirp(name: 'Database');
  httpLogger.log('GET /api/users');
  dbLogger.log('Query executed');

  // Example 5: Instance tracking with extensions
  print('\n=== Example 5: Instance Tracking ===');
  final service1 = UserService();
  final service2 = UserService();
  service1.chirp('Service 1 working');
  service2.chirp('Service 2 working'); // Different instance hash!

  // Example 6: Custom formatter (Compact)
  print('\n=== Example 6: Custom Formatter (Compact) ===');
  Chirp.root = Chirp(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: CompactChirpMessageFormatter(),
      ),
    ],
  );
  final compactService = UserService();
  compactService.chirp('Compact format message');

  // Example 7: JSON formatter
  print('\n=== Example 7: JSON Formatter ===');
  Chirp.root = Chirp(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
      ),
    ],
  );
  final jsonService = UserService();
  jsonService.chirp('JSON format message');

  // Example 8: Multiple writers - different formats per destination
  print('\n=== Example 8: Multiple Writers ===');
  Chirp.root = Chirp(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: DefaultChirpMessageFormatter(),
      ),
      ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
        output: (msg) => print('[JSON] $msg'),
      ),
    ],
  );
  final multiService = UserService();
  multiService.chirp('Logged with both formatters!');

  // Reset to default
  Chirp.root = Chirp();
}

class UserService {
  void fetchUser(String userId) {
    chirp('Fetching user: $userId');
    // Simulate work
    chirp('User fetched successfully');
  }

  void processData() {
    chirp('Processing data...');
    // Simulate work
    chirp('Data processed');
  }

  void simulateError() {
    try {
      throw Exception('Something went wrong');
    } catch (e, stackTrace) {
      chirpError('Error in UserService', e, stackTrace);
    }
  }
}
