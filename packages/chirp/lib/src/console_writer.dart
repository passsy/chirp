// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

export 'package:chirp/src/platform/platform_info.dart';

/// Writes to console using dart:core [print].
///
/// **Supports ANSI colors**, supported by almost all terminals and IDEs for Flutter/Dart.
/// Use ANSI colors for local development.
///
/// ## Android Truncation (1024 characters)
///
/// On Android, `print()` is truncated at **1024 characters**. This limit comes
/// from the NDK's `liblog` library, which is smaller than logcats 4068 byte limit.
///
/// **The truncation path:**
/// ```text
/// Dart print()
///   → Flutter Engine: __android_log_print(ANDROID_LOG_INFO, tag, "%s", msg)
///     → liblog: vsnprintf(buf, LOG_BUF_SIZE, fmt, ap)  // LOG_BUF_SIZE = 1024
///       → kernel logger (LOGGER_ENTRY_MAX_PAYLOAD ≈ 4068, never reached)
/// ```
///
/// **Why Java's `Log.d()` allows ~4000 chars but Flutter doesn't:**
/// Java's `android.util.Log` calls `__android_log_buf_write()` directly,
/// bypassing the 1024-byte formatting buffer. Flutter uses the NDK path which
/// goes through `__android_log_print()` with its smaller buffer.
///
/// **Source code references:**
/// - [LOG_BUF_SIZE = 1024](https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/logger_write.cpp;l=67)
/// - [vsnprintf truncation](https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/logger_write.cpp;l=426)
/// - [Flutter engine log callback](https://github.com/flutter/flutter/blob/9bdd5efdd239db16f2693a2b9ec1a3d13f306304/engine/src/flutter/shell/platform/android/flutter_main.cc#L184)
/// - [LOGGER_ENTRY_MAX_PAYLOAD (kernel limit)](https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/include/log/log.h;l=71)
///
/// ## iOS Truncation (1024 bytes)
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
/// - [os/log.h header (iOS SDK)](https://github.com/xybp888/iOS-SDKs/blob/a18d5334788b97e586d1afebd3cb0006af6a1416/iPhoneOS13.0.sdk/usr/include/os/log.h#L202)
/// - [Apple Developer Forums - NSLog 1024 limit](https://developer.apple.com/forums/thread/63537)
/// - [Stack Overflow - iOS 10 NSLog truncation](https://stackoverflow.com/questions/39538320)
///
/// ## Rate Limiting
///
/// Android's logd daemon can mark apps as "chatty" and collapse logs when
/// they exceed ~5 messages per second. However, testing with the
/// `example/print_limits` app showed **no observable rate limiting** even
/// when sending 4MB of log data without any throttling. The "chatty"
/// behavior appears to be disabled or very lenient on modern Android
/// versions.
///
/// Flutter's `debugPrintThrottled` uses 12KB/s throttling as a precaution,
/// but our testing suggests this may be unnecessary. If you experience
/// dropped logs on specific devices, consider using `debugPrintThrottled` as [output]
/// or implementing custom throttling.
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
class PrintConsoleWriter extends ChirpWriter {
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

  /// Custom output function for testing or alternative output destinations.
  final void Function(String) output;

  PrintConsoleWriter({
    ConsoleMessageFormatter? formatter,
    int? maxChunkLength,
    bool? useColors,
    void Function(String)? output,
  })  : formatter = formatter ?? RainbowMessageFormatter(),
        maxChunkLength = maxChunkLength ?? platformPrintMaxChunkLength,
        useColors = useColors ?? platformSupportsAnsiColors,
        output = output ?? print;

  @override
  bool get requiresCallerInfo => formatter.requiresCallerInfo;

  @override
  void write(LogRecord record) {
    // Format
    final buffer = ConsoleMessageBuffer(supportsColors: useColors);
    formatter.format(record, buffer);
    final text = buffer.toString();

    // No chunking needed (default on desktop/web)
    if (maxChunkLength == null) {
      output(text);
      return;
    }

    // Chunking needed (mobile platforms)
    for (final chunk in splitIntoChunks(text, maxChunkLength!)) {
      output(chunk);
    }
  }
}

/// Formats a [LogRecord] into a string for console output.
///
/// Implementations receive a [ConsoleMessageBuffer] to write formatted output.
/// The buffer handles ANSI color codes when colors are enabled.
abstract class ConsoleMessageFormatter {
  /// Whether this formatter requires caller info (file, line, class, method).
  ///
  /// If `true`, the logger will capture `StackTrace.current` for each log call.
  /// If `false`, the expensive stack trace capture can be skipped.
  ///
  /// Default is `false`. Override in subclasses that display caller info.
  bool get requiresCallerInfo => false;

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
