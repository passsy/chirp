// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  // Example 1: Basic usage - call .log() on a Chirp instance
  print('=== Example 1: Basic Chirp.log() ===');
  final logger = ChirpLogger(name: 'MyApp');
  logger.log('Application started');
  logger.log('Processing data...');
  logger.log('Error occurred', error: Exception('Something went wrong'));

  // Example 2: Top-level chirp usage
  print('\n=== Example 2: Top-level chirp ===');
  Chirp.log('Processing data...');
  Chirp.info('Info message');
  Chirp.warning('Something is off');
  Chirp.error('Error occurred');

  // Example 3: From a service class
  print('\n=== Example 3: Service Class ===');
  final service = UserService();
  service.fetchUser('user123');
  service.simulateError();

  // Example 4: Named loggers for different subsystems
  print('\n=== Example 4: Named Loggers ===');
  final httpLogger = ChirpLogger(name: 'HTTP');
  final dbLogger = ChirpLogger(name: 'Database');
  httpLogger.log('GET /api/users');
  dbLogger.log('Query executed');

  // Example 5: Structured logging with data
  print('\n=== Example 5: Structured Logging ===');
  final apiLogger = ChirpLogger(name: 'API');
  apiLogger.info(
    'User request received',
    data: {
      'userId': 'user_123',
      'endpoint': '/api/profile',
      'method': 'GET',
    },
  );

  // Example 6: Log levels
  print('\n=== Example 6: Log Levels ===');
  final svcLogger = ChirpLogger(name: 'Service');
  svcLogger.debug('Debug information');
  svcLogger.info('Info message');
  svcLogger.warning('Warning message');
  svcLogger.error('Error message');

  // Example 7: Custom formatter (Compact)
  print('\n=== Example 7: Custom Formatter (Compact) ===');
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: CompactChirpMessageFormatter(),
      ),
    ],
  );
  Chirp.log('Compact format message');

  // Example 8: JSON formatter
  print('\n=== Example 8: JSON Formatter ===');
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
      ),
    ],
  );
  Chirp.log('JSON format message');

  // Example 9: Multiple writers - different formats per destination
  print('\n=== Example 9: Multiple Writers ===');
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: RainbowMessageFormatter(),
      ),
      ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
        output: (msg) => print('[JSON] $msg'),
      ),
    ],
  );
  Chirp.log('Logged with both formatters!');

  // Reset to default
  Chirp.root = ChirpLogger();
}

class UserService {
  void fetchUser(String userId) {
    chirp.info('Fetching user: $userId');
    Chirp.info('Fetching user: $userId');
    // Simulate work
    chirp.debug('User fetched successfully');
  }

  void simulateError() {
    try {
      throw Exception('Something went wrong');
    } catch (e, stackTrace) {
      chirp.log('Error in UserService', error: e, stackTrace: stackTrace);
    }
  }
}
