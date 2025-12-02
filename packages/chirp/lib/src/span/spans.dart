import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';

// =============================================================================
// Leaf Spans (no children)
// =============================================================================

/// A span that renders nothing.
///
/// Use this when a span conditionally has no output, similar to
/// Flutter's `SizedBox.shrink()`.
class EmptySpan extends LeafSpan {
  @override
  void render(ConsoleMessageBuffer buffer) {
    // Intentionally empty - renders nothing
  }

  @override
  String toString() => 'EmptySpan()';
}

/// Plain text span.
class PlainText extends LeafSpan {
  final String value;

  PlainText(this.value);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(value);
  }

  @override
  String toString() => 'PlainText("$value")';
}

/// A single space.
class Whitespace extends LeafSpan {
  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(' ');
  }

  @override
  String toString() => 'Whitespace()';
}

/// A line break.
class NewLine extends LeafSpan {
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

/// Applies foreground and/or background color to a child span.
class AnsiColored extends SingleChildSpan {
  final XtermColor? foreground;
  final XtermColor? background;

  AnsiColored({
    super.child,
    this.foreground,
    this.background,
  });

  @override
  void render(ConsoleMessageBuffer buffer) {
    final c = child;
    if (c == null) return;
    buffer.pushColor(foreground: foreground, background: background);
    c.render(buffer);
    buffer.popColor();
  }

  @override
  String toString() =>
      'AnsiColored(fg: $foreground, bg: $background, child: $child)';
}

// =============================================================================
// Multi Child Spans
// =============================================================================

/// A sequence of spans rendered sequentially.
class SpanSequence extends MultiChildSpan {
  SpanSequence([List<LogSpan>? children]) : super(children: children);

  @override
  void render(ConsoleMessageBuffer buffer) {
    for (final child in children) {
      child.render(buffer);
    }
  }

  @override
  String toString() => 'SpanSequence($children)';
}

// =============================================================================
// Slotted Spans
// =============================================================================

/// Renders a prefix and/or suffix around an optional child.
///
/// If [child] is null, renders nothing (empty).
/// If [child] is non-null, renders [prefix], [child], [suffix].
class Surrounded extends SlottedSpan {
  static const prefixSlot = 'prefix';
  static const childSlot = 'child';
  static const suffixSlot = 'suffix';

  LogSpan? get prefix => getSlot(prefixSlot);

  set prefix(LogSpan? v) => setSlot(prefixSlot, v);

  LogSpan? get child => getSlot(childSlot);

  set child(LogSpan? v) => setSlot(childSlot, v);

  LogSpan? get suffix => getSlot(suffixSlot);

  set suffix(LogSpan? v) => setSlot(suffixSlot, v);

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

/// Timestamp when the log was created.
///
/// Builds to [PlainText] with format "HH:mm:ss.mmm".
class Timestamp extends LeafSpan {
  final DateTime date;

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

/// Source code location (file and line).
///
/// Builds to [PlainText] with format "file:line" or [EmptySpan] if no file.
class DartSourceCodeLocation extends LeafSpan {
  final String? fileName;
  final int? line;

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

/// Logger name for named loggers.
///
/// Builds to [PlainText].
class LoggerName extends LeafSpan {
  final String name;

  LoggerName(this.name);

  @override
  LogSpan build() => PlainText(name);

  @override
  String toString() => 'LoggerName("$name")';
}

/// Class or instance name.
///
/// Builds to [PlainText] with format "ClassName" or "ClassName@hash".
class ClassName extends LeafSpan {
  final String name;
  final String? instanceHash;

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

/// Method name where the log was called.
///
/// Builds to [PlainText].
class MethodName extends LeafSpan {
  final String name;

  MethodName(this.name);

  @override
  LogSpan build() => PlainText(name);

  @override
  String toString() => 'MethodName("$name")';
}

/// Log severity level with brackets.
///
/// Builds to [PlainText] with format "[levelName]".
class BracketedLogLevel extends LeafSpan {
  final ChirpLogLevel level;

  BracketedLogLevel(this.level);

  @override
  LogSpan build() => PlainText('[${level.name}]');

  @override
  String toString() => 'BracketedLogLevel(${level.name})';
}

/// The primary log message.
///
/// Builds to [PlainText] or [EmptySpan] if message is null/empty.
class LogMessage extends LeafSpan {
  final Object? message;

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

/// Structured key-value data rendered inline: ` (key: value, key: value)`.
///
/// Builds to [PlainText] or [EmptySpan] if data is null/empty.
class InlineData extends LeafSpan {
  final Map<String, Object?>? data;

  InlineData(this.data);

  @override
  LogSpan build() {
    final d = data;
    if (d == null || d.isEmpty) return EmptySpan();
    final str = d.entries
        .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
        .join(', ');
    return PlainText(' ($str)');
  }

  @override
  String toString() => 'InlineData($data)';
}

/// Structured key-value data rendered as multiline YAML.
///
/// Builds to [PlainText] or [EmptySpan] if data is null/empty.
class MultilineData extends LeafSpan {
  final Map<String, Object?>? data;

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

/// Error object.
///
/// Builds to [PlainText] or [EmptySpan] if error is null.
class ErrorSpan extends LeafSpan {
  final Object? error;

  ErrorSpan(this.error);

  @override
  LogSpan build() {
    if (error == null) return EmptySpan();
    return PlainText(error.toString());
  }

  @override
  String toString() => 'ErrorSpan($error)';
}

/// Stack trace.
///
/// Builds to [PlainText].
class StackTraceSpan extends LeafSpan {
  final StackTrace stackTrace;

  StackTraceSpan(this.stackTrace);

  @override
  LogSpan build() => PlainText(stackTrace.toString());

  @override
  String toString() => 'StackTraceSpan(...)';
}

// =============================================================================
// Box span for ASCII borders
// =============================================================================

/// Border style for box spans.
enum BoxBorderStyle { single, double, rounded, heavy, ascii }

/// Characters for drawing box borders.
class BoxBorderChars {
  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;
  final String horizontal;
  final String vertical;

  const BoxBorderChars({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.horizontal,
    required this.vertical,
  });

  static const single = BoxBorderChars(
    topLeft: '\u250c',
    topRight: '\u2510',
    bottomLeft: '\u2514',
    bottomRight: '\u2518',
    horizontal: '\u2500',
    vertical: '\u2502',
  );

  static const double = BoxBorderChars(
    topLeft: '\u2554',
    topRight: '\u2557',
    bottomLeft: '\u255a',
    bottomRight: '\u255d',
    horizontal: '\u2550',
    vertical: '\u2551',
  );

  static const rounded = BoxBorderChars(
    topLeft: '\u256d',
    topRight: '\u256e',
    bottomLeft: '\u2570',
    bottomRight: '\u256f',
    horizontal: '\u2500',
    vertical: '\u2502',
  );

  static const heavy = BoxBorderChars(
    topLeft: '\u250f',
    topRight: '\u2513',
    bottomLeft: '\u2517',
    bottomRight: '\u251b',
    horizontal: '\u2501',
    vertical: '\u2503',
  );

  static const ascii = BoxBorderChars(
    topLeft: '+',
    topRight: '+',
    bottomLeft: '+',
    bottomRight: '+',
    horizontal: '-',
    vertical: '|',
  );

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
class Bordered extends SingleChildSpan {
  final BoxBorderStyle style;
  final XtermColor? borderColor;
  final int padding;

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
