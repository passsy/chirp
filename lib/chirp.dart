import 'dart:collection';

import 'package:chirp/src/console_writer.dart';
import 'package:chirp/src/format_option.dart';
import 'package:chirp/src/formatters/rainbow_message_formatter.dart';
import 'package:chirp/src/log_level.dart';
import 'package:chirp/src/log_record.dart';
import 'package:clock/clock.dart';

export 'package:chirp/src/console_writer.dart';
export 'package:chirp/src/format_option.dart';
export 'package:chirp/src/formatters/compact_message_formatter.dart';
export 'package:chirp/src/formatters/json_message_formatter.dart';
export 'package:chirp/src/formatters/rainbow_message_formatter.dart';
export 'package:chirp/src/formatters/simple_console_message_formatter.dart';
export 'package:chirp/src/log_level.dart';
export 'package:chirp/src/log_record.dart';
export 'package:chirp/src/stack_trace_util.dart';

// ignore: avoid_classes_with_only_static_members
/// Global static logger providing convenient access to logging functionality.
///
/// The [Chirp] class provides static methods for logging at different severity
/// levels. It delegates to [root], the global [ChirpLogger] instance that can
/// be customized with different writers and formatters.
///
/// ## Quick Start
///
/// ```dart
/// Chirp.info('Application started');
/// Chirp.warning('Cache miss', data: {'key': 'user_123'});
/// Chirp.error('Request failed', error: e, stackTrace: stackTrace);
/// ```
///
/// ## Available Log Levels (by severity)
///
/// - [trace] (0) - Most detailed execution information
/// - [debug] (100) - Diagnostic information for troubleshooting
/// - [info] (200) - Routine operational messages (default)
/// - [notice] (300) - Normal but significant events
/// - [warning] (400) - Potentially problematic situations
/// - [error] (500) - Errors that prevent specific operations
/// - [critical] (600) - Severe errors affecting core functionality
/// - [wtf] (1000) - Impossible situations that should never happen
///
/// ## Customizing the Global Logger
///
/// Replace [root] to configure logging globally:
///
/// ```dart
/// // Use custom formatter
/// Chirp.root = ChirpLogger(
///   writers: [
///     ConsoleChirpMessageWriter(
///       formatter: JsonChirpMessageFormatter(),
///     ),
///   ],
/// );
///
/// // Multiple writers
/// Chirp.root = ChirpLogger(
///   writers: [
///     ConsoleChirpMessageWriter(),
///     FileChirpMessageWriter('/var/log/app.log'),
///   ],
/// );
/// ```
///
/// ## Instance Logging
///
/// For object-specific logging, use the `.chirp` extension:
///
/// ```dart
/// class PaymentService {
///   void processPayment() {
///     chirp.info('Processing payment'); // Includes instance hash
///   }
/// }
/// ```
///
/// ## Structured Logging
///
/// Add contextual data to any log entry:
///
/// ```dart
/// Chirp.info('User action', data: {
///   'userId': 'user_123',
///   'action': 'login',
///   'timestamp': DateTime.now().toIso8601String(),
/// });
/// ```
///
/// See also:
/// - [ChirpLogger] for creating custom logger instances
/// - [ChirpLogLevel] for understanding severity levels
/// - [ChirpWriter] for implementing custom log destinations
// ignore: avoid_classes_with_only_static_members
class Chirp {
  /// Global root logger used by all static methods and the `.chirp` extension.
  ///
  /// Replace this with a custom [ChirpLogger] instance to configure logging
  /// globally for your entire application.
  ///
  /// Example:
  /// ```dart
  /// Chirp.root = ChirpLogger(
  ///   writers: [
  ///     ConsoleChirpMessageWriter(
  ///       formatter: GcpChirpMessageFormatter(
  ///         projectId: 'my-project',
  ///         logName: 'application-logs',
  ///       ),
  ///     ),
  ///   ],
  /// );
  /// ```
  static ChirpLogger root = ChirpLogger();

  /// Logs a message at a custom severity level.
  ///
  /// Use this when you need a log level not provided by the convenience
  /// methods, or when the level is determined dynamically.
  ///
  /// Parameters:
  /// - [message]: The log message (can be any object, will be converted via `toString()`)
  /// - [level]: The severity level (defaults to [ChirpLogLevel.info])
  /// - [error]: Optional error object to log
  /// - [stackTrace]: Optional stack trace (often from a catch block)
  /// - [data]: Optional structured data as key-value pairs
  /// - [formatOptions]: Optional formatting hints for writers/formatters
  ///
  /// Example:
  /// ```dart
  /// // Custom log level
  /// const alert = ChirpLogLevel('alert', 700);
  /// Chirp.log('System alert', level: alert, data: {'severity': 'high'});
  ///
  /// // Dynamic level selection
  /// final level = isProduction ? ChirpLogLevel.error : ChirpLogLevel.debug;
  /// Chirp.log('Environment-specific message', level: level);
  /// ```
  ///
  /// See also:
  /// - [info], [warning], [error] and other convenience methods
  /// - [ChirpLogLevel] for standard log levels
  static void log(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    ChirpLogLevel level = ChirpLogLevel.info,
    List<FormatOptions>? formatOptions,
  }) {
    root.log(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs a trace message (severity: 0) - most detailed execution information.
  ///
  /// Use trace for:
  /// - Detailed execution flow (entering/exiting methods)
  /// - Variable values at each step
  /// - Loop iterations and fine-grained debugging
  ///
  /// Trace logs are typically disabled in production due to high volume.
  /// They're most useful during development or when debugging specific issues.
  ///
  /// Example:
  /// ```dart
  /// void processData(List<String> items) {
  ///   Chirp.trace('Entering processData', data: {'itemCount': items.length});
  ///
  ///   for (final item in items) {
  ///     Chirp.trace('Processing item', data: {'item': item});
  ///     // ... processing logic
  ///   }
  ///
  ///   Chirp.trace('Exiting processData');
  /// }
  /// ```
  ///
  /// See also:
  /// - [debug] for less verbose diagnostic information
  /// - [ChirpLogLevel.trace] for the log level constant
  static void trace(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.log(
      message,
      level: ChirpLogLevel.trace,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs a debug message (severity: 100) - diagnostic information.
  ///
  /// Use debug for:
  /// - Function parameters and return values
  /// - State changes during operations
  /// - Branch decisions (which if/else path taken)
  /// - Resource allocation/deallocation
  ///
  /// Debug logs are usually enabled during development and disabled in production.
  /// They help troubleshoot issues without the extreme verbosity of trace logs.
  ///
  /// Example:
  /// ```dart
  /// User? authenticate(String username, String password) {
  ///   Chirp.debug('Authenticating user', data: {'username': username});
  ///
  ///   final user = database.findUser(username);
  ///   if (user == null) {
  ///     Chirp.debug('User not found');
  ///     return null;
  ///   }
  ///
  ///   Chirp.debug('User found, verifying password');
  ///   return user;
  /// }
  /// ```
  ///
  /// See also:
  /// - [trace] for more detailed debugging
  /// - [info] for production-ready operational messages
  /// - [ChirpLogLevel.debug] for the log level constant
  static void debug(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.debug(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs an info message (severity: 200) - routine operational messages.
  ///
  /// Use info for:
  /// - Application startup/shutdown
  /// - Configuration loaded
  /// - Service started/stopped
  /// - Request received/completed
  /// - User logged in/out
  /// - Job started/finished
  ///
  /// Info is the standard production logging level. Messages should be
  /// meaningful to operators monitoring the system.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   Chirp.info('Application starting', data: {
  ///     'version': '1.2.3',
  ///     'environment': 'production',
  ///   });
  ///
  ///   await database.connect();
  ///   Chirp.info('Database connected');
  ///
  ///   await server.start();
  ///   Chirp.info('Server listening', data: {'port': 8080});
  /// }
  /// ```
  ///
  /// See also:
  /// - [debug] for development-time diagnostic messages
  /// - [notice] for more significant operational events
  /// - [ChirpLogLevel.info] for the log level constant
  static void info(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.info(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs a notice message (severity: 300) - normal but significant events.
  ///
  /// Use notice for:
  /// - Important state transitions
  /// - Security events (successful login, permission changes)
  /// - Configuration changes applied
  /// - Significant business events
  /// - Data migrations started/completed
  /// - System mode changes (maintenance mode, read-only mode)
  ///
  /// Notice logs are more significant than info but not warnings. They indicate
  /// events that operators should be aware of. Commonly used in GCP Cloud
  /// Logging, Syslog, and other logging systems.
  ///
  /// Example:
  /// ```dart
  /// void updateUserRole(String userId, String newRole) {
  ///   final oldRole = user.role;
  ///   user.role = newRole;
  ///
  ///   Chirp.notice('User role changed', data: {
  ///     'userId': userId,
  ///     'oldRole': oldRole,
  ///     'newRole': newRole,
  ///     'changedBy': currentUser.id,
  ///   });
  /// }
  ///
  /// void enableMaintenanceMode() {
  ///   system.maintenanceMode = true;
  ///   Chirp.notice('Maintenance mode enabled');
  /// }
  /// ```
  ///
  /// See also:
  /// - [info] for routine operational messages
  /// - [warning] for potentially problematic situations
  /// - [ChirpLogLevel.notice] for the log level constant
  static void notice(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.notice(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs a warning message (severity: 400) - potentially problematic situations.
  ///
  /// Use warning for:
  /// - Deprecated feature usage
  /// - Approaching resource limits (80% disk space)
  /// - Recoverable errors (retry succeeded)
  /// - Unexpected but handled situations
  /// - Performance degradation
  /// - Configuration issues that don't prevent operation
  ///
  /// Warnings indicate something that should be investigated but isn't critical.
  /// The application can continue operating normally.
  ///
  /// Example:
  /// ```dart
  /// Future<Data> fetchData() async {
  ///   try {
  ///     return await api.getData();
  ///   } catch (e, stackTrace) {
  ///     Chirp.warning(
  ///       'API request failed, using cache',
  ///       error: e,
  ///       stackTrace: stackTrace,
  ///       data: {'cacheAge': cache.age},
  ///     );
  ///     return cache.getData();
  ///   }
  /// }
  ///
  /// void checkDiskSpace() {
  ///   final usage = disk.usagePercent;
  ///   if (usage > 80) {
  ///     Chirp.warning('Disk space running low', data: {'usage': '$usage%'});
  ///   }
  /// }
  /// ```
  ///
  /// See also:
  /// - [notice] for significant but normal events
  /// - [error] for actual errors preventing operations
  /// - [ChirpLogLevel.warning] for the log level constant
  static void warning(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.warning(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs an error message (severity: 500) - errors preventing specific operations.
  ///
  /// Use error for:
  /// - Failed API requests
  /// - Database query failures
  /// - File not found
  /// - Validation errors
  /// - Exceptions that were caught and handled
  /// - Operations that failed but app continues
  ///
  /// Errors indicate a problem occurred but the application can continue.
  /// Always include the exception and stack trace when available.
  ///
  /// Example:
  /// ```dart
  /// Future<User> loadUser(String id) async {
  ///   try {
  ///     return await database.findUser(id);
  ///   } catch (e, stackTrace) {
  ///     Chirp.error(
  ///       'Failed to load user',
  ///       error: e,
  ///       stackTrace: stackTrace,
  ///       data: {'userId': id},
  ///     );
  ///     rethrow;
  ///   }
  /// }
  ///
  /// void handleRequest(Request req) {
  ///   try {
  ///     processRequest(req);
  ///   } catch (e, stackTrace) {
  ///     Chirp.error(
  ///       'Request processing failed',
  ///       error: e,
  ///       stackTrace: stackTrace,
  ///       data: {'requestId': req.id},
  ///     );
  ///     // Continue processing other requests
  ///   }
  /// }
  /// ```
  ///
  /// See also:
  /// - [warning] for recoverable issues
  /// - [critical] for severe errors affecting core functionality
  /// - [ChirpLogLevel.error] for the log level constant
  static void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.error(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs a critical message (severity: 600) - severe errors affecting core functionality.
  ///
  /// Use critical for:
  /// - Database connection lost
  /// - Core service unavailable
  /// - Data corruption detected
  /// - Security breach detected
  /// - System resource exhaustion
  /// - Critical business process failure
  ///
  /// Critical errors require immediate attention and may affect multiple users
  /// or operations. They should trigger alerts and investigation.
  ///
  /// Example:
  /// ```dart
  /// Future<void> initializeDatabase() async {
  ///   try {
  ///     await database.connect();
  ///   } catch (e, stackTrace) {
  ///     Chirp.critical(
  ///       'Database connection failed - service unavailable',
  ///       error: e,
  ///       stackTrace: stackTrace,
  ///       data: {
  ///         'host': database.host,
  ///         'retryCount': retries,
  ///       },
  ///     );
  ///     // Trigger alerts, graceful shutdown, etc.
  ///   }
  /// }
  ///
  /// void detectDataCorruption(Data data) {
  ///   if (!data.checksumValid) {
  ///     Chirp.critical('Data corruption detected', data: {
  ///       'dataId': data.id,
  ///       'expectedChecksum': data.expectedChecksum,
  ///       'actualChecksum': data.actualChecksum,
  ///     });
  ///   }
  /// }
  /// ```
  ///
  /// See also:
  /// - [error] for errors affecting individual operations
  /// - [wtf] for impossible situations that should never happen
  /// - [ChirpLogLevel.critical] for the log level constant
  static void critical(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.critical(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// Logs a WTF message (severity: 1000) - "What a Terrible Failure" for impossible situations.
  ///
  /// Use wtf for:
  /// - Situations that should be logically impossible
  /// - Invariant violations
  /// - Corrupt state detected
  /// - "This should never happen" conditions
  /// - Critical assertions failed
  ///
  /// WTF is inspired by Android's Log.wtf(). It indicates a programmer error
  /// or serious system corruption. These logs should trigger alerts and
  /// immediate investigation.
  ///
  /// Example:
  /// ```dart
  /// void processAge(int age) {
  ///   if (age < 0) {
  ///     Chirp.wtf('User age is negative', data: {
  ///       'age': age,
  ///       'userId': user.id,
  ///     });
  ///     // This violates our data model invariants
  ///   }
  /// }
  ///
  /// void handleEnum(Status status) {
  ///   switch (status) {
  ///     case Status.pending:
  ///       // handle pending
  ///       break;
  ///     case Status.completed:
  ///       // handle completed
  ///       break;
  ///     default:
  ///       Chirp.wtf('Unknown status value', data: {'status': status});
  ///       // Should be impossible if enum is exhaustive
  ///   }
  /// }
  ///
  /// void verifyMath() {
  ///   if (2 + 2 != 4) {
  ///     Chirp.wtf('Mathematics broken');
  ///     // Universe is ending
  ///   }
  /// }
  /// ```
  ///
  /// See also:
  /// - [critical] for severe but possible errors
  /// - [error] for expected error conditions
  /// - [ChirpLogLevel.wtf] for the log level constant
  static void wtf(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    root.log(
      message,
      level: ChirpLogLevel.wtf,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }
}

/// Merges two data maps, with [override] values taking precedence over [base].
///
/// Returns `null` if both maps are empty. This optimization avoids creating
/// empty maps in log records when no data is present.
///
/// When both maps contain the same key, the value from [override] is used.
/// This allows per-call data to override contextual data from the logger.
Map<String, Object?>? _mergeData(
  Map<String, Object?> base,
  Map<String, Object?>? override,
) {
  if (base.isEmpty && override == null) return null;
  if (base.isEmpty) return override;
  if (override == null || override.isEmpty) return base.isEmpty ? null : base;
  return {...base, ...override};
}

/// Flexible logger class supporting named loggers, instance tracking, and child loggers.
///
/// [ChirpLogger] provides instance methods for logging at different severity
/// levels. It supports:
/// - Named loggers for different subsystems
/// - Instance tracking for object-specific logging
/// - Child loggers with inherited configuration
/// - Contextual data that persists across log calls
/// - Custom writers and formatters
///
/// ## Named Loggers
///
/// Create named loggers for different parts of your application:
///
/// ```dart
/// final apiLogger = ChirpLogger(name: 'API');
/// final dbLogger = ChirpLogger(name: 'Database');
///
/// apiLogger.info('Request received');
/// dbLogger.info('Query executed');
/// ```
///
/// ## Instance Tracking
///
/// Use the `.chirp` extension for automatic instance tracking:
///
/// ```dart
/// class PaymentProcessor {
///   void process() {
///     chirp.info('Processing payment'); // Includes instance hash
///   }
/// }
/// ```
///
/// ## Child Loggers (Winston-style)
///
/// Create child loggers that inherit parent configuration and context:
///
/// ```dart
/// final requestLogger = Chirp.root.child(context: {
///   'requestId': 'REQ-123',
///   'userId': 'user_456',
/// });
///
/// requestLogger.info('Request started'); // Includes requestId and userId
///
/// final txLogger = requestLogger.child(context: {
///   'transactionId': 'TXN-789',
/// });
///
/// txLogger.info('Transaction complete'); // Includes all parent context
/// ```
///
/// ## Custom Writers
///
/// Configure custom writers for different destinations:
///
/// ```dart
/// final logger = ChirpLogger(
///   writers: [
///     ConsoleChirpMessageWriter(
///       formatter: JsonChirpMessageFormatter(),
///     ),
///     FileChirpMessageWriter('/var/log/app.log'),
///     SentryChirpMessageWriter(),
///   ],
/// );
/// ```
///
/// ## Mutable Context
///
/// Add or remove context dynamically:
///
/// ```dart
/// final logger = ChirpLogger(context: {'service': 'api'});
///
/// logger.context['requestId'] = 'REQ-123';
/// logger.info('Processing'); // Includes service and requestId
///
/// logger.context.remove('requestId');
/// logger.info('Done'); // Only includes service
/// ```
///
/// See also:
/// - [Chirp] for convenient static logging methods
/// - [ChirpLogLevel] for available severity levels
/// - [ChirpWriter] for implementing custom writers
class ChirpLogger {
  /// Optional name for this logger.
  ///
  /// Used to identify which subsystem or component generated the log.
  /// Appears in log output to help filter and organize logs.
  ///
  /// Example:
  /// ```dart
  /// final apiLogger = ChirpLogger(name: 'API');
  /// final dbLogger = ChirpLogger(name: 'Database');
  /// ```
  final String? name;

  /// Optional instance reference for object-specific logging.
  ///
  /// When using the `.chirp` extension, this is automatically set to the
  /// object instance. The instance's identity hash code is included in logs
  /// to distinguish between different instances of the same class.
  ///
  /// Example:
  /// ```dart
  /// class Service {
  ///   void process() {
  ///     chirp.info('Processing'); // Includes instance identity
  ///   }
  /// }
  /// ```
  final Object? instance;

  /// Parent logger for delegation.
  ///
  /// Child loggers delegate to their parent for writer configuration. This
  /// allows child loggers to inherit the parent's logging configuration while
  /// having their own name, instance, and context.
  final ChirpLogger? parent;

  /// Internal mutable list of writers owned by this logger.
  final List<ChirpWriter> _writers = [];

  /// Read-only view of writers owned by this logger.
  ///
  /// Use [addWriter] and [removeWriter] to modify the writers list.
  /// Both root and child loggers can have their own writers. When logging,
  /// this logger's writers are combined with all parent writers.
  ///
  /// If no writers are configured anywhere in the hierarchy, no output
  /// will be produced.
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'API');
  ///
  /// // Add writers
  /// logger.addWriter(ConsoleWriter());
  /// logger.addConsoleWriter(formatter: JsonMessageFormatter());
  ///
  /// // Check current writers
  /// print(logger.writers.length);
  ///
  /// // Remove a specific writer
  /// logger.removeWriter(myWriter);
  /// ```
  List<ChirpWriter> get writers => UnmodifiableListView(_writers);

  /// Adds a writer to this logger.
  ///
  /// Writers receive all log records from this logger and its children.
  /// You can add multiple writers to send logs to different destinations.
  ///
  /// Adding the same writer instance twice is a no-op - each writer can only
  /// be added once to a logger.
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'API')
  ///   ..addWriter(ConsoleWriter())
  ///   ..addWriter(FileWriter('/var/log/api.log'));
  /// ```
  ///
  /// See also:
  /// - [addConsoleWriter] for a convenient shorthand
  /// - [removeWriter] to remove a writer
  /// - [writers] for the read-only list of current writers
  void addWriter(ChirpWriter writer) {
    if (_writers.contains(writer)) return;
    _writers.add(writer);
  }

  /// Removes a writer from this logger.
  ///
  /// Returns `true` if the writer was found and removed, `false` otherwise.
  /// Only removes writers from this logger, not from parent loggers.
  ///
  /// Example:
  /// ```dart
  /// final writer = ConsoleWriter();
  /// logger.addWriter(writer);
  ///
  /// // Later...
  /// final removed = logger.removeWriter(writer);
  /// print(removed); // true
  /// ```
  ///
  /// See also:
  /// - [addWriter] to add a writer
  /// - [writers] for the read-only list of current writers
  bool removeWriter(ChirpWriter writer) {
    return _writers.remove(writer);
  }

  /// Get all effective writers for this logger (own + inherited from parents).
  ///
  /// This combines this logger's [_writers] with all parent writers.
  /// Used internally when logging to dispatch to all relevant writers.
  List<ChirpWriter> get _effectiveWriters {
    final p = parent;
    if (p == null) return _writers;
    final parentWriters = p._effectiveWriters;
    if (_writers.isEmpty) return parentWriters;
    if (parentWriters.isEmpty) return _writers;
    return [...parentWriters, ..._writers];
  }

  /// Convenient shorthand to add a [ConsoleWriter] with optional formatter.
  ///
  /// This is the most common writer configuration. If no [formatter] is
  /// provided, uses [RainbowMessageFormatter] by default.
  ///
  /// Parameters:
  /// - [formatter]: Custom formatter (defaults to [RainbowMessageFormatter])
  /// - [output]: Custom output function (defaults to [print])
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'API')
  ///   ..addConsoleWriter(); // Uses RainbowMessageFormatter
  ///
  /// // With custom formatter
  /// final jsonLogger = ChirpLogger(name: 'JSON')
  ///   ..addConsoleWriter(formatter: JsonMessageFormatter());
  ///
  /// // Capture output for testing
  /// final messages = <String>[];
  /// final testLogger = ChirpLogger(name: 'Test')
  ///   ..addConsoleWriter(output: messages.add);
  /// ```
  ///
  /// See also:
  /// - [addWriter] for adding custom writers
  /// - [ConsoleWriter] for more configuration options
  void addConsoleWriter({
    ConsoleMessageFormatter? formatter,
    void Function(String)? output,
  }) {
    addWriter(
      ConsoleWriter(
        formatter: formatter ?? RainbowMessageFormatter(),
        output: output,
      ),
    );
  }

  /// Contextual data automatically included in all log entries.
  ///
  /// Context is useful for per-request or per-transaction loggers where
  /// you want to attach common data like requestId, userId, etc. to every
  /// log message without repeating it.
  ///
  /// The map is **mutable** and can be modified during the logger's lifetime:
  ///
  /// ```dart
  /// final logger = ChirpLogger(name: 'API', context: {'service': 'api'});
  ///
  /// // Add context as it becomes available
  /// logger.context['requestId'] = 'REQ-123';
  /// logger.context['userId'] = 'user_456';
  /// logger.info('Processing'); // Includes service, requestId, userId
  ///
  /// // Remove context when no longer needed
  /// logger.context.remove('userId');
  /// logger.info('Complete'); // Includes service, requestId only
  /// ```
  ///
  /// When using child loggers, context from parent loggers is merged with
  /// child context, with child values taking precedence:
  ///
  /// ```dart
  /// final parent = ChirpLogger(context: {'app': 'myapp'});
  /// final child = parent.child(context: {'requestId': 'REQ-123'});
  /// child.info('Log'); // Includes both app and requestId
  /// ```
  final Map<String, Object?> context;

  /// Creates a logger instance with an optional name.
  ///
  /// Parameters:
  /// - [name]: Optional name to identify this logger's source (e.g., 'API', 'Database')
  ///
  /// Use [addWriter] to attach writers after creation:
  ///
  /// ```dart
  /// final logger = ChirpLogger(name: 'API')
  ///   ..addWriter(ConsoleWriter())
  ///   ..addWriter(FileWriter('/var/log/api.log'));
  ///
  /// // Add contextual data
  /// logger.context['version'] = '1.0';
  /// logger.context['service'] = 'api';
  /// ```
  ///
  /// For child loggers, use the [child] method instead:
  /// ```dart
  /// final childLogger = parentLogger.child(
  ///   name: 'Subsystem',
  ///   context: {'requestId': 'REQ-123'},
  /// );
  /// ```
  ChirpLogger({this.name})
      : instance = null,
        parent = null,
        context = {};

  /// Internal constructor for creating child loggers and instance loggers.
  ChirpLogger._internal({
    this.name,
    this.instance,
    this.parent,
    Map<String, Object?>? context,
  }) : context = context ?? {};

  /// Logs a message at the specified severity level.
  ///
  /// This is the base logging method used by all level-specific methods
  /// ([trace], [debug], [info], etc.). Use this when you need a custom log
  /// level or when the level is determined dynamically.
  ///
  /// Parameters:
  /// - [message]: The log message (any object, converted via `toString()`)
  /// - [level]: The severity level (defaults to [ChirpLogLevel.info])
  /// - [error]: Optional error/exception object
  /// - [stackTrace]: Optional stack trace (typically from a catch block)
  /// - [data]: Optional structured data as key-value pairs
  /// - [formatOptions]: Optional formatting hints for writers/formatters
  ///
  /// The logger automatically captures:
  /// - Current timestamp via `clock.now()`
  /// - Caller stack trace for source location
  /// - Logger name (if set)
  /// - Instance identity (if set)
  /// - Merged context data and per-call data
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'API');
  ///
  /// // Custom level
  /// const alert = ChirpLogLevel('alert', 700);
  /// logger.log('High priority event', level: alert);
  ///
  /// // Dynamic level
  /// final level = isDev ? ChirpLogLevel.debug : ChirpLogLevel.info;
  /// logger.log('Environment message', level: level);
  /// ```
  ///
  /// See also:
  /// - [Chirp.log] for the static equivalent
  /// - Level-specific methods: [trace], [debug], [info], [notice], [warning], [error], [critical], [wtf]
  void log(
    Object? message, {
    ChirpLogLevel level = ChirpLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
    int skipFrames = 0,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      skipFrames: skipFrames,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs a trace message (severity: 0).
  ///
  /// Instance method equivalent of [Chirp.trace]. See [Chirp.trace] for
  /// detailed documentation on when to use trace logging.
  ///
  /// Use for detailed execution flow, variable values, and fine-grained debugging.
  void trace(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.trace,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs a debug message (severity: 100).
  ///
  /// Instance method equivalent of [Chirp.debug]. See [Chirp.debug] for
  /// detailed documentation on when to use debug logging.
  ///
  /// Use for diagnostic information, state changes, and troubleshooting.
  void debug(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.debug,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs an info message (severity: 200).
  ///
  /// Instance method equivalent of [Chirp.info]. See [Chirp.info] for
  /// detailed documentation on when to use info logging.
  ///
  /// Use for routine operational messages like startup, shutdown, and normal events.
  void info(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      // ignore: avoid_redundant_argument_values
      level: ChirpLogLevel.info,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs a notice message (severity: 300).
  ///
  /// Instance method equivalent of [Chirp.notice]. See [Chirp.notice] for
  /// detailed documentation on when to use notice logging.
  ///
  /// Use for normal but significant events like security events and configuration changes.
  void notice(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.notice,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs a warning message (severity: 400).
  ///
  /// Instance method equivalent of [Chirp.warning]. See [Chirp.warning] for
  /// detailed documentation on when to use warning logging.
  ///
  /// Use for potentially problematic situations that don't prevent operation.
  void warning(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.warning,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs an error message (severity: 500).
  ///
  /// Instance method equivalent of [Chirp.error]. See [Chirp.error] for
  /// detailed documentation on when to use error logging.
  ///
  /// Use for errors that prevent specific operations. Always include error and stackTrace.
  void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.error,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs a critical message (severity: 600).
  ///
  /// Instance method equivalent of [Chirp.critical]. See [Chirp.critical] for
  /// detailed documentation on when to use critical logging.
  ///
  /// Use for severe errors affecting core functionality that require immediate attention.
  void critical(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.critical,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Logs a WTF message (severity: 1000) - for impossible situations.
  ///
  /// Instance method equivalent of [Chirp.wtf]. See [Chirp.wtf] for
  /// detailed documentation on when to use WTF logging.
  ///
  /// Use for logically impossible situations, invariant violations, and corrupt state.
  void wtf(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.wtf,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Writes a log record to all configured writers.
  ///
  /// This internal method is called by all logging methods after creating
  /// a [LogRecord]. It iterates through all effective writers (own + inherited)
  /// and calls each writer's `write()` method with the record.
  ///
  /// Writers are responsible for formatting and outputting the log record
  /// to their respective destinations (console, file, network, etc.).
  void _logRecord(LogRecord record) {
    for (final writer in _effectiveWriters) {
      writer.write(record);
    }
  }

  /// Create a child logger with optional name, instance, and/or context (winston-style)
  ///
  /// Child loggers inherit their parent's writers configuration but can
  /// have their own name, instance, and context. This is useful for creating
  /// per-request or per-transaction loggers:
  ///
  /// ```dart
  /// // Add context only
  /// final requestLogger = Chirp.root.child(context: {
  ///   'requestId': 'REQ-123',
  ///   'userId': 'user_456',
  /// });
  ///
  /// // Add name only
  /// final apiLogger = Chirp.root.child(name: 'API');
  ///
  /// // Add instance (for object tracking)
  /// final instanceLogger = Chirp.root.child(instance: this);
  ///
  /// // Combine name and context
  /// final logger = Chirp.root.child(
  ///   name: 'PaymentService',
  ///   context: {'requestId': 'REQ-123'},
  /// );
  ///
  /// // All logs from child logger inherit parent's writers
  /// requestLogger.info('Processing request');
  /// ```
  ///
  /// Context from the parent logger is merged with the new context,
  /// with new context taking precedence. Child loggers always use
  /// their parent's (eventually root's) writers configuration.
  ChirpLogger child({
    String? name,
    Object? instance,
    Map<String, Object?>? context,
  }) {
    return ChirpLogger._internal(
      name: name ?? this.name,
      instance: instance ?? this.instance,
      parent: this,
      context: context != null ? {...this.context, ...context} : {...this.context},
    );
  }

  /// Cache of logger instances per object for the `.chirp` extension.
  ///
  /// Uses [Expando] to associate loggers with objects without affecting their
  /// memory lifecycle. When an object is garbage collected, its cached logger
  /// is automatically removed.
  static final Expando<ChirpLogger> _instanceCache = Expando();

  /// Creates or retrieves a cached logger for a specific object instance.
  ///
  /// This factory is used internally by the `.chirp` extension to provide
  /// instance-specific logging. It caches logger instances per object using
  /// [Expando], so repeated calls with the same object return the same logger.
  ///
  /// The returned logger is a child of [Chirp.root] with the [instance]
  /// parameter set to the provided [object].
  ///
  /// Example:
  /// ```dart
  /// final service = MyService();
  /// final logger = ChirpLogger.forInstance(service);
  /// logger.info('Hello'); // Includes MyService instance identity
  /// ```
  ///
  /// Typically you don't call this directly - use the `.chirp` extension instead:
  /// ```dart
  /// class MyService {
  ///   void doWork() {
  ///     chirp.info('Working'); // Uses ChirpLogger.forInstance internally
  ///   }
  /// }
  /// ```
  factory ChirpLogger.forInstance(Object object) {
    return _instanceCache[object] ??= Chirp.root.child(instance: object);
  }
}

/// Extension providing the `.chirp` property for instance-specific logging.
///
/// This extension makes logging from within objects incredibly convenient.
/// It automatically tracks which instance generated each log message using
/// the object's identity hash code.
///
/// ## Basic Usage
///
/// Simply use `chirp.info()`, `chirp.warning()`, etc. inside any class:
///
/// ```dart
/// class PaymentProcessor {
///   final String merchantId;
///
///   PaymentProcessor(this.merchantId);
///
///   Future<void> processPayment(Payment payment) async {
///     chirp.info('Processing payment', data: {
///       'paymentId': payment.id,
///       'amount': payment.amount,
///       'merchantId': merchantId,
///     });
///
///     try {
///       await gateway.charge(payment);
///       chirp.info('Payment successful');
///     } catch (e, stackTrace) {
///       chirp.error(
///         'Payment failed',
///         error: e,
///         stackTrace: stackTrace,
///       );
///       rethrow;
///     }
///   }
/// }
/// ```
///
/// ## Instance Differentiation
///
/// Logs from different instances are automatically distinguished:
///
/// ```dart
/// final processor1 = PaymentProcessor('merchant_1');
/// final processor2 = PaymentProcessor('merchant_2');
///
/// processor1.chirp.info('Started'); // Shows PaymentProcessor#abc123
/// processor2.chirp.info('Started'); // Shows PaymentProcessor#def456
/// ```
///
/// ## Accessing the Logger
///
/// The `.chirp` property returns a [ChirpLogger] instance:
///
/// ```dart
/// class Service {
///   late final ChirpLogger logger;
///
///   Service() {
///     logger = chirp; // Get the logger instance
///   }
///
///   void doWork() {
///     logger.info('Working'); // Use it later
///   }
/// }
/// ```
///
/// ## Implementation Notes
///
/// - Uses [Expando] to cache logger instances per object
/// - Delegates to [Chirp.root] for writer configuration
/// - Includes the object's runtime type and identity hash in logs
/// - Works with any Dart object (classes, not primitives)
///
/// See also:
/// - [ChirpLogger] for manual logger creation
/// - [Chirp] for static logging methods
extension ChirpObjectExt<T extends Object> on T {
  /// Gets a logger instance for this object with automatic instance tracking.
  ///
  /// The returned logger includes this object's identity in all log entries,
  /// making it easy to trace logs back to specific object instances.
  ///
  /// Logger instances are cached per object using [Expando], so repeated
  /// access to `.chirp` returns the same logger instance.
  ChirpLogger get chirp => ChirpLogger.forInstance(this);
}

/// Abstract interface for log output destinations.
///
/// A [ChirpWriter] receives [LogRecord] instances and writes them to a
/// destination such as the console, a file, a network endpoint, or a
/// monitoring service.
///
/// ## Built-in Writers
///
/// Chirp provides several built-in writers:
///
/// - [ConsoleWriter]: Writes formatted logs to stdout using `print()`
/// - [BufferedAppender]: Buffers logs for later processing or batch sending
/// - [MultiAppender]: Delegates to multiple writers simultaneously
///
/// ## Implementing Custom Writers
///
/// Create custom writers by implementing this interface:
///
/// ```dart
/// class FileWriter implements ChirpWriter {
///   final File logFile;
///
///   FileWriter(String path) : logFile = File(path);
///
///   @override
///   void write(LogRecord record) {
///     final line = '${record.date.toIso8601String()} '
///         '[${record.level.name}] ${record.message}\n';
///     logFile.writeAsStringSync(line, mode: FileMode.append);
///   }
/// }
/// ```
///
/// ## Using Writers with ChirpLogger
///
/// Configure writers when creating a [ChirpLogger]:
///
/// ```dart
/// Chirp.root = ChirpLogger(
///   writers: [
///     ConsoleAppender(formatter: RainbowMessageFormatter()),
///     FileWriter('/var/log/app.log'),
///     SentryWriter(dsn: 'https://...'),
///   ],
/// );
/// ```
///
/// ## Writer Considerations
///
/// When implementing a writer, consider:
///
/// - **Performance**: Writers are called synchronously. For slow operations
///   (network, disk), consider buffering or async processing.
/// - **Error handling**: Writers should handle their own errors gracefully
///   to avoid disrupting the application.
/// - **Thread safety**: If your writer maintains state, ensure thread safety
///   for concurrent access.
/// - **Resource cleanup**: Implement cleanup logic (close files, flush buffers)
///   when the application shuts down.
///
/// See also:
/// - [ConsoleWriter] for console output with formatting
/// - [LogRecord] for the data structure passed to writers
/// - [ChirpLogger] for configuring writers on loggers
abstract class ChirpWriter {
  /// Writes a log record to this writer's destination.
  ///
  /// Implementations should process the [record] and output it to their
  /// respective destination (console, file, network, etc.).
  ///
  /// This method is called synchronously for each log event. Long-running
  /// operations should be handled asynchronously to avoid blocking the
  /// application.
  void write(LogRecord record);
}
