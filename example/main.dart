// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  UserService().processUser('robin');

  print('=== Example 1: Static Methods - All Log Levels ===');
  allLogLevelsExample();

  print('\n=== Example 2: Named Logger & Structured Data ===');
  namedLoggerExample();

  print('\n=== Example 3: Child Loggers (Per-Request Context) ===');
  childLoggerExample();

  print('\n=== Example 4: Instance Tracking with .chirp Extension ===');
  instanceTrackingExample();

  print('\n=== Example 5: GCP Cloud Logging Format ===');
  gcpFormatterExample();

  print('\n=== Example 6: Multiple Writers (Console + JSON) ===');
  multipleWritersExample();

  // Reset to default
  Chirp.root = ChirpLogger();

  final bleLogger =
      Chirp.root.child(name: 'BLE', context: {'bluetooth_state': 'on'});
  bleLogger.info('Device connected');
}

/// Demonstrates all 7 log levels
void allLogLevelsExample() {
  Chirp.trace('Detailed execution trace', data: {'step': 1});
  Chirp.debug('Debug information', data: {'cache': 'miss'});
  Chirp.info('Application started');
  Chirp.log('Application started', level: const ChirpLogLevel('robin', 600));
  Chirp.warning('Deprecated API used', data: {'api': 'v1'});
  Chirp.error('Operation failed', error: Exception('Timeout'));
  Chirp.critical('Database connection lost');
  Chirp.wtf('User age is negative', data: {'age': -5});
}

/// Named logger with structured data
void namedLoggerExample() {
  final logger = ChirpLogger(name: 'API');

  logger.info(
    'User request received',
    data: {
      'userId': 'user_123',
      'endpoint': '/api/profile',
      'method': 'GET',
    },
  );

  logger.error(
    'Request failed',
    error: Exception('Not found'),
    stackTrace: StackTrace.current,
    data: {'statusCode': 404},
  );
}

/// Child loggers inherit parent configuration
void childLoggerExample() {
  // Create request-scoped logger
  final requestLogger = Chirp.root.child(context: {
    'requestId': 'REQ-123',
    'userId': 'user_456',
  });

  requestLogger.info('Request received');
  requestLogger.info('Processing data');

  // Nest children for transaction scope
  final txLogger = requestLogger.child(context: {
    'transactionId': 'TXN-789',
    'action': 'login',
    'cool package': 'https://pub.dev/packages/spot',
    'pathToFile0':
        'file:///Users/dev/Projects/MyProject/test/fake/fake_auth_service.dart:119:7',
    'pathToFile1':
        'file:///Users/dev/Projects/MyProject/test/fake/fake_auth_service.dart:119:7',
    'pathToFile2':
        'file:///Users/dev/Projects/MyProject/test/fake/fake_auth_service.dart:119:7',
    'pathToFile3':
        'file:///Users/dev/Projects/MyProject/test/fake/fake_auth_service.dart:119:7',
  });

  // Includes requestId, userId, AND transactionId
  txLogger.info('Transaction started');
  txLogger.info('Transaction completed');
}

/// Instance tracking differentiates object instances
void instanceTrackingExample() {
  final service1 = UserService();
  final service2 = UserService();

  // Different instances = different hashes
  service1.chirp.info('From service 1');
  service2.chirp.info('From service 2');

  // Static method - shows class name without instance
  UserService.logStatic();
}

/// GCP Cloud Logging compatible JSON format
void gcpFormatterExample() {
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

  Chirp.info('GCP format log', data: {
    'userId': 'user_123',
    'action': 'login',
    'cool package': 'https://pub.dev/packages/spot',
    'pathToFile':
        'file:///Users/pascalwelsch/Projects/MyProject/test/fake/fake_auth_service.dart:119:7',
  });

  Chirp.error(
    'GCP error log',
    error: Exception('Connection failed'),
  );

  // Reset
  Chirp.root = ChirpLogger();
}

/// Multiple writers send to different destinations with different formats
void multipleWritersExample() {
  Chirp.root = ChirpLogger(
    writers: [
      // Human-readable format for console
      ConsoleChirpMessageWriter(
        formatter: CompactChirpMessageFormatter(),
        output: (msg) => print('[CONSOLE] $msg'),
      ),
      // Machine-readable JSON
      ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
        output: (msg) => print('[JSON] $msg'),
      ),
    ],
  );

  Chirp.info('Logged with both formatters!');

  // Reset
  Chirp.root = ChirpLogger();
}

class UserService {
  void processUser(String userId) {
    chirp.info('Processing user', data: {'userId': userId});
    Chirp.info('Processing user', data: {'userId': userId});
  }

  static void logStatic() {
    Chirp.info('From static method');
  }
}
