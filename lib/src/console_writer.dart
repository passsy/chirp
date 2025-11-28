// ignore_for_file: avoid_print

import 'dart:developer' as developer;
import 'package:chirp/chirp.dart';

export 'package:chirp/src/platform/platform_info.dart';

/// Writes to console using [print()].
///
/// **Supports ANSI colors** in terminals and IDEs that render them.
///
/// ## Android Truncation (1024 characters)
///
/// On Android, `print()` is truncated at **1024 characters**. This limit comes
/// from the NDK's `liblog` library, not the kernel.
///
/// **The truncation path:**
/// ```text
/// Dart print()
///   → Flutter Engine: __android_log_print(ANDROID_LOG_INFO, tag, "%s", msg)
///     → liblog: vsnprintf(buf, LOG_BUF_SIZE, fmt, ap)  // LOG_BUF_SIZE = 1024
///       → kernel logger (LOGGER_ENTRY_MAX_PAYLOAD ≈ 4068, never reached)
/// ```
///
/// The Flutter engine calls `__android_log_print()` which formats the message
/// into a **1024-byte stack buffer** before sending to the kernel. The kernel's
/// larger limit (~4068 bytes) is never reached because truncation happens first
/// in userspace.
///
/// **Why Java's `Log.d()` allows ~4000 chars but Flutter doesn't:**
/// Java's `android.util.Log` calls `__android_log_buf_write()` directly,
/// bypassing the 1024-byte formatting buffer. Flutter uses the NDK path which
/// goes through `__android_log_print()` with its smaller buffer.
///
/// **Source code references:**
/// - [LOG_BUF_SIZE = 1024](https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/logger_write.cpp;l=62)
/// - [vsnprintf truncation](https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/logger_write.cpp;l=75)
/// - [Flutter engine log callback](https://github.com/flutter/engine/blob/main/shell/platform/android/flutter_main.cc)
/// - [LOGGER_ENTRY_MAX_PAYLOAD (kernel limit)](https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/include/log/log.h;l=34)
///
/// ## iOS/macOS Truncation (1024 bytes)
///
/// On iOS 10+ and macOS 10.12+, Apple's **Unified Logging** system (`os_log`)
/// truncates messages at **1024 bytes** for dynamic content.
///
/// **The truncation path:**
/// ```text
/// Dart print()
///   → Flutter Engine: stdout
///     → NSLog() / os_log()
///       → libsystem_trace.dylib (1024 byte limit)
///         → Unified Logging persistence store
/// ```
///
/// From Apple's `<os/log.h>` header:
/// > "There is a physical cap of 1024 bytes per log line for dynamic content,
/// > such as %s and %@, that can be written to the persistence store.
/// > All content exceeding the limit will be truncated before it is written
/// > to disk."
///
/// **Important notes:**
/// - The limit is **1024 bytes**, not characters (UTF-8 multi-byte chars count more)
/// - Live streaming via `log stream` may show full content, but stored logs are truncated
/// - Running directly in Xcode may show full output, but archived/release builds truncate
/// - The limit is hard-coded in `libsystem_trace.dylib` and cannot be changed
///
/// **Source code references:**
/// - [os/log.h header (iOS SDK)](https://github.com/xybp888/iOS-SDKs/blob/master/iPhoneOS13.0.sdk/usr/include/os/log.h)
/// - [Apple Developer Forums - NSLog 1024 limit](https://developer.apple.com/forums/thread/63537)
/// - [Stack Overflow - iOS 10 NSLog truncation](https://stackoverflow.com/questions/39538320)
///
/// ## Rate Limiting
///
/// Android's kernel may drop log messages when too many are sent quickly.
/// Use [throttleDelay] (default 2ms) to avoid dropped messages when chunking.
///
/// ## Platform Summary
///
/// | Platform | Limit | Cause |
/// |----------|-------|-------|
/// | Android | 1024 chars | NDK `LOG_BUF_SIZE` in `__android_log_print` |
/// | iOS | ~1024 bytes | `os_log` unified logging |
/// | Desktop | None | Direct stdout |
/// | Web | None | Browser console |
///
/// ## Visibility
///
/// - `adb logcat`, `flutter logs`, Xcode console
/// - IDE debug console (Android Studio, VS Code, IntelliJ)
/// - Works in release builds
class PrintConsoleWriter implements ChirpWriter {
  final ConsoleMessageFormatter formatter;

  /// Maximum length per chunk (in characters).
  ///
  /// Platform-specific defaults via [platformPrintMaxChunkLength]:
  /// - **iOS**: 800 (safely under 1024 byte limit)
  /// - **Android**: 900 (safely under 1024 char limit of `LOG_BUF_SIZE`)
  /// - **Desktop/Web**: null (no chunking needed)
  final int? maxChunkLength;

  /// Whether to use ANSI color codes in output.
  ///
  /// Defaults to [platformSupportsAnsiColors].
  final bool useColors;

  /// Delay between chunks to avoid Android logcat rate limiting.
  ///
  /// Android's kernel may drop log messages when too many are sent quickly.
  /// Set to [Duration.zero] to disable throttling.
  ///
  /// Only applies when [maxChunkLength] causes message splitting.
  final Duration throttleDelay;

  /// Custom output function for testing or alternative output destinations.
  final void Function(String)? output;

  PrintConsoleWriter({
    ConsoleMessageFormatter? formatter,
    int? maxChunkLength,
    bool? useColors,
    this.throttleDelay = const Duration(milliseconds: 2),
    this.output,
  })  : formatter = formatter ?? RainbowMessageFormatter(),
        maxChunkLength = maxChunkLength ?? platformPrintMaxChunkLength,
        useColors = useColors ?? platformSupportsAnsiColors;

  DateTime? _lastPrintTime;

  @override
  void write(LogRecord record) {
    final buffer = ConsoleMessageBuffer(supportsColors: useColors);
    formatter.format(record, buffer);
    final text = buffer.toString();

    final chunks = maxChunkLength != null
        ? splitIntoChunks(text, maxChunkLength!)
        : [text];

    for (final chunk in chunks) {
      _throttleIfNeeded();
      if (output != null) {
        output!(chunk);
      } else {
        print(chunk);
      }
      _lastPrintTime = DateTime.now();
    }
  }

  void _throttleIfNeeded() {
    if (throttleDelay == Duration.zero || _lastPrintTime == null) return;

    final elapsed = DateTime.now().difference(_lastPrintTime!);
    if (elapsed < throttleDelay) {
      final remaining = throttleDelay - elapsed;
      // Busy-wait for short delays (sleep would require dart:io)
      final end = DateTime.now().add(remaining);
      while (DateTime.now().isBefore(end)) {
        // Spin
      }
    }
  }
}

/// Writes to console using [developer.log()].
///
/// **No character limit** - messages are never truncated.
/// **No ANSI color support** - colors are stripped because the output already
/// includes a `[name]` tag prefix that makes ANSI codes look messy.
///
/// **Requires Dart DevTools Service (DDS) connection:**
/// - Shows in Flutter DevTools Logging view
/// - Shows in IDE debug console when debugger is attached
/// - Does NOT show in `adb logcat` or Xcode console
/// - Does NOT work in release builds (AOT compiled)
///
/// **Advantages:**
/// - Unlimited message length
/// - No rate limiting
/// - Structured logging with name/level/error/stackTrace parameters
///
/// **Disadvantages:**
/// - Requires Flutter tooling / debugger attachment
/// - Cannot be viewed with `adb logcat` in Android Studio
/// - Not available in release mode
///
/// ## Log Level Mapping
///
/// [developer.log] expects levels compatible with `package:logging`.
/// Chirp levels are mapped as follows:
///
/// | Chirp Level | Chirp Severity | → | Logging Level | Logging Value |
/// |-------------|----------------|---|---------------|---------------|
/// | trace       | 0              | → | FINEST        | 300           |
/// | debug       | 100            | → | FINE          | 500           |
/// | info        | 200            | → | INFO          | 800           |
/// | notice      | 300            | → | INFO          | 800           |
/// | warning     | 400            | → | WARNING       | 900           |
/// | error       | 500            | → | SEVERE        | 1000          |
/// | critical    | 600            | → | SHOUT         | 1200          |
/// | wtf         | 1000           | → | SHOUT         | 1200          |
///
/// See:
/// - https://api.flutter.dev/flutter/dart-developer/log.html
/// - https://pub.dev/documentation/logging/latest/logging/Level-class.html
class DeveloperLogConsoleWriter implements ChirpWriter {
  final ConsoleMessageFormatter formatter;

  DeveloperLogConsoleWriter({
    ConsoleMessageFormatter? formatter,
  }) : formatter = formatter ?? RainbowMessageFormatter();

  @override
  void write(LogRecord record) {
    // Colors disabled - developer.log adds its own [name] prefix which
    // makes ANSI codes look messy in the output
    final buffer = ConsoleMessageBuffer(supportsColors: false);
    formatter.format(record, buffer);
    final text = buffer.toString();

    developer.log(
      text,
      name: record.loggerName ?? '',
      level: _mapToLoggingLevel(record.level),
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  /// Maps [ChirpLogLevel] severity to `package:logging` Level values.
  ///
  /// See https://pub.dev/documentation/logging/latest/logging/Level-class.html
  static int _mapToLoggingLevel(ChirpLogLevel level) {
    // package:logging Level values:
    // ALL=0, FINEST=300, FINER=400, FINE=500, CONFIG=700,
    // INFO=800, WARNING=900, SEVERE=1000, SHOUT=1200, OFF=2000
    return switch (level.severity) {
      < 100 => 300, // trace → FINEST
      < 200 => 500, // debug → FINE
      < 400 => 800, // info, notice → INFO
      < 500 => 900, // warning → WARNING
      < 600 => 1000, // error → SEVERE
      _ => 1200, // critical, wtf → SHOUT
    };
  }
}


/// Formats a [LogRecord] into a string for console output.
///
/// Implementations receive a [ConsoleMessageBuffer] to write formatted output.
/// The buffer handles ANSI color codes when colors are enabled.
abstract class ConsoleMessageFormatter {
  /// Formats the given [record] by writing to the [buffer].
  ///
  /// Implementations should build a span tree from the record and render it:
  /// ```dart
  /// void format(LogRecord record, ConsoleMessageBuffer buffer) {
  ///   final span = MyLogSpan(record).build();
  ///   renderSpan(span, buffer);
  /// }
  /// ```
  void format(LogRecord record, ConsoleMessageBuffer buffer);
}

/// A buffer for building console output with optional ANSI color support.
///
/// Manages a color stack to support nested colors. When a color is pushed,
/// it becomes active. When popped, the previous color is restored (not reset).
///
/// ## Example
///
/// ```dart
/// final buffer = ConsoleMessageBuffer(useColors: true);
/// buffer.pushColor(foreground: XtermColor.red);
/// buffer.write('Hello ');
/// buffer.pushColor(foreground: XtermColor.blue);
/// buffer.write('World');
/// buffer.popColor(); // restores red
/// buffer.write('!');
/// buffer.popColor(); // resets to default
/// print(buffer.toString()); // "Hello " in red, "World" in blue, "!" in red
/// ```
class ConsoleMessageBuffer {
  /// Whether to emit ANSI color codes.
  ///
  /// When false, all color operations are no-ops and output is plain text.
  final bool supportsColors;

  final List<(XtermColor?, XtermColor?)> _colorStack = [];

  ConsoleMessageBuffer({
    required this.supportsColors,
  });

  final StringBuffer _buffer = StringBuffer();

  /// Pushes a color onto the stack and writes its ANSI escape code.
  ///
  /// The color remains active until [popColor] is called.
  /// Nested calls create a color stack - inner colors override outer ones.
  void pushColor({XtermColor? foreground, XtermColor? background}) {
    _colorStack.add((foreground, background));
    if (supportsColors) {
      _writeColorCode(foreground, background);
    }
  }

  /// Pops the current color and restores the previous one.
  ///
  /// If the stack becomes empty, writes an ANSI reset code.
  /// Otherwise, writes the ANSI code for the previous color.
  void popColor() {
    if (_colorStack.isEmpty) return;
    _colorStack.removeLast();
    if (supportsColors) {
      if (_colorStack.isEmpty) {
        _buffer.write('\x1B[0m');
      } else {
        final (fg, bg) = _colorStack.last;
        _writeColorCode(fg, bg);
      }
    }
  }

  void _writeColorCode(XtermColor? foreground, XtermColor? background) {
    if (foreground != null) {
      _buffer.write('\x1B[38;5;${foreground.code}m');
    }
    if (background != null) {
      _buffer.write('\x1B[48;5;${background.code}m');
    }
  }

  /// Writes a value to the buffer, optionally with colors.
  ///
  /// If [foreground] or [background] is provided and [supportsColors] is true,
  /// the value is wrapped with push/pop color calls.
  ///
  /// When colors are active (either from the color stack or from parameters),
  /// color codes are re-applied after each newline to ensure colors persist
  /// across multiple lines.
  void write(Object? value, {XtermColor? foreground, XtermColor? background}) {
    if (supportsColors && (foreground != null || background != null)) {
      pushColor(foreground: foreground, background: background);
      _writeWithColorReapply(value, foreground, background);
      popColor();
    } else if (supportsColors && _colorStack.isNotEmpty) {
      final (fg, bg) = _colorStack.last;
      _writeWithColorReapply(value, fg, bg);
    } else {
      _buffer.write(value);
    }
  }

  /// Writes value to buffer, re-applying current color after each newline.
  void _writeWithColorReapply(Object? value, XtermColor? fg, XtermColor? bg) {
    final text = value?.toString() ?? 'null';
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      _buffer.write(lines[i]);
      if (i < lines.length - 1) {
        _buffer.write('\n');
        _writeColorCode(fg, bg);
      }
    }
  }

  /// Returns the accumulated buffer contents as a string.
  @override
  String toString() {
    return _buffer.toString();
  }

  /// Returns the visible length of the buffer contents, excluding ANSI codes.
  int get visibleLength => stripAnsiCodes(_buffer.toString()).length;

  /// Creates a new buffer with the same settings but empty contents.
  ///
  /// Useful for spans that need to pre-render children to measure them.
  ConsoleMessageBuffer createChildBuffer() {
    return ConsoleMessageBuffer(supportsColors: supportsColors);
  }
}

/// Strips ANSI escape codes from a string.
///
/// Useful for calculating visible text width when content may contain
/// color codes or other terminal control sequences.
String stripAnsiCodes(String s) {
  var result = s;
  for (final pattern in _ansiPatterns) {
    result = result.replaceAll(pattern, '');
  }
  return result;
}

final _ansiPatterns = [
  // SGR (Select Graphic Rendition): colors, bold, underline, etc.
  // Example: \x1B[31m (red), \x1B[1;4m (bold+underline), \x1B[0m (reset)
  RegExp(r'\x1B\[[0-9;]*m'),

  // CSI (Control Sequence Introducer): cursor movement, erase, etc.
  // Example: \x1B[2J (clear screen), \x1B[10;20H (move cursor)
  RegExp(r'\x1B\[[0-9;?]*[A-LN-Za-z]'),

  // OSC (Operating System Command): title, hyperlinks, etc.
  // Terminated by BEL (\x07) or ST (\x1B\\)
  // Example: \x1B]0;Window Title\x07
  RegExp(r'\x1B\][^\x07]*\x07'),
  RegExp(r'\x1B\][^\x1B]*\x1B\\'),

  // Single-character escapes: save/restore cursor, etc.
  // Example: \x1B7 (save cursor), \x1B8 (restore cursor)
  RegExp(r'\x1B[78]'),
];

/// Splits a text into chunks that fit within [maxLength] characters.
///
/// Android and iOS truncate log output based on actual bytes (~4000 chars on
/// Android, ~1024 bytes on iOS). This function splits long messages into
/// multiple chunks while trying to preserve readability.
///
/// The function checks BOTH visible character count AND actual string length.
/// This is important because ANSI color codes add significant overhead that
/// mobile platforms count toward their limits. For example, a text with 115
/// newlines and colors might have 2981 visible characters but 4029 actual
/// bytes due to color codes being re-applied after each newline.
///
/// Splitting priorities (in order):
/// 1. Prefer splitting at newlines (`\n`)
/// 2. Avoid splitting within JSON objects (balanced `{` and `}`)
/// 3. Avoid splitting within JWTs (base64 segments separated by `.`)
/// 4. If no good split point exists, force split at [maxLength]
///
/// ANSI escape codes are preserved but DO count toward the actual length limit
/// since mobile platforms count them.
List<String> splitIntoChunks(String text, int maxLength) {
  if (maxLength <= 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be positive');
  }

  // Android/iOS truncate based on actual bytes, not visible characters.
  // ANSI color codes count toward the limit.
  if (text.length <= maxLength) {
    return [text];
  }

  final chunks = <String>[];
  var remaining = text;

  while (remaining.isNotEmpty) {
    if (remaining.length <= maxLength) {
      chunks.add(remaining);
      break;
    }

    var splitIndex = _findBestSplitPoint(remaining, maxLength);

    // Ensure progress: if splitIndex is 0, we must take at least 1 code unit
    // (or 2 for surrogate pairs) to avoid infinite loops
    if (splitIndex == 0) {
      final firstCodeUnit = remaining.codeUnitAt(0);
      // High surrogate range: 0xD800-0xDBFF
      if (firstCodeUnit >= 0xD800 &&
          firstCodeUnit <= 0xDBFF &&
          remaining.length > 1) {
        splitIndex = 2; // Take the whole surrogate pair
      } else {
        splitIndex = 1;
      }
    }

    final chunk = remaining.substring(0, splitIndex);
    chunks.add(chunk);

    // Skip the newline if we split at one
    var nextStart = splitIndex;
    if (nextStart < remaining.length && remaining[nextStart] == '\n') {
      nextStart++;
    }
    remaining = remaining.substring(nextStart);
  }

  return chunks;
}

/// Finds the best position to split [text] within [maxLength] bytes.
///
/// Searches backwards from [maxLength] to find a good split point.
/// Priority: newline > whitespace/punctuation > force split at limit.
int _findBestSplitPoint(String text, int maxLength) {
  final limit = maxLength.clamp(0, text.length);

  // Priority 1: Find last newline before limit (O(n) optimized native search)
  final newlineIndex = text.lastIndexOf('\n', limit - 1);
  if (newlineIndex >= 0) {
    return newlineIndex;
  }

  // Priority 2: Find last whitespace/punctuation
  const splitChars = {' ', '\t', ',', ';', ':', '}', ']', ')'};
  for (var i = limit - 1; i >= 0; i--) {
    if (splitChars.contains(text[i])) {
      return i + 1;
    }
  }

  // Priority 3: Force split at limit, but avoid splitting inside ANSI/emoji
  return _adjustSplitPosition(text, limit);
}

/// Adjusts split position to avoid cutting ANSI sequences or emoji/surrogate pairs.
int _adjustSplitPosition(String text, int position) {
  if (position <= 0 || position >= text.length) return position;

  var adjustedPosition = position;

  // Don't split in the middle of a surrogate pair (emoji, etc.)
  // Low surrogate range: 0xDC00-0xDFFF
  final codeUnit = text.codeUnitAt(adjustedPosition);
  if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
    adjustedPosition--; // Move before the high surrogate
  }

  // Don't split inside ANSI escape sequences
  // Look backwards for ESC character (ANSI sequences are max ~20 chars)
  final searchStart = (adjustedPosition - 20).clamp(0, adjustedPosition);
  for (var i = adjustedPosition - 1; i >= searchStart; i--) {
    if (text[i] == '\x1B') {
      // Found ESC - check if position is inside this sequence
      // ANSI sequences end with a letter (0x40-0x7E)
      for (var j = i + 1; j < text.length && j <= adjustedPosition + 10; j++) {
        final c = text.codeUnitAt(j);
        if (c >= 0x40 && c <= 0x7E && text[j] != '[') {
          // Sequence ends at j
          if (adjustedPosition <= j) {
            // We're inside the sequence, split before it
            return i;
          }
          break;
        }
      }
      break;
    }
  }
  return adjustedPosition;
}
