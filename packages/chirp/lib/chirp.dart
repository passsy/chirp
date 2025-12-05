import 'package:chirp/src/console_writer.dart';
import 'package:chirp/src/formatters/rainbow_message_formatter.dart';
import 'package:chirp/src/stack_trace_util.dart';
import 'package:chirp_protocol/chirp_protocol.dart';

export 'package:chirp/src/console_writer.dart';
export 'package:chirp/src/developer_log_console_writer.dart';
export 'package:chirp/src/formatters/compact_message_formatter.dart';
export 'package:chirp/src/formatters/json_message_formatter.dart';
export 'package:chirp/src/formatters/rainbow_message_formatter.dart';
export 'package:chirp/src/formatters/simple_console_message_formatter.dart';
export 'package:chirp/src/stack_trace_util.dart';
export 'package:chirp/src/xterm_colors.g.dart';
// Re-export everything from chirp_protocol
export 'package:chirp_protocol/chirp_protocol.dart';

// ignore: avoid_classes_with_only_static_members
/// Global static logger with pre-configured console output.
///
/// This class provides static logging methods that work out of the box.
/// Logs will print to console automatically without any configuration.
///
/// For silent logging (library use), depend on `chirp_protocol` instead.
///
/// ## Default Behavior
///
/// By default, [Chirp.root] is `null` and all logging goes through an internal
/// default logger with console output. This means `Chirp.info("hello")` works
/// immediately.
///
/// ## Customizing the Root Logger
///
/// To customize logging behavior, **replace** [Chirp.root] entirely:
///
/// ```dart
/// // In your app initialization or test setUp:
/// Chirp.root = ChirpLogger()
///   .addConsoleWriter(formatter: JsonMessageFormatter())
///   .setMinLogLevel(ChirpLogLevel.warning);
/// ```
///
/// **Important:** Do NOT call `Chirp.root.addWriter(...)` - this will fail with
/// a null error by design. Always replace the root logger instead. This prevents
/// accidental writer accumulation in test setUp() code.
class Chirp {
  static ChirpLogger? _root;

  /// The custom root logger.
  ///
  /// Throws [StateError] if accessed before being set via `Chirp.root = ...`.
  /// This is intentional - it prevents the common mistake of calling
  /// `Chirp.root.addWriter(...)` in test setUp() code, which would
  /// accumulate writers across tests.
  ///
  /// To customize logging, always **replace** the root:
  ///
  /// ```dart
  /// // Correct - replaces the logger each time
  /// Chirp.root = ChirpLogger().addConsoleWriter(output: messages.add);
  ///
  /// // Wrong - throws StateError (by design)
  /// Chirp.root.addWriter(myWriter); // StateError: Chirp.root not set
  /// ```
  ///
  /// Static methods like [Chirp.info] and the `.chirp` extension work
  /// regardless of whether root is set - they fall back to an internal
  /// default logger with console output.
  static ChirpLogger get root {
    if (_root == null) {
      throw StateError(
        'Chirp.root has not been set. '
        'Use "Chirp.root = ChirpLogger().addConsoleWriter(...)" to configure it. '
        'For logging without setup, use Chirp.info() or Chirp.log() directly.',
      );
    }
    return _root!;
  }

  /// Sets the custom root logger.
  ///
  /// Set to `null` to revert to the default logger behavior.
  static set root(ChirpLogger? value) => _root = value;

  /// {@macro chirp.log}
  static void log(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    ChirpLogLevel level = ChirpLogLevel.info,
    List<FormatOptions>? formatOptions,
    int? skipFrames,
  }) {
    _effectiveRootLogger.log(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
      skipFrames: skipFrames,
    );
  }

  /// {@macro chirp.trace}
  static void trace(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.trace(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.debug}
  static void debug(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.debug(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.info}
  static void info(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.info(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.notice}
  static void notice(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.notice(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.warning}
  static void warning(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.warning(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.error}
  static void error(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.error(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.critical}
  static void critical(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.critical(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }

  /// {@macro chirp.wtf}
  static void wtf(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _effectiveRootLogger.wtf(
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
      formatOptions: formatOptions,
    );
  }
}

/// Extension on [ChirpLogger] to add convenience methods for console writers.
///
/// This extension adds the [addConsoleWriter] method that requires implementation
/// classes from chirp (not available in chirp_protocol).
extension ChirpLoggerConsoleWriterExt on ChirpLogger {
  /// Adds a [PrintConsoleWriter] - logs via `print()` to logcat/os_log.
  ///
  /// This is the most common writer for mobile development. Logs are visible
  /// in `adb logcat`, Xcode console, and `flutter logs`.
  ///
  /// **Platform limits (auto-chunked):**
  /// - Android: 1024 chars (NDK's `LOG_BUF_SIZE` in `__android_log_print`)
  /// - iOS: ~1024 bytes (os_log limit)
  ///
  /// **For unlimited length**, use [DeveloperLogConsoleWriter] instead:
  /// ```dart
  /// logger.addWriter(DeveloperLogConsoleWriter(name: 'myapp'));
  /// ```
  /// Note: `developer.log()` requires debugger attachment and won't show
  /// in `adb logcat` - only in Flutter DevTools and IDE debug consoles.
  ///
  /// ## Parameters
  /// - [formatter]: How to format log records (default: [RainbowMessageFormatter])
  /// - [output]: Custom output function (default: `print()`)
  /// - [useColors]: Whether to emit ANSI color escape codes in the output.
  ///   When `true`, log levels, timestamps, and other elements are colorized.
  ///   When `false`, plain text is output without escape codes.
  ///   Default: `null` (uses [platformSupportsAnsiColors] - `true` for Flutter,
  ///   checks `stdout.supportsAnsiEscapes` for pure Dart, `false` for web).
  /// - [minLogLevel]: Minimum log level for this writer. Records below this
  ///   level are skipped. Default: `null` (accepts all levels).
  /// - [interceptors]: List of interceptors to transform/filter records.
  ///
  /// ## Examples
  /// ```dart
  /// // Default setup with colors (auto-detected)
  /// final logger = ChirpLogger(name: 'API')
  ///   .addConsoleWriter();
  ///
  /// // Chaining multiple configuration calls
  /// final prodLogger = ChirpLogger(name: 'Prod')
  ///   .addConsoleWriter(minLogLevel: ChirpLogLevel.warning)
  ///   .setMinLogLevel(ChirpLogLevel.info);
  ///
  /// // JSON format for structured logging
  /// final jsonLogger = ChirpLogger(name: 'JSON')
  ///   .addConsoleWriter(formatter: JsonMessageFormatter());
  ///
  /// // Capture output for testing
  /// final messages = <String>[];
  /// final testLogger = ChirpLogger(name: 'Test')
  ///   .addConsoleWriter(output: messages.add);
  ///
  /// // Use both writers for maximum compatibility
  /// final logger = ChirpLogger()
  ///   .addConsoleWriter()  // Always works, visible in logcat
  ///   .addWriter(DeveloperLogConsoleWriter());  // Unlimited when debugger attached
  /// ```
  ///
  /// ## Why this returns `ChirpLogger` instead of the writer
  ///
  /// This method returns `this` to enable fluent chaining. If you need a
  /// reference to the writer (e.g., to remove it later), create it directly:
  ///
  /// ```dart
  /// final writer = PrintConsoleWriter(formatter: JsonMessageFormatter());
  /// logger.addWriter(writer);
  /// // Later: logger.removeWriter(writer);
  /// ```
  ///
  /// See also:
  /// - [PrintConsoleWriter] for creating writers with full control
  /// - [DeveloperLogConsoleWriter] for unlimited length via `developer.log()`
  /// - [addWriter] for adding any custom [ChirpWriter]
  ChirpLogger addConsoleWriter({
    ConsoleMessageFormatter? formatter,
    void Function(String)? output,
    bool? useColors,
    ChirpLogLevel? minLogLevel,
    List<ChirpInterceptor>? interceptors,
  }) {
    final writer = PrintConsoleWriter(
      formatter: formatter ?? RainbowMessageFormatter(),
      output: output,
      useColors: useColors,
    );
    if (minLogLevel != null) {
      writer.setMinLogLevel(minLogLevel);
    }
    if (interceptors != null) {
      for (final interceptor in interceptors) {
        writer.addInterceptor(interceptor);
      }
    }
    addWriter(writer);
    return this;
  }
}

/// Default Root logger of chirp
///
/// Just a special name for the instance to make debugging easier
class _RootLogger extends ChirpLogger {}

/// Default logger with console output, used when [Chirp.root] is not set.
/// Lazily initialized on first access (Dart initializes top-level fields lazily).
final ChirpLogger _defaultRootLogger = _RootLogger().addConsoleWriter();

/// Internal getter for the effective logger used by static methods and extensions.
ChirpLogger get _effectiveRootLogger => Chirp._root ?? _defaultRootLogger;

/// Cache for instance loggers to ensure the same instance always gets the same logger.
final Expando<ChirpLogger> _instanceLoggerCache = Expando('chirp');

/// Extension that provides a `.chirp` getter on any object for instance-specific logging.
///
/// This extension creates child loggers from [Chirp.root] that are associated with
/// specific object instances. The logger is cached using an [Expando], so
/// calling `.chirp` multiple times on the same instance returns the same logger.
///
/// ## Usage
///
/// ```dart
/// class UserService {
///   void fetchUser(String id) {
///     chirp.info('Fetching user', data: {'userId': id});
///   }
/// }
///
/// final service1 = UserService();
/// final service2 = UserService();
///
/// // Different instances get different loggers with unique instance IDs
/// service1.chirp.info('From service 1'); // Shows UserService@a1b2
/// service2.chirp.info('From service 2'); // Shows UserService@c3d4
/// ```
///
/// The logger includes the instance reference, allowing formatters to display
/// which specific object instance produced each log entry.
///
/// ## Note for Library Authors
///
/// If you're writing a library that depends on `chirp_protocol` (to stay silent
/// by default), create your own logger instead:
///
/// ```dart
/// final logger = ChirpLogger(name: 'my_library');
/// ```
///
/// The `.chirp` extension is designed for application code where you want
/// automatic console output through [Chirp.root].
extension ChirpObjectExt on Object {
  /// Returns a cached logger for this specific object instance.
  ///
  /// The logger is a child of the effective root logger (either [Chirp.root]
  /// if set, or the internal default logger) with this instance attached,
  /// enabling formatters to show instance-specific identifiers.
  ChirpLogger get chirp {
    var logger = _instanceLoggerCache[this];
    if (logger == null) {
      logger = _effectiveRootLogger.child(instance: this);
      _instanceLoggerCache[this] = logger;
    }
    return logger;
  }
}

/// Extension on [LogRecord] to add formatting helpers.
///
/// These helpers depend on [stack_trace_util.dart] which is implementation
/// code in chirp, not part of chirp_
extension LogRecordExt on LogRecord {
  /// Returns the identity hash code of the instance, if present.
  int? get instanceHash {
    if (instance == null) return null;
    return identityHashCode(instance);
  }

  /// Extracts caller info from this record's stack trace
  StackFrameInfo? get callerInfo {
    if (caller == null) return null;
    return getCallerInfo(caller!, skipFrames: skipFrames ?? 0);
  }

  /// Returns formatted time string like "HH:mm:ss.mmm"
  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
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
