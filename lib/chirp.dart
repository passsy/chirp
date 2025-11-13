import 'package:chirp/src/format_option.dart';
import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/log_level.dart';
import 'package:chirp/src/message_writer.dart';
import 'package:clock/clock.dart';

export 'src/format_option.dart';
export 'src/log_entry.dart';
export 'src/log_level.dart';
export 'src/message_formatter.dart';
export 'src/message_writer.dart';
export 'src/rainbow_message_formatter.dart';

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

  /// Parent logger for delegation (child loggers inherit parent's writers)
  final ChirpLogger? parent;

  /// Writers owned by this logger (only root loggers have their own writers)
  final List<ChirpMessageWriter>? _ownWriters;

  /// Get the writers for this logger (delegates to parent if this is a child)
  List<ChirpMessageWriter> get writers {
    final p = parent;
    if (p != null) {
      return p.writers;
    }
    return _ownWriters ?? [ConsoleChirpMessageWriter()];
  }

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
    this.parent,
    List<ChirpMessageWriter>? writers,
    Map<String, Object?>? context,
  })  : _ownWriters = parent == null
            ? (writers != null ? List.unmodifiable(writers) : null)
            : null,
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
    List<FormatOptions>? formatOptions,
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
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Log a trace message
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

  /// Log a debug message
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

  /// Log an info message
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

  /// Log a notice message
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

  /// Log a warning message
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

  /// Log an error message
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

  /// Log a critical message
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

  /// Log a WTF (What a Terrible Failure) message - for impossible situations
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

  void _logRecord(LogRecord record) {
    for (final writer in writers) {
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
    return ChirpLogger(
      name: name ?? this.name,
      instance: instance ?? this.instance,
      parent: this,
      context: context != null ? {...this.context, ...context} : this.context,
    );
  }

  static final Expando<ChirpLogger> _instanceCache = Expando();

  factory ChirpLogger.forInstance(Object object) {
    return _instanceCache[object] ??= Chirp.root.child(instance: object);
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
