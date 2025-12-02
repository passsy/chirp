import 'dart:collection';

import 'package:chirp_protocol/src/chirp_writer.dart';
import 'package:chirp_protocol/src/format_option.dart';
import 'package:chirp_protocol/src/log_level.dart';
import 'package:chirp_protocol/src/log_record.dart';
import 'package:clock/clock.dart';

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
/// Chirp.root = ChirpLogger()
///   ..addWriter(myCustomWriter);
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
  /// Chirp.root = ChirpLogger()
  ///   ..addWriter(myWriter);
  /// ```
  static ChirpLogger root = ChirpLogger();

  /// {@template chirp.log}
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
  /// {@endtemplate}
  static void log(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    ChirpLogLevel level = ChirpLogLevel.info,
    List<FormatOptions>? formatOptions,
    int? skipFrames,
  }) {
    root.log(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
      skipFrames: skipFrames,
    );
  }

  /// {@template chirp.trace}
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
  /// See also:
  /// - [debug] for less verbose diagnostic information
  /// - [ChirpLogLevel.trace] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.debug}
  /// Logs a debug message (severity: 100) - diagnostic information.
  ///
  /// Use debug for:
  /// - Function parameters and return values
  /// - State changes during operations
  /// - Branch decisions (which if/else path taken)
  /// - Resource allocation/deallocation
  ///
  /// Debug logs are usually enabled during development and disabled in production.
  ///
  /// See also:
  /// - [trace] for more detailed debugging
  /// - [info] for production-ready operational messages
  /// - [ChirpLogLevel.debug] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.info}
  /// Logs an info message (severity: 200) - routine operational messages.
  ///
  /// Use info for:
  /// - Application startup/shutdown
  /// - Configuration loaded
  /// - Service started/stopped
  /// - Request received/completed
  ///
  /// Info is the standard production logging level.
  ///
  /// See also:
  /// - [debug] for development-time diagnostic messages
  /// - [notice] for more significant operational events
  /// - [ChirpLogLevel.info] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.notice}
  /// Logs a notice message (severity: 300) - normal but significant events.
  ///
  /// Use notice for:
  /// - Important state transitions
  /// - Security events (successful login, permission changes)
  /// - Configuration changes applied
  /// - Significant business events
  ///
  /// See also:
  /// - [info] for routine operational messages
  /// - [warning] for potentially problematic situations
  /// - [ChirpLogLevel.notice] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.warning}
  /// Logs a warning message (severity: 400) - potentially problematic situations.
  ///
  /// Use warning for:
  /// - Deprecated feature usage
  /// - Approaching resource limits
  /// - Recoverable errors (retry succeeded)
  /// - Unexpected but handled situations
  ///
  /// See also:
  /// - [notice] for significant but normal events
  /// - [error] for actual errors preventing operations
  /// - [ChirpLogLevel.warning] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.error}
  /// Logs an error message (severity: 500) - errors preventing specific operations.
  ///
  /// Use error for:
  /// - Failed API requests
  /// - Database query failures
  /// - Validation errors
  /// - Operations that failed but app continues
  ///
  /// Always include the exception and stack trace when available.
  ///
  /// See also:
  /// - [warning] for recoverable issues
  /// - [critical] for severe errors affecting core functionality
  /// - [ChirpLogLevel.error] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.critical}
  /// Logs a critical message (severity: 600) - severe errors affecting core functionality.
  ///
  /// Use critical for:
  /// - Database connection lost
  /// - Core service unavailable
  /// - Data corruption detected
  /// - Security breach detected
  ///
  /// See also:
  /// - [error] for errors affecting individual operations
  /// - [wtf] for impossible situations that should never happen
  /// - [ChirpLogLevel.critical] for the log level constant
  /// {@endtemplate}
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

  /// {@template chirp.wtf}
  /// Logs a WTF message (severity: 1000) - "What a Terrible Failure" for impossible situations.
  ///
  /// Use wtf for:
  /// - Situations that should be logically impossible
  /// - Invariant violations
  /// - Corrupt state detected
  ///
  /// Inspired by Android's Log.wtf().
  ///
  /// See also:
  /// - [critical] for severe but possible errors
  /// - [error] for expected error conditions
  /// - [ChirpLogLevel.wtf] for the log level constant
  /// {@endtemplate}
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

/// Flexible logger class supporting named loggers, instance tracking, and child loggers.
///
/// [ChirpLogger] provides instance methods for logging at different severity
/// levels. It supports:
/// - Named loggers for different subsystems
/// - Instance tracking for object-specific logging
/// - Child loggers with inherited configuration
/// - Contextual data that persists across log calls
/// - Custom writers
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
/// ```
///
/// See also:
/// - [Chirp] for convenient static logging methods
/// - [ChirpLogLevel] for available severity levels
/// - [ChirpWriter] for implementing custom writers
class ChirpLogger {
  /// Optional name for this logger.
  final String? name;

  /// Optional instance reference for object-specific logging.
  final Object? instance;

  /// Parent logger for delegation.
  final ChirpLogger? parent;

  /// Internal mutable list of writers owned by this logger.
  final List<ChirpWriter> _writers = [];

  /// Read-only view of writers owned by this logger.
  List<ChirpWriter> get writers => UnmodifiableListView(_writers);

  /// Adds a writer to this logger.
  void addWriter(ChirpWriter writer) {
    if (_writers.contains(writer)) return;
    _writers.add(writer);
  }

  /// Removes a writer from this logger.
  bool removeWriter(ChirpWriter writer) {
    return _writers.remove(writer);
  }

  /// Get all effective writers for this logger (own + inherited from parents).
  List<ChirpWriter> get _effectiveWriters {
    final p = parent;
    if (p == null) return _writers;
    final parentWriters = p._effectiveWriters;
    if (_writers.isEmpty) return parentWriters;
    if (parentWriters.isEmpty) return _writers;
    return [...parentWriters, ..._writers];
  }

  /// Contextual data automatically included in all log entries.
  final Map<String, Object?> context;

  /// Creates a logger instance with an optional name.
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

  /// {@macro chirp.log}
  void log(
    Object? message, {
    ChirpLogLevel level = ChirpLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
    int? skipFrames,
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

  /// {@macro chirp.trace}
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

  /// {@macro chirp.debug}
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

  /// {@macro chirp.info}
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

  /// {@macro chirp.notice}
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

  /// {@macro chirp.warning}
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

  /// {@macro chirp.error}
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

  /// {@macro chirp.critical}
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

  /// {@macro chirp.wtf}
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
  void _logRecord(LogRecord record) {
    for (final writer in _effectiveWriters) {
      writer.write(record);
    }
  }

  /// Create a child logger with optional name, instance, and/or context (winston-style)
  ChirpLogger child({
    String? name,
    Object? instance,
    Map<String, Object?>? context,
  }) {
    return ChirpLogger._internal(
      name: name ?? this.name,
      instance: instance ?? this.instance,
      parent: this,
      context:
          context != null ? {...this.context, ...context} : {...this.context},
    );
  }

  /// Cache of logger instances per object for the `.chirp` extension.
  static final Expando<ChirpLogger> _instanceCache = Expando();

  /// Creates or retrieves a cached logger for a specific object instance.
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
/// See also:
/// - [ChirpLogger] for manual logger creation
/// - [Chirp] for static logging methods
extension ChirpObjectExt<T extends Object> on T {
  /// Returns an implicit logger for this object instance.
  ///
  /// Every object automatically has its own logger available via this property.
  /// The logger is lazily created on first access and cached for the lifetime
  /// of the object, so repeated calls return the same logger instance.
  ///
  /// Log messages include the object's class name and identity hash code,
  /// making it easy to trace logs back to specific instances when multiple
  /// objects of the same type exist.
  ///
  /// ```dart
  /// class MyService {
  ///   void doWork() {
  ///     chirp.info('Starting work');  // Logs as "MyService@a1b2: Starting work"
  ///   }
  /// }
  /// ```
  ChirpLogger get chirp => ChirpLogger.forInstance(this);
}

/// Merges two data maps, with [override] values taking precedence over [base].
///
/// Returns `null` if both maps are empty. This optimization avoids creating
/// empty maps in log records when no data is present.
Map<String, Object?>? _mergeData(
  Map<String, Object?> base,
  Map<String, Object?>? override,
) {
  if (base.isEmpty && override == null) return null;
  if (base.isEmpty) return override;
  if (override == null || override.isEmpty) return base.isEmpty ? null : base;
  return {...base, ...override};
}
