class LogEntry {
  /// The log message
  final Object? message;

  /// When this log was created
  final DateTime date;

  /// Optional error/exception
  final Object? error;

  /// Optional stack trace
  final StackTrace? stackTrace;

  /// Resolved class name (after transformers)
  final String? className;

  /// Instance identity hash code
  final int? instanceHash;

  /// Original instance that logged this
  final Object? instance;

  /// Logger name (for named loggers)
  final String? loggerName;

  const LogEntry({
    required this.message,
    required this.date,
    this.error,
    this.stackTrace,
    this.className,
    this.instanceHash,
    this.instance,
    this.loggerName,
  });
}
