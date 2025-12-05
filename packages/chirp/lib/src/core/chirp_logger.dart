import 'dart:async';
import 'dart:collection';

import 'package:chirp/src/core/chirp_interceptor.dart';
import 'package:chirp/src/core/chirp_writer.dart';
import 'package:chirp/src/core/format_option.dart';
import 'package:chirp/src/core/log_level.dart';
import 'package:chirp/src/core/log_record.dart';
import 'package:clock/clock.dart';

/// Flexible logger class supporting named loggers, child loggers, and custom writers.
///
/// [ChirpLogger] provides instance methods for logging at different severity
/// levels. It supports:
/// - Named loggers for different subsystems
/// - Child loggers with inherited configuration
/// - Contextual data that persists across log calls
/// - Custom writers for different output destinations
///
/// ## For Library Authors
///
/// Create a named logger for your library:
///
/// ```dart
/// // In your library's main file
/// final logger = ChirpLogger(name: 'my_library');
///
/// // Use throughout your library
/// logger.info('Something happened');
/// logger.error('Failed', error: e, stackTrace: stackTrace);
/// ```
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
/// ## Child Loggers (Winston-style)
///
/// Create child loggers that inherit parent configuration and context:
///
/// ```dart
/// final requestLogger = logger.child(context: {
///   'requestId': 'REQ-123',
///   'userId': 'user_456',
/// });
///
/// requestLogger.info('Request started'); // Includes requestId and userId
/// ```
///
/// ## Adopting Library Loggers
///
/// Integrate library loggers into your app's logging hierarchy:
///
/// ```dart
/// // Library exposes its logger (silent by default)
/// final httpLogger = ChirpLogger(name: 'http_client');
///
/// // App adopts the library logger to see its output
/// Chirp.root.adopt(httpLogger);
///
/// // Now library logs appear through the app's writers
/// httpLogger.info('Request sent'); // Visible in console!
/// ```
///
/// See also:
/// - [ChirpLogLevel] for available severity levels
/// - [ChirpWriter] for implementing custom writers
class ChirpLogger {
  /// Creates a logger instance.
  ///
  /// Parameters:
  /// - [name]: Optional name for the logger (e.g., 'http', 'database')
  /// - [instance]: Optional object instance for instance-specific logging
  /// - [context]: Optional initial context data included in all log entries
  ChirpLogger({
    this.name,
    this.instance,
    ChirpLogger? parent,
    Map<String, Object?>? context,
  })  : _parent = parent,
        context = context ?? {};

  /// Optional name for this logger.
  final String? name;

  /// Optional instance reference for object-specific logging.
  final Object? instance;

  /// Parent logger for writer inheritance.
  ///
  /// Set either via [child] (for child loggers) or [adopt] (for adopted loggers).
  ChirpLogger? _parent;

  /// The parent logger if this logger was created via [child] or [adopt].
  ChirpLogger? get parent => _parent;

  /// Cached flag indicating if any writer or interceptor requires caller info.
  bool _anyWriterRequiresCallerInfo = false;

  /// Backing field for [minLogLevel].
  ChirpLogLevel? _minLogLevel;

  /// Minimum log level for this logger.
  ///
  /// Logs below this level are rejected immediately without creating a
  /// LogRecord, avoiding the expensive `StackTrace.current` capture.
  ///
  /// Default is `null` (no filtering - accept all logs, including custom
  /// levels with negative severity).
  ///
  /// Use [setMinLogLevel] to change this value.
  ChirpLogLevel? get minLogLevel => _minLogLevel;

  /// Sets the minimum log level and returns this logger for chaining.
  ///
  /// Pass `null` to reset to no filtering (accept all levels).
  ///
  /// This is commonly used to:
  /// - Configure library loggers with a default minimum level
  /// - Enable verbose logging for specific libraries when debugging
  ///
  /// Example:
  /// ```dart
  /// // Library author: set default minimum level
  /// final libraryLogger = ChirpLogger(name: 'http_client')
  ///   .setMinLogLevel(ChirpLogLevel.warning);
  /// libraryLogger.addConsoleWriter();
  ///
  /// // App developer: enable verbose logging for a library
  /// libraryLogger.setMinLogLevel(ChirpLogLevel.trace);
  ///
  /// // Reset to accept all (including custom negative severity levels)
  /// libraryLogger.setMinLogLevel(null);
  /// ```
  ChirpLogger setMinLogLevel(ChirpLogLevel? level) {
    _minLogLevel = level;
    return this;
  }

  /// Internal mutable list of interceptors for this logger.
  final List<ChirpInterceptor> _interceptors = [];

  /// Read-only view of interceptors owned by this logger.
  List<ChirpInterceptor> get interceptors =>
      UnmodifiableListView(_interceptors);

  /// Get effective interceptors for this logger (parent's + own).
  ///
  /// Unlike writers, interceptors from both parent and child are combined.
  /// Parent interceptors run first, then child interceptors.
  List<ChirpInterceptor> get _effectiveInterceptors {
    final p = parent;
    if (p == null) return _interceptors;
    final parentInterceptors = p._effectiveInterceptors;
    if (_interceptors.isEmpty) return parentInterceptors;
    if (parentInterceptors.isEmpty) return _interceptors;
    return [...parentInterceptors, ..._interceptors];
  }

  /// Adds an interceptor to this logger and returns this logger for chaining.
  ///
  /// Interceptors are applied to all log records before they are sent to writers.
  /// They can transform or reject records.
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'api')
  ///   .addInterceptor(RedactSecretsInterceptor())
  ///   .addWriter(consoleWriter);
  /// ```
  ChirpLogger addInterceptor(ChirpInterceptor interceptor) {
    _interceptors.add(interceptor);
    updateRequiresCallerInfo();
    return this;
  }

  /// Removes an interceptor from this logger.
  bool removeInterceptor(ChirpInterceptor interceptor) {
    final removed = _interceptors.remove(interceptor);
    if (removed) {
      updateRequiresCallerInfo();
    }
    return removed;
  }

  /// Internal mutable list of writers owned by this logger.
  final List<ChirpWriter> _writers = [];

  /// Read-only view of writers owned by this logger.
  List<ChirpWriter> get writers => UnmodifiableListView(_writers);

  /// Get effective writers for this logger.
  ///
  /// - Root/orphan loggers use their own writers
  /// - Child/adopted loggers use only parent's writers (own writers are ignored)
  ///
  /// This allows libraries to have default writers that get replaced when
  /// the logger is adopted by an app.
  List<ChirpWriter> get _effectiveWriters {
    final p = parent;
    if (p == null) return _writers;
    return p._effectiveWriters;
  }

  /// Adds a writer to this logger and returns this logger for chaining.
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'api')
  ///   .addWriter(consoleWriter)
  ///   .addWriter(fileWriter);
  /// ```
  ChirpLogger addWriter(ChirpWriter writer) {
    if (_writers.contains(writer)) return this;
    _writers.add(writer);
    writer.attachedLoggers.add(this);
    updateRequiresCallerInfo();
    return this;
  }

  /// Removes a writer from this logger.
  bool removeWriter(ChirpWriter writer) {
    final removed = _writers.remove(writer);
    if (removed) {
      writer.attachedLoggers.remove(this);
      updateRequiresCallerInfo();
    }
    return removed;
  }

  /// Whether any effective writer requires caller info.
  ///
  /// - Root/orphan loggers check their own writers
  /// - Child/adopted loggers check only parent (own writers are ignored)
  bool get _effectiveRequiresCallerInfo {
    final p = parent;
    if (p != null) {
      // Child/adopted loggers use only parent's writers, so only check parent
      return p._effectiveRequiresCallerInfo;
    }
    // Root/orphan loggers use their own writers
    return _anyWriterRequiresCallerInfo;
  }

  /// Contextual data automatically included in all log entries.
  final Map<String, Object?> context;

  /// Get effective context for this logger (parent's context + own context).
  ///
  /// Context is resolved at log time, so changes to parent context after
  /// child/adoption are visible.
  Map<String, Object?> get _effectiveContext {
    final p = parent;
    if (p == null) return context;
    final parentContext = p._effectiveContext;
    if (context.isEmpty) return parentContext;
    if (parentContext.isEmpty) return context;
    return {...parentContext, ...context};
  }

  /// Merges the given context into this logger's context and returns this
  /// logger for chaining.
  ///
  /// Values in [additionalContext] override existing values with the same key.
  /// Note that `null` is a valid value and does not remove the key.
  ///
  /// To remove entries, use the [context] map directly:
  /// ```dart
  /// logger.context.remove('requestId');
  /// logger.context.clear();
  /// ```
  ///
  /// Example:
  /// ```dart
  /// final logger = ChirpLogger(name: 'api')
  ///   .addContext({'env': 'prod'})
  ///   .addContext({'version': '1.0'});
  /// // logger.context now has both 'env' and 'version'
  /// ```
  ChirpLogger addContext(Map<String, Object?> additionalContext) {
    context.addAll(additionalContext);
    return this;
  }

  /// Create a child logger with optional name, instance, and/or context.
  ///
  /// The child logger inherits:
  /// - Parent's writers (via parent chain)
  /// - Parent's context (resolved at log time, not copied)
  /// - Parent's name and instance (by default, can be overridden)
  ///
  /// Context inheritance is dynamic - changes to parent's context after
  /// child creation will be visible when the child logs.
  ChirpLogger child({
    String? name,
    Object? instance,
    Map<String, Object?>? context,
  }) {
    return ChirpLogger(
      name: name ?? this.name,
      instance: instance ?? this.instance,
      parent: this,
      context: context,
    );
  }

  /// Adopts an orphan logger, making it inherit this logger's writers and context.
  ///
  /// After adoption:
  /// - The adopted logger's output goes through this logger's writers
  /// - The adopted logger inherits this logger's context (resolved at log time)
  /// - The adopted logger keeps its own name and instance
  /// - The adopted logger can still have its own additional writers and context
  ///
  /// This is useful for integrating library loggers into an app's logging
  /// hierarchy without requiring libraries to expose configuration APIs.
  ///
  /// Example:
  /// ```dart
  /// // Library defines its logger (silent by default)
  /// final httpLogger = ChirpLogger(name: 'http');
  ///
  /// // App adopts it to see the logs
  /// Chirp.root.adopt(httpLogger);
  ///
  /// // Library logs now appear through app's writers
  /// httpLogger.info('Request sent'); // Visible!
  /// ```
  ///
  /// Throws [StateError] if the logger already has a parent.
  ChirpLogger adopt(ChirpLogger orphan) {
    if (orphan._parent != null) {
      throw StateError(
        'Cannot adopt logger "${orphan.name}" - it already has a parent. '
        'A logger can only be adopted once.',
      );
    }
    orphan._parent = this;
    return this;
  }

  /// Removes the parent-child relationship, making this logger an orphan.
  ///
  /// After calling orphan:
  /// - The logger no longer inherits writers or context from its parent
  /// - The logger becomes silent unless it has its own writers
  /// - The logger can be adopted by a different parent
  ///
  /// This is useful for testing or reconfiguring logger hierarchies.
  ///
  /// Example:
  /// ```dart
  /// final parent = ChirpLogger(name: 'app').addConsoleWriter();
  /// final child = parent.child(name: 'module');
  ///
  /// child.info('visible'); // Goes through parent's writer
  ///
  /// child.orphan();
  /// child.info('silent'); // No writers, no output
  /// ```
  void orphan() {
    _parent = null;
  }

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
  /// logger.log('System alert', level: alert, data: {'severity': 'high'});
  ///
  /// // Dynamic level selection
  /// final level = isProduction ? ChirpLogLevel.error : ChirpLogLevel.debug;
  /// logger.log('Environment-specific message', level: level);
  /// ```
  ///
  /// See also:
  /// - [info], [warning], [error] and other convenience methods
  /// - [ChirpLogLevel] for standard log levels
  /// {@endtemplate}
  void log(
    Object? message, {
    ChirpLogLevel level = ChirpLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
    int? skipFrames,
  }) {
    // Early rejection based on minLogLevel - no LogRecord created
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    // Only capture caller if any writer needs it
    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      skipFrames: skipFrames,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void trace(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.trace;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void debug(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.debug;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void info(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.info;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      // ignore: avoid_redundant_argument_values
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void notice(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.notice;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void warning(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.warning;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.error;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void critical(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.critical;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
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
  void wtf(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    const level = ChirpLogLevel.wtf;
    final min = minLogLevel;
    if (min != null && level.severity < min.severity) return;

    final caller = _effectiveRequiresCallerInfo ? StackTrace.current : null;

    final entry = LogRecord(
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      caller: caller,
      timestamp: clock.now(),
      zone: Zone.current,
      loggerName: name,
      instance: instance,
      data: _mergeData(_effectiveContext, data),
      formatOptions: formatOptions,
    );

    _logRecord(entry);
  }

  /// Writes a log record to all configured writers.
  void _logRecord(LogRecord record) {
    LogRecord? r = record;

    // Apply logger interceptors first (before any writer sees the record)
    for (final interceptor in _effectiveInterceptors) {
      if (r == null) return; // Record rejected, skip all writers
      r = interceptor.intercept(r);
    }
    if (r == null) return;

    // Then dispatch to each writer
    for (final writer in _effectiveWriters) {
      // Check writer's minLogLevel
      final writerMinLevel = writer.minLogLevel;
      if (writerMinLevel != null &&
          r.level.severity < writerMinLevel.severity) {
        continue; // Skip this writer
      }

      LogRecord? wr = r;

      // Apply writer-specific interceptors
      for (final interceptor in writer.interceptors) {
        if (wr == null) break;
        wr = interceptor.intercept(wr);
      }

      if (wr != null) {
        writer.write(wr);
      }
    }
  }
}

/// Soft-private extension for package-internal use.
///
/// This extension is intentionally not exported from `chirp_protocol.dart`.
/// It provides internal APIs needed for cross-file communication within the
/// package (e.g., between [ChirpWriter] and [ChirpLogger]).
///
/// **Not part of the public API** - may change without notice.
///
/// Advanced users can access this by importing the src file directly,
/// but doing so is discouraged and unsupported. If you find yourself needing
/// these APIs, please open an issue - we'd like to understand your use case
/// and potentially expose a proper public API.
extension $PrivateChirpLogger on ChirpLogger {
  /// Recalculates whether any writer or interceptor requires caller info.
  void updateRequiresCallerInfo() {
    // Check logger's own interceptors
    for (final interceptor in _interceptors) {
      if (interceptor.requiresCallerInfo) {
        _anyWriterRequiresCallerInfo = true;
        return;
      }
    }
    // Check writers and their interceptors
    for (final writer in _writers) {
      if (writer.requiresCallerInfo) {
        _anyWriterRequiresCallerInfo = true;
        return;
      }
      for (final interceptor in writer.interceptors) {
        if (interceptor.requiresCallerInfo) {
          _anyWriterRequiresCallerInfo = true;
          return;
        }
      }
    }
    _anyWriterRequiresCallerInfo = false;
  }
}

/// Merges two data maps, with [override] values taking precedence over [base].
///
/// Returns `null` if both maps are empty. This optimization avoids creating
/// empty maps in log records when no data is present.
Map<String, Object?>? _mergeData(
  Map<String, Object?> base,
  Map<String, Object?>? override,
) {
  if (base.isEmpty && (override == null || override.isEmpty)) return null;
  if (base.isEmpty) return override;
  if (override == null || override.isEmpty) return base;
  return {...base, ...override};
}
