import 'package:chirp_protocol/src/chirp_logger.dart';
import 'package:chirp_protocol/src/chirp_writer.dart';
import 'package:chirp_protocol/src/format_option.dart';
import 'package:chirp_protocol/src/log_level.dart';

/// An immutable snapshot of a log event passed to [ChirpWriter]s.
///
/// You typically don't create LogRecords directly. They are created by
/// [ChirpLogger] when you call logging methods like `Chirp.info()`.
///
/// LogRecord is primarily consumed when implementing custom [ChirpWriter]s
/// or formatters that need to access the full log context.
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
