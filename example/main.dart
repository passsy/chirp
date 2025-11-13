// ignore_for_file: avoid_print, avoid_redundant_argument_values

import 'package:chirp/chirp.dart';

void main() {
  Chirp.warning('=== Example 0: Basic Instance Logging ===');
  basicInstanceLoggingExample();

  Chirp.warning('=== Example 1: Static Methods - All Log Levels ===');
  allLogLevelsExample();

  Chirp.warning('=== Example 2: Named Logger & Structured Data ===');
  namedLoggerExample();

  Chirp.warning('=== Example 3: Child Loggers (Per-Request Context) ===');
  childLoggerExample();

  Chirp.warning('=== Example 4: Instance Tracking with .chirp Extension ===');
  instanceTrackingExample();

  Chirp.warning('=== Example 5: GCP Cloud Logging Format ===');
  gcpFormatterExample();

  Chirp.warning('=== Example 6: Multiple Writers (Console + JSON) ===');
  multipleWritersExample();

  Chirp.warning('=== Example 7: Format Options (Inline vs Multiline Data) ===');
  formatOptionsExample();

  Chirp.warning('=== Example 8: Multiline Messages ===');
  multilineMessagesExample();

  Chirp.warning('=== Example 9: Stacktraces with Different Log Levels ===');
  stacktraceLevelsExample();

  // Reset to default
  Chirp.root = ChirpLogger();

  final bleLogger =
      Chirp.root.child(name: 'BLE', context: {'bluetooth_state': 'on'});
  bleLogger.info('Device connected');
}

/// Basic example showing instance method logging
void basicInstanceLoggingExample() {
  final userService = UserService();
  userService.processUser('robin');
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

/// Demonstrates different format options for RainbowMessageFormatter
void formatOptionsExample() {
  // Multiline data display (default)
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: RainbowMessageFormatter(
          options: const RainbowFormatOptions(data: DataPresentation.multiline),
        ),
      ),
    ],
  );

  Chirp.info('User logged in', data: {
    'userId': 'user_123',
    'email': 'user@example.com',
    'loginMethod': 'oauth',
  });

  // Force inline
  Chirp.info(
    'User logged in',
    data: {
      'userId': 'user_123',
      'email': 'user@example.com',
      'loginMethod': 'oauth',
    },
    formatOptions: [const RainbowFormatOptions(data: DataPresentation.inline)],
  );

  // Reset
  Chirp.root = ChirpLogger();
}

/// Demonstrates logging messages with newlines
void multilineMessagesExample() {
  // Single line message
  Chirp.info('Single line message');

  // Multiline message with \n
  Chirp.info('Line 1\nLine 2\nLine 3');

  // Multiline message with data (inline by default)
  Chirp.info(
    'Deployment summary:\n- Service: api-gateway\n- Version: 1.2.3\n- Status: deployed',
    data: {'duration': '2.5s', 'status': 'ok'},
  );

  Chirp.info(
    'Deployment summary:\n- Service: api-gateway\n- Version: 1.2.3\n- Status: deployed',
    data: {'duration': '2.5s', 'status': 'ok'},
    formatOptions: [
      const RainbowFormatOptions(data: DataPresentation.multiline),
    ],
  );

  // Force zero indentation
  Chirp.info(
    'User logged in',
    data: {
      'userId': 'user_123',
      'email': 'user@example.com',
      'loginMethod': 'oauth',
    },
    formatOptions: [const RainbowFormatOptions(layout: LayoutStyle.plain)],
  );

  // Reset
  Chirp.root = ChirpLogger();
}

/// Demonstrates how stacktraces are colored differently based on log level
void stacktraceLevelsExample() {
  // Info level with stacktrace - stacktrace appears in grey
  Chirp.info(
    'Debug checkpoint reached',
    stackTrace: StackTrace.current,
  );

  // Warning level with stacktrace - stacktrace appears in warning color
  Chirp.warning(
    'Deprecated method called',
    stackTrace: StackTrace.current,
    data: {'method': 'oldApiCall'},
  );

  // Error level with error and stacktrace - both appear in error color
  Chirp.error(
    'Failed to process request',
    error: Exception('Connection timeout'),
    stackTrace: StackTrace.current,
    data: {'retries': 3},
  );

  // Debug level with stacktrace - stacktrace appears in grey
  Chirp.debug(
    'Entering critical section',
    stackTrace: StackTrace.current,
    data: {'threadId': 42},
  );
}

class UserService {
  void processUser(String userId) {
    chirp.info('Processing user', data: {'userId': userId});
    chirp.info('Processing user', data: {'userId': userId});
    Chirp.info('Processing user', data: {'userId': userId});
  }

  static void logStatic() {
    Chirp.info('From static method');
  }
}
