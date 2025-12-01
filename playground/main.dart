// ignore_for_file: avoid_print, avoid_redundant_argument_values

import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
    // ..addConsoleWriter(formatter: CompactChirpMessageFormatter())
    ..addConsoleWriter(
      formatter: RainbowMessageFormatter(
        spanTransformers: [_boxWtfMessages],
      ),
    );

  sectionLogger.warning('=== Example 0: Basic Instance Logging ===');
  basicInstanceLoggingExample();

  sectionLogger.warning('=== Example 1: Static Methods - All Log Levels ===');

  allLogLevelsExample();

  sectionLogger.warning('=== Example 2: Named Logger & Structured Data ===');
  namedLoggerExample();

  sectionLogger
      .warning('=== Example 3: Child Loggers (Per-Request Context) ===');
  childLoggerExample();

  sectionLogger
      .warning('=== Example 4: Instance Tracking with .chirp Extension ===');
  instanceTrackingExample();

  sectionLogger
      .warning('=== Example 5: Format Options (Inline vs Multiline Data) ===');
  formatOptionsExample();

  sectionLogger.warning('=== Example 6: Multiline Messages ===');
  multilineMessagesExample();

  sectionLogger
      .warning('=== Example 7: Stacktraces with Different Log Levels ===');
  stacktraceLevelsExample();

  sectionLogger.warning('=== Example 8: Multiple Writers (Console + JSON) ===');
  multipleWritersExample();

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

/// Demonstrates all 8 log levels
void allLogLevelsExample() {
  Chirp.trace('Detailed execution trace', data: {'step': 1});
  Chirp.debug('Debug information', data: {'cache': 'miss'});
  Chirp.info('Application started info');
  Chirp.notice('Device connected', data: {'id': '32168', 'name': 'DPE 2'});
  Chirp.log(
    'Application started custom level 600',
    level: const ChirpLogLevel('myAlert', 600),
  );
  Chirp.warning('Deprecated API used warning', data: {'api': 'v1'});
  Chirp.error('Operation failed error', error: Exception('Timeout'));
  Chirp.critical('Database connection lost (critical)');
  Chirp.wtf('User age is negative WTF', data: {'age': -5});
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
  final requestLogger = Chirp.root.child(
    context: {
      'requestId': 'REQ-123',
      'userId': 'user_456',
    },
  );

  requestLogger.info('Request received');
  requestLogger.info('Processing data');

  // Nest children for transaction scope
  final txLogger = requestLogger.child(
    context: {
      'transactionId': 'TXN-789',
      'action': 'login',
      'plainObject': Object(),
      'cool package': 'https://pub.dev/packages/spot',
    },
  );

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

/// Multiple writers send to different destinations with different formats
void multipleWritersExample() {
  Chirp.root = ChirpLogger()
    // Human-readable format for console
    ..addConsoleWriter(
      formatter: CompactChirpMessageFormatter(),
      output: (msg) => print('[CONSOLE] $msg'),
    )
    // Machine-readable JSON
    ..addConsoleWriter(
      formatter: JsonMessageFormatter(),
      output: (msg) => print('[JSON] $msg'),
    );

  Chirp.info('Logged with both formatters!');

  // Reset
  Chirp.root = ChirpLogger();
}

/// Demonstrates different format options for RainbowMessageFormatter
void formatOptionsExample() {
  // Multiline data display (default)
  Chirp.root = ChirpLogger()
    ..addConsoleWriter(
      formatter: RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      ),
    );

  Chirp.info(
    'User logged in',
    data: {
      'userId': 'user_123',
      'email': 'user@example.com',
      'loginMethod': 'oauth',
      'metadata': {
        'browser': 'Chrome',
        'platform': 'macOS',
        'version': 25,
      },
      'roles': {'admin', 'user'},
      'a record': ("value", "more", "data"),
      'escapedStrings': [
        'Sting"With"Quotes',
        '\\wi\\th\\s\\paces',
        null,
        "null",
        true,
        'true',
      ],
    },
  );

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
    formatOptions: [const RainbowFormatOptions()],
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

// Logger for section headers with newline prefix and no level
final sectionLogger = ChirpLogger()
  ..addConsoleWriter(
    formatter: RainbowMessageFormatter(
      options: const RainbowFormatOptions(
        showLogLevel: true,
        showMethod: false,
      ),
      spanTransformers: [
        _prependNewlineForSectionHeaders,
        _removeLevel,
      ],
    ),
  );

/// Prepends a newline before messages starting with "=== ".
void _prependNewlineForSectionHeaders(LogSpan tree, LogRecord record) {
  final message = record.message?.toString() ?? '';
  if (message.startsWith('=== ')) {
    // Find the root sequence and prepend a newline
    if (tree is MultiChildSpan) {
      tree.insertChild(0, NewLine());
    }
  }
}

/// Removes the BracketedLogLevel span from the output.
void _removeLevel(LogSpan tree, LogRecord record) {
  tree.findFirst<BracketedLogLevel>()?.remove();
}

/// Wraps WTF level messages in a bordered box.
void _boxWtfMessages(LogSpan tree, LogRecord record) {
  if (record.level != ChirpLogLevel.wtf) return;

  tree.wrap(
    (child) => Bordered(
      child: child,
      style: BoxBorderStyle.rounded,
      borderColor: XtermColor.red3_160, // red
    ),
  );
}
