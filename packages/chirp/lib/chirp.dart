import 'package:chirp/src/console_writer.dart';
import 'package:chirp/src/formatters/rainbow_message_formatter.dart';
import 'package:chirp/src/stack_trace_util.dart';
import 'package:chirp_protocol/chirp_protocol.dart';

// Export implementation-specific files
export 'package:chirp/src/console_writer.dart';
export 'package:chirp/src/formatters/compact_message_formatter.dart';
export 'package:chirp/src/formatters/json_message_formatter.dart';
export 'package:chirp/src/formatters/rainbow_message_formatter.dart';
export 'package:chirp/src/formatters/simple_console_message_formatter.dart';
export 'package:chirp/src/stack_trace_util.dart';
export 'package:chirp/src/xterm_colors.g.dart';
// Re-export everything from chirp_protocol
export 'package:chirp_protocol/chirp_protocol.dart';

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
  ///
  /// ## Examples
  /// ```dart
  /// // Default setup with colors (auto-detected)
  /// final logger = ChirpLogger(name: 'API')
  ///   ..addConsoleWriter();
  ///
  /// // Force colors off (useful for file output or CI logs)
  /// final noColorLogger = ChirpLogger(name: 'CI')
  ///   ..addConsoleWriter(useColors: false);
  ///
  /// // Force colors on (useful when piping to a terminal that supports colors)
  /// final colorLogger = ChirpLogger(name: 'Term')
  ///   ..addConsoleWriter(useColors: true);
  ///
  /// // JSON format for structured logging
  /// final jsonLogger = ChirpLogger(name: 'JSON')
  ///   ..addConsoleWriter(formatter: JsonMessageFormatter());
  ///
  /// // Capture output for testing
  /// final messages = <String>[];
  /// final testLogger = ChirpLogger(name: 'Test')
  ///   ..addConsoleWriter(output: messages.add);
  ///
  /// // Use both writers for maximum compatibility
  /// final logger = ChirpLogger()
  ///   ..addConsoleWriter()  // Always works, visible in logcat
  ///   ..addWriter(DeveloperLogConsoleWriter());  // Unlimited when debugger attached
  /// ```
  ///
  /// See also:
  /// - [PrintConsoleWriter] for more configuration (throttling, chunk size)
  /// - [DeveloperLogConsoleWriter] for unlimited length via `developer.log()`
  /// - [addWriter] for adding any custom [ChirpWriter]
  void addConsoleWriter({
    ConsoleMessageFormatter? formatter,
    void Function(String)? output,
    bool? useColors,
  }) {
    addWriter(
      PrintConsoleWriter(
        formatter: formatter ?? RainbowMessageFormatter(),
        output: output,
        useColors: useColors,
      ),
    );
  }
}

/// Extension on [LogRecord] to add formatting helpers.
///
/// These helpers depend on [stack_trace_util.dart] which is implementation
/// code in chirp, not part of chirp_protocol.
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
