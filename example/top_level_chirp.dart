// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  print('=== Example 1: Simple static Chirp ===');
  Chirp.log('Application started');
  Chirp.log('Processing data...');
  Chirp.error('Something went wrong');

  print('\n=== Example 2: With structured data ===');
  Chirp.info(
    'User logged in',
    data: {
      'userId': 123,
      'email': 'user@example.com',
      'loginMethod': 'oauth',
    },
  );

  print('\n=== Example 3: Different log levels ===');
  Chirp.debug('Debug information');
  Chirp.info('Info message');
  Chirp.warning('Warning message');
  Chirp.error('Error message');

  print('\n=== Example 4: With error and stack trace ===');
  try {
    throw Exception('Something failed');
  } catch (e, stackTrace) {
    Chirp.error('Caught an error', error: e, stackTrace: stackTrace);
  }

  print('\n=== Example 5: From a class method (instance tracking) ===');
  final service = UserService();
  service.processUser('user_123');

  print('\n=== Example 6: With JSON formatter ===');
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
      ),
    ],
  );
  Chirp.info('JSON formatted log', data: {'key': 'value'});

  // Reset
  Chirp.root = ChirpLogger();

  print('\n=== Example 7: With GCP formatter ===');
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-project',
          logName: 'app-logs',
        ),
      ),
    ],
  );
  Chirp.info(
    'GCP formatted log',
    data: {
      'userId': 456,
      'action': 'purchase',
      'amount': 99.99,
    },
  );

  // Reset
  Chirp.root = ChirpLogger();
}

class UserService {
  void processUser(String userId) {
    chirp.info('Processing user', data: {'userId': userId});

    // Simulate some work
    chirp.debug('Fetching user data');
    chirp.debug('Validating user data');

    chirp.info('User processed successfully', data: {'userId': userId});
  }
}
