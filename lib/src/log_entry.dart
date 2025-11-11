/// Log severity levels compatible with Google Cloud Logging
// TODO don't use an enum, make it extensible. labels?
enum LogLevel {
  /// Debug or trace information
  debug(100),

  /// Routine information, such as ongoing status or performance
  info(200),

  /// Warning events might cause problems
  warning(400),

  /// Error events are likely to cause problems
  error(500),

  /// Critical events cause severe problems or system failures
  critical(600);

  const LogLevel(this.severity);

  /// Numeric severity for sorting and filtering
  final int severity;

  /// GCP-compatible severity name
  String get gcpSeverity {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRITICAL';
    }
  }
}

class LogRecord {
  /// The log message
  final Object? message;

  /// When this log was created
  final DateTime date;

  /// Log severity level
  final LogLevel level;

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
    this.level = LogLevel.info,
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
