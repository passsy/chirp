import 'dart:async';

/// @docImport 'package:chirp/chirp.dart';
import 'package:chirp/src/core/format_option.dart';
import 'package:chirp/src/core/log_level.dart';

/// Sentinel value to distinguish between "not provided" and "explicitly null".
const Object _undefined = _Undefined();

class _Undefined {
  const _Undefined();
}

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

  /// When this log was created (from injectable [clock]).
  ///
  /// This timestamp comes from the `clock` package which can be mocked in tests.
  /// Use [wallClock] when you need the actual system time regardless of mocking.
  final DateTime timestamp;

  /// The actual wall-clock time when this log was created.
  ///
  /// Unlike [timestamp] (which uses the injectable `clock` and can be mocked),
  /// this always captures `DateTime.now()` - the real system time.
  ///
  /// Useful for:
  /// - Production logs where you need accurate real-world timestamps
  /// - Correlating logs with external systems that use wall-clock time
  /// - Debugging timing issues while tests use mocked time for [timestamp]
  final DateTime wallClock;

  /// Log severity level
  final ChirpLogLevel level;

  /// Optional error/exception
  final Object? error;

  /// Optional stack trace
  final StackTrace? stackTrace;

  /// The stacktrace of the log method call
  ///
  /// This is typically `null` and only populated if one of those fields are set
  /// to `true`:
  /// - [ChirpInterceptor.requiresCallerInfo]
  /// - [ChirpWriter.requiresCallerInfo]
  /// - [ConsoleMessageFormatter.requiresCallerInfo]
  final StackTrace? caller;

  /// Number of stack frames to skip when resolving caller info
  final int? skipFrames;

  /// Original instance that logged this
  final Object? instance;

  /// Logger name (for named loggers)
  final String? loggerName;

  /// Structured data (key-value pairs) for machine-readable logging
  final Map<String, Object?> data;

  /// Format options for this specific log entry
  ///
  /// These options override the formatter's default options.
  /// Each formatter interprets options specific to its implementation.
  final List<FormatOptions>? formatOptions;

  /// The Zone that was active when this log was created.
  ///
  /// Useful for accessing zone values (e.g., request ID, user ID) that were
  /// set in the calling context. This is always captured because `Zone.current`
  /// is essentially free (just a pointer lookup).
  final Zone zone;

  /// Creates a log record.
  ///
  /// Typically you don't create these directly - use [ChirpLogger] methods
  /// like `Chirp.info()` instead.
  LogRecord({
    required this.message,
    required this.timestamp,
    required this.wallClock,
    Zone? zone,
    this.level = ChirpLogLevel.info,
    this.error,
    this.stackTrace,
    this.instance,
    this.caller,
    this.skipFrames,
    this.loggerName,
    Map<String, Object?>? data,
    this.formatOptions,
  })  : data = data ?? {},
        zone = zone ?? Zone.current;

  /// Creates a copy of this [LogRecord] with the given fields replaced.
  ///
  /// Use this method to create a new [LogRecord] with some properties changed
  /// while keeping the rest unchanged.
  ///
  /// For nullable fields (like [error], [stackTrace], [loggerName], etc.),
  /// you can explicitly set them to `null` and the copy will have `null`
  /// for those fields. Simply not providing a parameter keeps the original
  /// value.
  ///
  /// Example:
  /// ```dart
  /// final original = LogRecord(
  ///   message: 'Hello',
  ///   timestamp: DateTime.now(),
  ///   loggerName: 'MyLogger',
  /// );
  ///
  /// // Change just the message
  /// final updated = original.copyWith(message: 'Goodbye');
  ///
  /// // Explicitly set loggerName to null
  /// final noLogger = original.copyWith(loggerName: null);
  /// ```
  LogRecord Function({
    Object? message,
    DateTime? timestamp,
    DateTime? wallClock,
    Zone? zone,
    ChirpLogLevel? level,
    Object? error,
    StackTrace? stackTrace,
    Object? instance,
    StackTrace? caller,
    int? skipFrames,
    String? loggerName,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) get copyWith => _copyWithImpl;

  LogRecord _copyWithImpl({
    Object? message = _undefined,
    DateTime? timestamp,
    DateTime? wallClock,
    Zone? zone,
    ChirpLogLevel? level,
    Object? error = _undefined,
    Object? stackTrace = _undefined,
    Object? instance = _undefined,
    Object? caller = _undefined,
    Object? skipFrames = _undefined,
    Object? loggerName = _undefined,
    Object? data = _undefined,
    Object? formatOptions = _undefined,
  }) {
    return LogRecord(
      message: identical(message, _undefined) ? this.message : message,
      timestamp: timestamp ?? this.timestamp,
      wallClock: wallClock ?? this.wallClock,
      zone: zone ?? this.zone,
      level: level ?? this.level,
      error: identical(error, _undefined) ? this.error : error,
      stackTrace: identical(stackTrace, _undefined)
          ? this.stackTrace
          : stackTrace as StackTrace?,
      instance: identical(instance, _undefined) ? this.instance : instance,
      caller:
          identical(caller, _undefined) ? this.caller : caller as StackTrace?,
      skipFrames: identical(skipFrames, _undefined)
          ? this.skipFrames
          : skipFrames as int?,
      loggerName: identical(loggerName, _undefined)
          ? this.loggerName
          : loggerName as String?,
      data: identical(data, _undefined)
          ? this.data
          : data as Map<String, Object?>?,
      formatOptions: identical(formatOptions, _undefined)
          ? this.formatOptions
          : formatOptions as List<FormatOptions>?,
    );
  }
}
