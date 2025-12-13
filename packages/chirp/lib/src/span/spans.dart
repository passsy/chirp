import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:meta/meta.dart';

// =============================================================================
// Leaf Spans (no children)
// =============================================================================

/// {@template chirp.EmptySpan}
/// A span that renders nothing.
///
/// Similar to Flutter's `SizedBox.shrink()`, use this when a span
/// conditionally produces no output:
///
/// ```dart
/// LogSpan build() {
///   if (data == null) return EmptySpan();
///   return PlainText(data.toString());
/// }
/// ```
/// {@endtemplate}
@experimental
class EmptySpan extends LeafSpan {
  /// {@macro chirp.EmptySpan}
  EmptySpan();

  @override
  void render(ConsoleMessageBuffer buffer) {
    // Intentionally empty - renders nothing
  }

  @override
  String toString() => 'EmptySpan()';
}

/// {@template chirp.PlainText}
/// Renders literal text without any ANSI formatting.
///
/// This is the most basic span - use it for any text content that doesn't
/// need colors or styling. Most semantic spans (like [LogMessage], [ClassName])
/// build down to [PlainText] internally.
/// {@endtemplate}
@experimental
class PlainText extends LeafSpan {
  /// The text to render verbatim.
  final String value;

  /// {@macro chirp.PlainText}
  PlainText(this.value);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(value);
  }

  @override
  String toString() => 'PlainText("$value")';
}

/// {@template chirp.Whitespace}
/// Renders a single space character.
///
/// Use between spans for visual separation. For multiple spaces, use
/// [PlainText] with the desired number of spaces instead.
/// {@endtemplate}
@experimental
class Whitespace extends LeafSpan {
  /// {@macro chirp.Whitespace}
  Whitespace();

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(' ');
  }

  @override
  String toString() => 'Whitespace()';
}

/// {@template chirp.NewLine}
/// Renders a line break (`\n`).
///
/// Use to separate log output across multiple lines, such as between
/// the main message and a stack trace.
/// {@endtemplate}
@experimental
class NewLine extends LeafSpan {
  /// {@macro chirp.NewLine}
  NewLine();

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write('\n');
  }

  @override
  String toString() => 'NewLine()';
}

// =============================================================================
// Single Child Spans
// =============================================================================

/// Applies foreground and/or background color and text styles to a child span.
///
/// Supports all common ANSI SGR text attributes:
/// - [foreground] and [background] colors
/// - [bold] (SGR 1) - increased intensity
/// - [dim] (SGR 2) - decreased intensity
/// - [italic] (SGR 3) - italic text
/// - [underline] (SGR 4) - underlined text
/// - [strikethrough] (SGR 9) - crossed-out text
///
/// Example:
/// ```dart
/// AnsiStyled(
///   foreground: Ansi16.red,
///   bold: true,
///   underline: true,
///   child: PlainText('Important!'),
/// )
/// ```
@experimental
class AnsiStyled extends SingleChildSpan {
  /// The foreground (text) color to apply.
  ///
  /// Use [Ansi16] for basic 16-color support, [Ansi256] for 256 colors,
  /// or [RgbColor] for truecolor (24-bit) support.
  final ConsoleColor? foreground;

  /// The background color to apply behind the text.
  ///
  /// Use [Ansi16] for basic 16-color support, [Ansi256] for 256 colors,
  /// or [RgbColor] for truecolor (24-bit) support.
  final ConsoleColor? background;

  /// Whether to apply bold styling (ANSI SGR code 1).
  ///
  /// **Terminal compatibility:**
  /// - Many terminals render bold as **bright/intense color** instead of
  ///   increased font weight, especially with the basic 16 colors
  /// - Some terminals (like macOS Terminal.app) may show bold as both
  ///   brighter AND heavier weight
  /// - With 256-color or truecolor, bold more reliably means font weight
  /// - A few older terminals may ignore bold entirely
  ///
  /// **Precedence:** If both [bold] and [dim] are true, bold takes precedence
  /// and dim is ignored. They share the same reset code (SGR 22) and have
  /// contradictory visual effects.
  final bool bold;

  /// Whether to apply dim/faint styling (ANSI SGR code 2).
  ///
  /// Dim text appears with reduced intensity/brightness.
  ///
  /// **Terminal compatibility:**
  /// - Support varies significantly across terminals
  /// - Some terminals (like older xterm) may ignore dim entirely
  /// - With truecolor (RGB), some terminals mathematically reduce brightness,
  ///   while others may ignore it or render it inconsistently
  /// - iTerm2, VS Code terminal, and most modern terminals support dim well
  /// - Windows Console (conhost) has limited dim support
  ///
  /// **Precedence:** Ignored if [bold] is also true, since they share the same
  /// reset code (SGR 22) and have contradictory visual effects.
  final bool dim;

  /// Whether to apply italic styling (ANSI SGR code 3).
  final bool italic;

  /// Whether to apply underline styling (ANSI SGR code 4).
  final bool underline;

  /// Whether to apply strikethrough styling (ANSI SGR code 9).
  final bool strikethrough;

  /// Creates a styled span that applies ANSI formatting to its [child].
  ///
  /// All style options default to false/null (no styling applied).
  AnsiStyled({
    super.child,
    this.foreground,
    this.background,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });

  @override
  void render(ConsoleMessageBuffer buffer) {
    final c = child;
    if (c == null) return;
    buffer.pushStyle(
      foreground: foreground,
      background: background,
      bold: bold,
      dim: dim,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
    );
    c.render(buffer);
    buffer.popStyle();
  }

  @override
  String toString() =>
      'AnsiStyled(fg: $foreground, bg: $background, bold: $bold, dim: $dim, '
      'italic: $italic, underline: $underline, strikethrough: $strikethrough, '
      'child: $child)';
}

// =============================================================================
// Multi Child Spans
// =============================================================================

/// A sequence of spans rendered sequentially.
@experimental
class SpanSequence extends MultiChildSpan {
  /// Creates a sequence of spans with optional [separator] between children.
  SpanSequence({super.children, this.separator});

  /// Optional span to render between each child.
  final LogSpan? separator;

  @override
  void render(ConsoleMessageBuffer buffer) {
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && separator != null) {
        separator!.render(buffer);
      }
      children[i].render(buffer);
    }
  }

  @override
  String toString() => 'SpanSequence($children, separator: $separator)';
}

// =============================================================================
// Slotted Spans
// =============================================================================

/// Renders a prefix and/or suffix around an optional child.
///
/// If [child] is null, renders nothing (empty).
/// If [child] is non-null, renders [prefix], [child], [suffix].
@experimental
class Surrounded extends SlottedSpan {
  /// Slot name for the prefix span.
  static const prefixSlot = 'prefix';

  /// Slot name for the child span.
  static const childSlot = 'child';

  /// Slot name for the suffix span.
  static const suffixSlot = 'suffix';

  /// The span rendered before the child.
  LogSpan? get prefix => getSlot(prefixSlot);

  set prefix(LogSpan? v) => setSlot(prefixSlot, v);

  /// The main content span (if null, nothing is rendered).
  LogSpan? get child => getSlot(childSlot);

  set child(LogSpan? v) => setSlot(childSlot, v);

  /// The span rendered after the child.
  LogSpan? get suffix => getSlot(suffixSlot);

  set suffix(LogSpan? v) => setSlot(suffixSlot, v);

  /// Creates a surrounded span with optional [prefix], [child], and [suffix].
  Surrounded({LogSpan? prefix, LogSpan? child, LogSpan? suffix}) {
    this.prefix = prefix;
    this.child = child;
    this.suffix = suffix;
  }

  @override
  void render(ConsoleMessageBuffer buffer) {
    if (child == null) return;
    prefix?.render(buffer);
    child?.render(buffer);
    suffix?.render(buffer);
  }

  @override
  String toString() =>
      'Surrounded(prefix: $prefix, child: $child, suffix: $suffix)';
}

// =============================================================================
// Semantic spans - these mark specific types of log content
// =============================================================================

/// {@template chirp.Timestamp}
/// Renders a timestamp in "HH:mm:ss.mmm" format (time only, no date).
///
/// Use this for compact log output where the date is not needed.
/// For full date and time, use [FullTimestamp] instead.
///
/// Example output: `10:30:45.123`
/// {@endtemplate}
@experimental
class Timestamp extends LeafSpan {
  /// The [DateTime] to extract the time from.
  final DateTime date;

  /// {@macro chirp.Timestamp}
  Timestamp(this.date);

  @override
  LogSpan build() {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    return PlainText('$hour:$minute:$second.$ms');
  }

  @override
  String toString() => 'Timestamp($date)';
}

/// {@template chirp.DartSourceCodeLocation}
/// Renders a source code location as "file:line".
///
/// Use to show where a log call originated in the codebase.
/// Returns [EmptySpan] if [fileName] is null.
///
/// Example output: `user_service.dart:42`
/// {@endtemplate}
@experimental
class DartSourceCodeLocation extends LeafSpan {
  /// The file name (typically without full path), e.g., "user_service.dart".
  final String? fileName;

  /// The line number in the source file, or null if unknown.
  final int? line;

  /// {@macro chirp.DartSourceCodeLocation}
  DartSourceCodeLocation({this.fileName, this.line});

  @override
  LogSpan build() {
    if (fileName == null) return EmptySpan();
    if (line != null) {
      return PlainText('$fileName:$line');
    }
    return PlainText(fileName!);
  }

  @override
  String toString() => 'DartSourceCodeLocation($fileName:$line)';
}

/// {@template chirp.LoggerName}
/// Renders a logger name for named loggers.
///
/// Named loggers help organize and filter logs by subsystem or feature.
/// Create named loggers with [ChirpLogger.named].
///
/// Example output: `payment`, `auth`, `api.users`
/// {@endtemplate}
@experimental
class LoggerName extends LeafSpan {
  /// The logger name, e.g., "payment" or "api.users".
  final String name;

  /// {@macro chirp.LoggerName}
  LoggerName(this.name);

  @override
  LogSpan build() => PlainText(name);

  @override
  String toString() => 'LoggerName("$name")';
}

/// Aligns child content within a fixed-width column.
///
/// Use [Aligned] to create consistent column widths in formatted output,
/// useful for aligning log levels, timestamps, or other fixed-width fields.
///
/// ## Example
///
/// ```dart
/// // Left-align log level in 8-character column
/// Aligned(
///   width: 8,
///   align: HorizontalAlign.left,
///   child: BracketedLogLevel(record.level),
/// )
/// // "[info]  " (padded to 8 chars)
///
/// // Right-align timestamp
/// Aligned(
///   width: 12,
///   align: HorizontalAlign.right,
///   child: Timestamp(record.date),
/// )
///
/// // Center-align content
/// Aligned(
///   width: 20,
///   align: HorizontalAlign.center,
///   child: PlainText('centered'),
/// )
/// // "      centered      "
/// ```
@experimental
class Aligned extends SingleChildSpan {
  /// Creates an aligned span with fixed [width].
  ///
  /// - [HorizontalAlign.left]: Content is padded on the right with spaces.
  /// - [HorizontalAlign.right]: Content is padded on the left with spaces.
  /// - [HorizontalAlign.center]: Content is padded equally on both sides.
  ///   If the padding is odd, the extra space goes on the right.
  Aligned({
    required this.width,
    required this.align,
    required super.child,
  });

  /// The horizontal alignment of the content within the column.
  final HorizontalAlign align;

  /// The fixed width of the column in characters.
  final int width;

  @override
  void render(ConsoleMessageBuffer buffer) {
    final b = buffer.createChildBuffer();
    child?.render(b);
    final content = b.toString();
    // Use visible length (excluding ANSI escape codes) for padding calculation
    final visibleLength = stripAnsiCodes(content).length;
    final padded = switch (align) {
      HorizontalAlign.left => _padRight(content, width, visibleLength),
      HorizontalAlign.right => _padLeft(content, width, visibleLength),
      HorizontalAlign.center => _padCenter(content, width, visibleLength),
    };
    buffer.write(padded);
  }

  static String _padLeft(String content, int width, int visibleLength) {
    if (visibleLength >= width) return content;
    return '${' ' * (width - visibleLength)}$content';
  }

  static String _padRight(String content, int width, int visibleLength) {
    if (visibleLength >= width) return content;
    return '$content${' ' * (width - visibleLength)}';
  }

  static String _padCenter(String content, int width, int visibleLength) {
    if (visibleLength >= width) return content;
    final totalPadding = width - visibleLength;
    final leftPadding = totalPadding ~/ 2;
    final rightPadding = totalPadding - leftPadding;
    return '${' ' * leftPadding}$content${' ' * rightPadding}';
  }
}

/// Horizontal alignment options for [Aligned] spans.
@experimental
enum HorizontalAlign { left, right, center }

/// {@template chirp.ClassName}
/// Renders a class name with optional instance hash.
///
/// The instance hash helps distinguish multiple instances of the same class
/// in logs, which is useful for tracking object lifecycles or debugging
/// concurrent operations.
///
/// Example output: `UserService` or `UserService@a1b2c3d4`
///
/// Use [ClassName.fromRecord] to automatically extract class name and hash
/// from a [LogRecord].
/// {@endtemplate}
@experimental
class ClassName extends LeafSpan {
  /// The class name, e.g., "UserService".
  final String name;

  /// Optional hex hash to distinguish instances, e.g., "a1b2c3d4".
  /// When present, output becomes "ClassName@hash".
  final String? instanceHash;

  /// {@macro chirp.ClassName}
  ClassName(this.name, {this.instanceHash});

  /// Creates a [ClassName] from a [LogRecord].
  ///
  /// Resolution logic:
  /// 1. If the record has an instance with a hash, uses the instance's runtime type
  ///    and includes the hash (formatted as hex digits with [hashLength])
  /// 2. Otherwise, if the record has caller info with a class name, uses that
  ///    without a hash
  /// 3. Otherwise, if the record has an instance (without hash), uses the instance's
  ///    runtime type without a hash
  /// 4. Returns null if no class name can be resolved
  ///
  /// The [hashLength] parameter controls how many hex characters to use for the
  /// instance hash (default: 8).
  ///
  /// This ensures that:
  /// - Instance type always matches the hash when both are present
  /// - Caller class names are shown without hash when no instance is present
  static ClassName? fromRecord(LogRecord record, {int hashLength = 8}) {
    // When we have an instance hash, prioritize the instance's type
    // to ensure the class name matches the hash
    if (record.instanceHash != null && record.instance != null) {
      final className = record.instance!.runtimeType.toString();
      final hashHex =
          record.instanceHash!.toRadixString(16).padLeft(hashLength, '0');
      // Take the last hashLength characters (handles overflow gracefully)
      final hash = hashHex.length > hashLength
          ? hashHex.substring(hashHex.length - hashLength)
          : hashHex;
      return ClassName(className, instanceHash: hash);
    }

    // Otherwise, try to get class name from caller (without hash)
    if (record.caller != null) {
      final callerInfo = getCallerInfo(record.caller!);
      if (callerInfo?.callerClassName != null) {
        return ClassName(callerInfo!.callerClassName!);
      }
    }

    // Fall back to instance type if available (without hash)
    if (record.instance != null) {
      final className = record.instance!.runtimeType.toString();
      return ClassName(className);
    }

    return null;
  }

  @override
  LogSpan build() {
    if (instanceHash != null) {
      return PlainText('$name@$instanceHash');
    }
    return PlainText(name);
  }

  @override
  String toString() => 'ClassName("$name", hash: $instanceHash)';
}

/// {@template chirp.MethodName}
/// Renders the method name where the log call originated.
///
/// Useful for understanding the call context without looking at stack traces.
///
/// Example output: `processOrder`, `handleRequest`
/// {@endtemplate}
@experimental
class MethodName extends LeafSpan {
  /// The method name, e.g., "processOrder".
  final String name;

  /// {@macro chirp.MethodName}
  MethodName(this.name);

  @override
  LogSpan build() => PlainText(name);

  @override
  String toString() => 'MethodName("$name")';
}

/// {@template chirp.BracketedLogLevel}
/// Renders the log severity level in brackets.
///
/// Example output: `[debug]`, `[info]`, `[warning]`, `[error]`
/// {@endtemplate}
@experimental
class BracketedLogLevel extends LeafSpan {
  /// The log level to render.
  final ChirpLogLevel level;

  /// {@macro chirp.BracketedLogLevel}
  BracketedLogLevel(this.level);

  @override
  LogSpan build() => PlainText('[${level.name}]');

  @override
  String toString() => 'BracketedLogLevel(${level.name})';
}

/// {@template chirp.LogMessage}
/// Renders the primary log message.
///
/// The [message] object is converted to a string via [Object.toString].
/// Returns [EmptySpan] if [message] is null or empty.
/// {@endtemplate}
@experimental
class LogMessage extends LeafSpan {
  /// The message object. Will be converted to string for display.
  final Object? message;

  /// {@macro chirp.LogMessage}
  LogMessage(this.message);

  @override
  LogSpan build() {
    final str = message?.toString() ?? '';
    if (str.isEmpty) return EmptySpan();
    return PlainText(str);
  }

  @override
  String toString() => 'LogMessage("$message")';
}

/// {@template chirp.DataKey}
/// Renders a single data key formatted for YAML output.
///
/// Keys containing whitespace or special characters are automatically quoted.
///
/// Example output: `userId`, `"key with spaces"`
/// {@endtemplate}
@experimental
class DataKey extends LeafSpan {
  /// The key to render.
  final Object? key;

  /// {@macro chirp.DataKey}
  DataKey(this.key);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(formatYamlKey(key));
  }

  @override
  String toString() => 'DataKey($key)';
}

/// {@template chirp.DataValue}
/// Renders a single data value formatted for YAML output.
///
/// Strings are quoted, null becomes "null", numbers and booleans render as-is.
///
/// Example output: `"hello"`, `42`, `true`, `null`
/// {@endtemplate}
@experimental
class DataValue extends LeafSpan {
  /// The value to render.
  final Object? value;

  /// {@macro chirp.DataValue}
  DataValue(this.value);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(formatYamlValue(value));
  }

  @override
  String toString() => 'DataValue($value)';
}

/// {@template chirp.InlineData}
/// Renders structured key-value data inline with the log message.
///
/// Output format: `key: value, key: value`
///
/// Use this for compact single-line output. For multi-line YAML format
/// that's easier to read with many fields, use [MultilineData] instead.
///
/// Returns [EmptySpan] if [data] is null or empty.
///
/// Example output: `userId: "abc123", action: "login"`
/// {@endtemplate}
@experimental
class InlineData extends LeafSpan {
  /// The structured data to render as inline key-value pairs.
  final Map<String, Object?>? data;

  /// Factory to create the span rendered between each key-value pair.
  ///
  /// Defaults to creating `PlainText(', ')`.
  final LogSpan Function() entrySeparatorBuilder;

  /// Factory to create the span rendered between the key and value.
  ///
  /// Defaults to creating `PlainText(': ')`.
  final LogSpan Function() keyValueSeparatorBuilder;

  /// {@macro chirp.InlineData}
  InlineData(
    this.data, {
    LogSpan Function()? entrySeparatorBuilder,
    LogSpan Function()? keyValueSeparatorBuilder,
  })  : entrySeparatorBuilder =
            entrySeparatorBuilder ?? (() => PlainText(', ')),
        keyValueSeparatorBuilder =
            keyValueSeparatorBuilder ?? (() => PlainText(': '));

  @override
  LogSpan build() {
    final d = data;
    if (d == null || d.isEmpty) return EmptySpan();

    final children = <LogSpan>[];
    for (final entry in d.entries) {
      children.add(
        SpanSequence(
          children: [
            DataKey(entry.key),
            keyValueSeparatorBuilder(),
            DataValue(entry.value),
          ],
        ),
      );
    }

    return SpanSequence(
      children: children,
      separator: entrySeparatorBuilder(),
    );
  }

  @override
  String toString() => 'InlineData($data)';
}

/// {@template chirp.MultilineData}
/// Renders structured key-value data in multi-line YAML format.
///
/// Use this when you have many data fields or nested structures that
/// benefit from vertical layout. For compact single-line output, use
/// [InlineData] instead.
///
/// Returns [EmptySpan] if [data] is null or empty.
///
/// Example output:
/// ```yaml
/// userId: abc123
/// action: login
/// metadata:
///   ip: 192.168.1.1
/// ```
/// {@endtemplate}
@experimental
class MultilineData extends LeafSpan {
  /// The structured data to render as multi-line YAML.
  final Map<String, Object?>? data;

  /// {@macro chirp.MultilineData}
  MultilineData(this.data);

  @override
  LogSpan build() {
    final d = data;
    if (d == null || d.isEmpty) return EmptySpan();
    final lines = formatAsYaml(d);
    return PlainText('\n${lines.join('\n')}');
  }

  @override
  String toString() => 'MultilineData($data)';
}

/// {@template chirp.ErrorSpan}
/// Renders an error or exception object.
///
/// The [error] is converted to string via [Object.toString].
/// Returns [EmptySpan] if [error] is null.
///
/// Typically used together with [StackTraceSpan] to show both the
/// error message and its stack trace.
/// {@endtemplate}
@experimental
class ErrorSpan extends LeafSpan {
  /// The error or exception to render.
  final Object? error;

  /// {@macro chirp.ErrorSpan}
  ErrorSpan(this.error);

  @override
  LogSpan build() {
    if (error == null) return EmptySpan();
    return PlainText(error.toString());
  }

  @override
  String toString() => 'ErrorSpan($error)';
}

/// {@template chirp.StackTraceSpan}
/// Renders a stack trace.
///
/// Typically used together with [ErrorSpan] to show both the error
/// message and where it occurred.
/// {@endtemplate}
@experimental
class StackTraceSpan extends LeafSpan {
  /// The stack trace to render.
  final StackTrace stackTrace;

  /// {@macro chirp.StackTraceSpan}
  StackTraceSpan(this.stackTrace);

  @override
  LogSpan build() {
    final text = stackTrace.toString();
    // Trim trailing newline to avoid extra blank line in output
    if (text.endsWith('\n')) {
      return PlainText(text.substring(0, text.length - 1));
    }
    return PlainText(text);
  }

  @override
  String toString() => 'StackTraceSpan(...)';
}

// =============================================================================
// Box span for ASCII borders
// =============================================================================

/// Border style for box spans.
@experimental
enum BoxBorderStyle { single, double, rounded, heavy, ascii }

/// Characters for drawing box borders.
///
/// Provides predefined border styles: [single], [double], [rounded],
/// [heavy], and [ascii].
@experimental
class BoxBorderChars {
  /// The character for the top-left corner.
  final String topLeft;

  /// The character for the top-right corner.
  final String topRight;

  /// The character for the bottom-left corner.
  final String bottomLeft;

  /// The character for the bottom-right corner.
  final String bottomRight;

  /// The character for horizontal lines.
  final String horizontal;

  /// The character for vertical lines.
  final String vertical;

  /// Creates a custom set of box border characters.
  const BoxBorderChars({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.horizontal,
    required this.vertical,
  });

  /// Single-line box drawing characters (─ │ ┌ ┐ └ ┘).
  static const single = BoxBorderChars(
    topLeft: '\u250c',
    topRight: '\u2510',
    bottomLeft: '\u2514',
    bottomRight: '\u2518',
    horizontal: '\u2500',
    vertical: '\u2502',
  );

  /// Double-line box drawing characters (═ ║ ╔ ╗ ╚ ╝).
  static const double = BoxBorderChars(
    topLeft: '\u2554',
    topRight: '\u2557',
    bottomLeft: '\u255a',
    bottomRight: '\u255d',
    horizontal: '\u2550',
    vertical: '\u2551',
  );

  /// Rounded corner box drawing characters (─ │ ╭ ╮ ╰ ╯).
  static const rounded = BoxBorderChars(
    topLeft: '\u256d',
    topRight: '\u256e',
    bottomLeft: '\u2570',
    bottomRight: '\u256f',
    horizontal: '\u2500',
    vertical: '\u2502',
  );

  /// Heavy/thick box drawing characters (━ ┃ ┏ ┓ ┗ ┛).
  static const heavy = BoxBorderChars(
    topLeft: '\u250f',
    topRight: '\u2513',
    bottomLeft: '\u2517',
    bottomRight: '\u251b',
    horizontal: '\u2501',
    vertical: '\u2503',
  );

  /// ASCII-only box characters (- | + + + +) for maximum compatibility.
  static const ascii = BoxBorderChars(
    topLeft: '+',
    topRight: '+',
    bottomLeft: '+',
    bottomRight: '+',
    horizontal: '-',
    vertical: '|',
  );

  /// Returns the [BoxBorderChars] for the given [style].
  static BoxBorderChars fromStyle(BoxBorderStyle style) {
    switch (style) {
      case BoxBorderStyle.single:
        return single;
      case BoxBorderStyle.double:
        return double;
      case BoxBorderStyle.rounded:
        return rounded;
      case BoxBorderStyle.heavy:
        return heavy;
      case BoxBorderStyle.ascii:
        return ascii;
    }
  }
}

/// A span that draws an ASCII box around its content.
///
/// Example:
/// ```dart
/// Bordered(
///   style: BoxBorderStyle.rounded,
///   borderColor: Ansi16.cyan,
///   child: PlainText('Hello, World!'),
/// )
/// ```
@experimental
class Bordered extends SingleChildSpan {
  /// The border style to use. Defaults to [BoxBorderStyle.single].
  final BoxBorderStyle style;

  /// The color for the border characters. If null, uses the default color.
  final ConsoleColor? borderColor;

  /// The padding (in spaces) between the border and the content.
  /// Defaults to 1.
  final int padding;

  /// Creates a bordered span around the [child] content.
  ///
  /// - [style] determines the border characters (single, double, rounded, etc.)
  /// - [borderColor] sets the ANSI color for the border
  /// - [padding] adds spacing between the border and content
  Bordered({
    super.child,
    this.style = BoxBorderStyle.single,
    this.borderColor,
    this.padding = 1,
  });

  @override
  void render(ConsoleMessageBuffer buffer) {
    final c = child;
    if (c == null) return;

    final temp = buffer.createChildBuffer();
    c.render(temp);
    final content = temp.toString();

    final lines = content.isEmpty ? <String>[] : content.split('\n');
    if (lines.isEmpty) return;

    final chars = BoxBorderChars.fromStyle(style);
    // Strip ANSI escape codes when calculating visible width
    final visibleWidths = lines.map((l) => stripAnsiCodes(l).length).toList();
    final maxWidth = visibleWidths.reduce((a, b) => a > b ? a : b);
    final paddingStr = ' ' * padding;
    final innerWidth = maxWidth + (padding * 2);

    // Top border
    buffer.write(
      chars.topLeft + chars.horizontal * innerWidth + chars.topRight,
      foreground: borderColor,
    );
    buffer.write('\n');

    // Content lines
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final visibleWidth = visibleWidths[i];
      final padAmount = maxWidth - visibleWidth;
      buffer.write(chars.vertical, foreground: borderColor);
      buffer.write(paddingStr + line + ' ' * padAmount + paddingStr);
      buffer.write(chars.vertical, foreground: borderColor);
      buffer.write('\n');
    }

    // Bottom border
    buffer.write(
      chars.bottomLeft + chars.horizontal * innerWidth + chars.bottomRight,
      foreground: borderColor,
    );
  }

  @override
  String toString() => 'Bordered(style: $style, child: $child)';
}

/// A span that renders the Chirp ASCII art logo.
@experimental
class ChirpLogo extends LeafSpan {
  /// Creates a Chirp logo span.
  ChirpLogo();

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write('''
 ██████╗██╗  ██╗██╗██████╗ ██████╗ 
██╔════╝██║  ██║██║██╔══██╗██╔══██╗
██║     ███████║██║██████╔╝██████╔╝
██║     ██╔══██║██║██╔══██╗██╔═══╝ 
╚██████╗██║  ██║██║██║  ██║██║     
 ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝     
''');
  }
}
