import 'package:chirp/src/log_level.dart';

class LogRecord {
  /// The log message
  final Object? message;

  /// When this log was created
  final DateTime date;

  /// Log severity level
  final ChirpLogLevel level;

  /// Optional error/exception
  final Object? error;

  /// Optional stack trace
  final StackTrace? stackTrace;

  /// The stacktrace of the log method call
  final StackTrace? caller;

  /// Resolved class name (after transformers)
  final String? className;

  /// Original instance that logged this
  final Object? instance;

  /// Logger name (for named loggers)
  final String? loggerName;

  /// Structured data (key-value pairs) for machine-readable logging
  final Map<String, Object?>? data;

  const LogRecord({
    required this.message,
    required this.date,
    this.level = ChirpLogLevel.info,
    this.error,
    this.stackTrace,
    this.className,
    this.instance,
    this.caller,
    this.loggerName,
    this.data,
  });
}

extension LogEntryExt on LogRecord {
  int? get instanceHash {
    if (instance == null) return null;
    return identityHashCode(instance);
  }
}
