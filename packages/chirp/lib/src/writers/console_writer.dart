// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';
import 'package:chirp/src/platform/platform_info.dart';

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
  /// The formatter that writes log records to a buffer.
  final ConsoleMessageFormatter formatter;

  /// Maximum length per chunk (in characters).
  ///
  /// Platform-specific defaults via [platformPrintMaxChunkLength]:
  /// - **iOS**: 800 (safely under 1024 byte limit)
  /// - **Android**: 900 (safely under 1024 char limit of `LOG_BUF_SIZE`)
  /// - **Desktop/Web**: null (no chunking needed)
  final int? maxChunkLength;

  /// Terminal capabilities for output rendering.
  ///
  /// Defaults to [TerminalCapabilities.autoDetect].
  final TerminalCapabilities capabilities;

  /// Custom output function for testing or alternative output destinations.
  final void Function(String) output;

  /// Creates a console writer that outputs via `print()`.
  ///
  /// Falls back to [RainbowMessageFormatter] if no [formatter] is provided.
  /// Use [output] to redirect logs for testing or alternative destinations.
  /// Use [minLevel] to filter out logs below a certain level.
  PrintConsoleWriter({
    ConsoleMessageFormatter? formatter,
    int? maxChunkLength,
    TerminalCapabilities? capabilities,
    void Function(String)? output,
    ChirpLogLevel? minLevel,
  })  : formatter = formatter ?? RainbowMessageFormatter(),
        maxChunkLength = maxChunkLength ?? platformPrintMaxChunkLength,
        capabilities = capabilities ?? TerminalCapabilities.autoDetect(),
        output = output ?? print {
    if (minLevel != null) {
      setMinLogLevel(minLevel);
    }
  }

  @override
  bool get requiresCallerInfo => formatter.requiresCallerInfo;

  @override
  void write(LogRecord record) {
    // Format
    final buffer = ConsoleMessageBuffer(capabilities: capabilities);
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

/// {@template chirp.ConsoleMessageFormatter}
/// Formats a [LogRecord] into a string for console output.
///
/// Implementations receive a [ConsoleMessageBuffer] to write formatted output.
/// The buffer handles ANSI color codes when colors are enabled.
/// {@endtemplate}
abstract class ConsoleMessageFormatter {
  /// {@macro chirp.ConsoleMessageFormatter}
  const ConsoleMessageFormatter();

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

/// A buffer for building console output with terminal capability awareness.
///
/// This is the central abstraction between spans and the terminal. Spans declare
/// their intent (e.g., "render this in red") and the buffer handles the
/// implementation details based on terminal capabilities.
///
/// ## Style Stack
///
/// Manages a style stack to support nested colors and text styles. When a style
/// is pushed, it becomes active. When popped, the previous style is restored.
/// Styles are automatically re-applied after newlines for terminals that don't
/// preserve styles across line breaks.
///
/// ## Terminal Capabilities
///
/// Access via [capabilities]. Currently supports:
/// - **Color support**: none, 16-color, 256-color, or truecolor
///
/// Future capabilities may include:
/// - **Terminal width**: For text wrapping, alignment, and bordered boxes
/// - **Unicode support**: Whether to use box-drawing characters (`╭─╮`) or
///   ASCII fallbacks (`+-+`)
/// - **Hyperlink support**: OSC 8 sequences for clickable URLs and file paths
///
/// The buffer abstracts these capabilities so spans can remain declarative.
/// For example, colors work transparently today - spans request colors and the
/// buffer emits appropriate escape codes (or nothing if unsupported).
///
/// ## Example
///
/// ```dart
/// final caps = TerminalCapabilities(colorSupport: TerminalColorSupport.ansi256);
/// final buffer = ConsoleMessageBuffer(capabilities: caps);
/// buffer.pushStyle(foreground: Ansi256.red_1);
/// buffer.write('Hello ');
/// buffer.pushStyle(foreground: Ansi256.blue_4, dim: true);
/// buffer.write('World');
/// buffer.popStyle(); // restores red, removes dim
/// buffer.write('!');
/// buffer.popStyle(); // resets to default
/// print(buffer.toString()); // "Hello " in red, "World" in dim blue, "!" in red
/// ```
class ConsoleMessageBuffer {
  /// Creates a console message buffer with the given terminal [capabilities].
  ConsoleMessageBuffer({
    required this.capabilities,
  });

  /// Terminal capabilities for this buffer.
  ///
  /// Use this to query terminal features when making rendering decisions:
  /// ```dart
  /// // Choose rendering strategy based on color support
  /// if (buffer.capabilities.colorSupport.supportsTruecolor) {
  ///   // render smooth gradient
  /// } else {
  ///   // render with 256-color approximation
  /// }
  /// ```
  ///
  /// Note: You don't need to check capabilities before calling [pushStyle] -
  /// it handles unsupported terminals gracefully by not emitting escape codes.
  final TerminalCapabilities capabilities;

  final List<_StyleState> _styleStack = [];

  final StringBuffer _buffer = StringBuffer();

  /// Pushes a style onto the stack and writes its ANSI escape codes.
  ///
  /// The style remains active until [popStyle] is called.
  /// Nested calls create a style stack - inner styles override outer ones.
  ///
  /// Parameters:
  /// - [foreground]: Foreground text color
  /// - [background]: Background color
  /// - [bold]: Apply bold styling (SGR code 1). Note: many terminals render
  ///   bold as bright/intense color instead of font weight, especially with
  ///   basic 16 colors. Takes precedence over [dim] if both are true.
  /// - [dim]: Apply dim/faint styling (SGR code 2). Support varies by terminal;
  ///   some ignore it entirely. Ignored if [bold] is also true.
  /// - [italic]: Apply italic styling (SGR code 3)
  /// - [underline]: Apply underline styling (SGR code 4)
  /// - [strikethrough]: Apply strikethrough styling (SGR code 9)
  void pushStyle({
    ConsoleColor? foreground,
    ConsoleColor? background,
    bool bold = false,
    bool dim = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
  }) {
    final state = _StyleState(
      foreground,
      background,
      bold: bold,
      dim: dim,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
    );
    _styleStack.add(state);
    if (capabilities.supportsColors) {
      _writeStyleCode(state);
    }
  }

  /// Pops the current style and restores the previous one.
  ///
  /// If the stack becomes empty, writes an ANSI reset code.
  /// Otherwise, writes the ANSI codes for the previous style.
  void popStyle() {
    if (_styleStack.isEmpty) return;
    _styleStack.removeLast();
    if (capabilities.supportsColors) {
      if (_styleStack.isEmpty) {
        _buffer.write('\x1B[0m');
      } else {
        _writeStyleCode(_styleStack.last);
      }
    }
  }

  void _writeStyleCode(_StyleState state) {
    if (state.bold) {
      _buffer.write('\x1B[1m'); // SGR 1: bold
    } else if (state.dim) {
      // dim is skipped when bold is true (bold takes precedence)
      _buffer.write('\x1B[2m'); // SGR 2: dim/faint
    }
    if (state.italic) {
      _buffer.write('\x1B[3m'); // SGR 3: italic
    }
    if (state.underline) {
      _buffer.write('\x1B[4m'); // SGR 4: underline
    }
    if (state.strikethrough) {
      _buffer.write('\x1B[9m'); // SGR 9: strikethrough
    }
    if (state.foreground != null) {
      _buffer.write(_colorEscapeCode(state.foreground!, isForeground: true));
    }
    if (state.background != null) {
      _buffer.write(_colorEscapeCode(state.background!, isForeground: false));
    }
  }

  /// Generates the ANSI escape code for a color based on color support level.
  String _colorEscapeCode(ConsoleColor color, {required bool isForeground}) {
    // DefaultColor means "use terminal's default" - output reset code
    if (color is DefaultColor) {
      return isForeground ? '\x1B[39m' : '\x1B[49m';
    }

    final base = isForeground ? 38 : 48;
    final base16 = isForeground ? 30 : 40;

    return switch (capabilities.colorSupport) {
      TerminalColorSupport.none => '',
      TerminalColorSupport.ansi16 => '\x1B[${base16 + _to16Color(color)}m',
      TerminalColorSupport.ansi256 => switch (color) {
          final IndexedColor c => '\x1B[$base;5;${c.code}m',
          final RgbColor c => '\x1B[$base;5;${_rgbTo256(c.r, c.g, c.b)}m',
          DefaultColor() => throw StateError('unreachable'),
        },
      TerminalColorSupport.truecolor =>
        '\x1B[$base;2;${color.r};${color.g};${color.b}m',
    };
  }

  /// Converts RGB to closest 256-color code.
  int _rgbTo256(int r, int g, int b) {
    // Check if it's a grayscale color
    if (r == g && g == b) {
      if (r < 8) return 16; // black
      if (r > 248) return 231; // white
      return ((r - 8) / 247 * 24).round() + 232;
    }
    // Map to 6x6x6 color cube
    final ri = (r / 255 * 5).round();
    final gi = (g / 255 * 5).round();
    final bi = (b / 255 * 5).round();
    return 16 + 36 * ri + 6 * gi + bi;
  }

  /// Writes a value to the buffer, optionally with colors.
  ///
  /// If [foreground] or [background] is provided and colors are supported,
  /// the value is wrapped with push/pop style calls.
  ///
  /// When styles are active (either from the style stack or from parameters),
  /// style codes are re-applied after each newline to ensure styles persist
  /// across multiple lines.
  void write(Object? value,
      {ConsoleColor? foreground, ConsoleColor? background}) {
    final supportsColors = capabilities.supportsColors;
    if (supportsColors && (foreground != null || background != null)) {
      pushStyle(foreground: foreground, background: background);
      _writeWithStyleReapply(value, _styleStack.last);
      popStyle();
    } else if (supportsColors && _styleStack.isNotEmpty) {
      _writeWithStyleReapply(value, _styleStack.last);
    } else {
      _buffer.write(value);
    }
  }

  /// Writes value to buffer, re-applying current style after each newline.
  ///
  /// Platforms like github actions and some terminals do not apply the current
  /// ansi style for the next line
  /// https://github.com/orgs/community/discussions/40864
  void _writeWithStyleReapply(Object? value, _StyleState state) {
    final text = value?.toString() ?? 'null';
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      _buffer.write(lines[i]);
      if (i < lines.length - 1) {
        _buffer.write('\n');
        _writeStyleCode(state);
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
    return ConsoleMessageBuffer(capabilities: capabilities);
  }
}

/// Internal state for style stack entries.
class _StyleState {
  final ConsoleColor? foreground;
  final ConsoleColor? background;
  final bool bold;
  final bool dim;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  _StyleState(
    this.foreground,
    this.background, {
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });
}

/// Converts a [ConsoleColor] to the closest 16-color ANSI index.
///
/// Returns an offset (0-15) to add to base code 30 (fg) or 40 (bg).
/// For bright colors (8-15), caller should use codes 90-97/100-107.
int _to16Color(ConsoleColor color) {
  // For indexed colors with code 0-15, use directly
  if (color is IndexedColor && color.code < 16) {
    final code = color.code;
    return code < 8 ? code : (code - 8 + 60);
  }

  // Convert RGB to 16-color approximation
  final r = color.r;
  final g = color.g;
  final b = color.b;

  // Check for grayscale
  if (r == g && g == b) {
    if (r < 64) return 0; // black
    if (r < 192) return 60; // bright black (gray)
    return 7; // white
  }

  // Map RGB to on/off channels (threshold at 128)
  final r1 = r >= 128 ? 1 : 0;
  final g1 = g >= 128 ? 1 : 0;
  final b1 = b >= 128 ? 1 : 0;

  // Bright if any channel is high (>= 192)
  final bright = (r >= 192 || g >= 192 || b >= 192) ? 60 : 0;

  // ANSI: 0=black, 1=red, 2=green, 3=yellow, 4=blue, 5=magenta, 6=cyan, 7=white
  return bright + (r1 * 1) + (g1 * 2) + (b1 * 4);
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
