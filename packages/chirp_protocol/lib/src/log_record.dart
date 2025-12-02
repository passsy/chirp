import 'package:chirp_protocol/src/format_option.dart';
import 'package:chirp_protocol/src/log_level.dart';

/// A single log entry containing the message and associated metadata.
///
/// LogRecord is an immutable snapshot of a log event. It captures:
/// - The log [message] and [level]
/// - When the log was created ([date])
/// - Optional [error] and [stackTrace] for error logging
/// - The [instance] that created the log (for instance tracking)
/// - The [caller] stack trace (for source location)
/// - Structured [data] for machine-readable logging
/// - Per-log [formatOptions] to override formatter defaults
///
/// ## Example
///
/// ```dart
/// final record = LogRecord(
///   message: 'User logged in',
///   date: DateTime.now(),
///   level: ChirpLogLevel.info,
///   data: {'userId': '123', 'method': 'oauth'},
/// );
/// ```
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

  /// Number of stack frames to skip when resolving caller info
  final int? skipFrames;

  /// Original instance that logged this
  final Object? instance;

  /// Logger name (for named loggers)
  final String? loggerName;

  /// Structured data (key-value pairs) for machine-readable logging
  final Map<String, Object?>? data;

  /// Format options for this specific log entry
  ///
  /// These options override the formatter's default options.
  /// Each formatter interprets options specific to its implementation.
  final List<FormatOptions>? formatOptions;

  const LogRecord({
    required this.message,
    required this.date,
    this.level = ChirpLogLevel.info,
    this.error,
    this.stackTrace,
    this.instance,
    this.caller,
    this.skipFrames,
    this.loggerName,
    this.data,
    this.formatOptions,
  });
}
