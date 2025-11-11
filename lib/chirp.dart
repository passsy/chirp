import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/log_level.dart';
import 'package:chirp/src/message_writer.dart';
import 'package:clock/clock.dart';

export 'src/log_entry.dart';
export 'src/log_level.dart';
export 'src/message_formatter.dart';
export 'src/message_writer.dart';

// ignore: non_constant_identifier_names
// ChirpLogger get Chirp => ChirpLogger.root;

// ignore: avoid_classes_with_only_static_members
class Chirp {
  /// Global root logger used by top-level chirp functions and extensions
  static ChirpLogger root = ChirpLogger();

  static void log(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    ChirpLogLevel level = ChirpLogLevel.info,
  }) {
    root.log(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void trace(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.log(
      message,
      level: ChirpLogLevel.trace,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void debug(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.debug(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void info(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.info(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void warning(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.warning(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.error(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void critical(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.critical(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  static void wtf(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    root.log(
      message,
      level: ChirpLogLevel.wtf,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }
}

/// Merge two data maps, with override taking precedence
Map<String, Object?>? _mergeData(
  Map<String, Object?> base,
  Map<String, Object?>? override,
) {
  if (base.isEmpty && override == null) return null;
  if (base.isEmpty) return override;
  if (override == null || override.isEmpty) return base.isEmpty ? null : base;
  return {...base, ...override};
}

/// Main logger class
class ChirpLogger {
  /// Optional name for this logger (required for explicit instances)
  final String? name;

  final Object? instance;

  /// The writers used by this logger
  final List<ChirpMessageWriter> writers;

  /// Contextual data attached to all logs from this logger
  ///
  /// This is useful for per-request or per-transaction loggers where
  /// you want to attach common context like requestId, userId, etc.
  ///
  /// This map is mutable and can be modified directly:
  /// ```dart
  /// final logger = Chirp(name: 'API', context: {'requestId': 'REQ-123'});
  ///
  /// // Add context as it becomes available
  /// logger.context['userId'] = 'user_456';
  /// logger.context['endpoint'] = '/api/users';
  ///
  /// // Remove context when no longer needed
  /// logger.context.remove('userId');
  /// ```
  final Map<String, Object?> context;

  /// Create a custom logger instance
  ChirpLogger({
    this.name,
    this.instance,
    List<ChirpMessageWriter>? writers,
    Map<String, Object?>? context,
  })  : writers = List.unmodifiable(writers ?? [ConsoleChirpMessageWriter()]),
        context = context ?? {};

  /// Log a message
  ///
  /// When called from the extension, instance is provided automatically.
  /// When called directly on a named logger, uses the logger's name.
  void log(
    Object? message, {
    ChirpLogLevel level = ChirpLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
    );

    _logRecord(entry);
  }

  /// Log a trace message
  void trace(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
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
    );

    _logRecord(entry);
  }

  /// Log a debug message
  void debug(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
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
    );

    _logRecord(entry);
  }

  /// Log an info message
  void info(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final caller = StackTrace.current;

    final entry = LogRecord(
      message: message,
      level: ChirpLogLevel.info,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      date: clock.now(),
      loggerName: name,
      instance: instance,
      data: _mergeData(context, data),
    );

    _logRecord(entry);
  }

  /// Log a warning message
  void warning(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
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
    );

    _logRecord(entry);
  }

  /// Log an error message
  void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
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
    );

    _logRecord(entry);
  }

  /// Log a critical message
  void critical(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
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
    );

    _logRecord(entry);
  }

  /// Log a WTF (What a Terrible Failure) message - for impossible situations
  void wtf(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
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
    );

    _logRecord(entry);
  }

  void _logRecord(LogRecord record) {
    for (final writer in writers) {
      writer.write(record);
    }
  }

  /// Create a new logger with additional context
  ///
  /// This creates a new logger instance with merged context,
  /// useful for creating per-request or per-transaction loggers:
  /// ```dart
  /// final requestLogger = Chirp.root.withContext({
  ///   'requestId': 'REQ-123',
  ///   'userId': 'user_456',
  /// });
  ///
  /// // All logs from requestLogger will include requestId and userId
  /// requestLogger.info('Processing request');
  /// ```
  ///
  /// Context from this logger will be merged with the new context,
  /// with new context taking precedence.
  ChirpLogger withContext(Map<String, Object?> additionalContext) {
    final merged = {...context, ...additionalContext};
    return ChirpLogger(
      name: name,
      writers: writers,
      context: merged,
    );
  }

  static final Expando<ChirpLogger> _instanceCache = Expando();

  factory ChirpLogger.forInstance(Object object) {
    return _instanceCache[object] ??= ChirpLogger(
      instance: object,
      writers: Chirp.root.writers,
    );
  }
}

/// Extension for logging from any object with instance tracking
///
/// This extension provides automatic instance tracking via identity hash codes,
/// allowing you to distinguish between different instances of the same class.
///
/// Example:
/// ```dart
/// class UserService {
///   void process() {
///     chirp('Processing...');  // Includes instance hash
///   }
/// }
///
/// final service1 = UserService();
/// final service2 = UserService();
/// service1.chirp('From service 1');  // Different hash
/// service2.chirp('From service 2');  // Different hash
/// ```
extension ChirpObjectExt<T extends Object> on T {
  ChirpLogger get chirp => ChirpLogger.forInstance(this);
}
