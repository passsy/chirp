import 'package:chirp/src/format_option.dart';
import 'package:chirp/src/log_level.dart';
import 'package:chirp/src/stack_trace_util.dart';

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
  final int skipFrames;

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
    this.skipFrames = 0,
    this.loggerName,
    this.data,
    this.formatOptions,
  });
}

extension LogEntryExt on LogRecord {
  int? get instanceHash {
    if (instance == null) return null;
    return identityHashCode(instance);
  }

  /// Extracts caller info from this record's stack trace
  StackFrameInfo? get callerInfo {
    if (caller == null) return null;
    return getCallerInfo(caller!, skipFrames: skipFrames);
  }

  /// Returns formatted time string like "HH:mm:ss.mmm"
  String get formattedTime {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$ms';
  }

  /// Returns a formatted instance identifier like "ClassName@a1b2"
  ///
  /// Uses [resolveClassName] to get the class name if provided,
  /// otherwise falls back to runtimeType.
  String? instanceLabel([String Function(Object)? resolveClassName]) {
    if (instance == null) return null;
    final className =
        resolveClassName?.call(instance!) ?? instance.runtimeType.toString();
    final hash = instanceHash ?? 0;
    final hashHex = hash.toRadixString(16).padLeft(4, '0');
    final shortHash =
        hashHex.substring(hashHex.length >= 4 ? hashHex.length - 4 : 0);
    return '$className@$shortHash';
  }
}
