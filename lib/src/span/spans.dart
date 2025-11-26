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
class Timestamp extends LeafSpan {
  final DateTime date;

  Timestamp(this.date);

  @override
  void render(ConsoleMessageBuffer buffer) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    buffer.write('$hour:$minute:$second.$ms');
  }

  @override
  String toString() => 'Timestamp($date)';
}

/// Source code location (file and line).
class DartSourceCodeLocation extends LeafSpan {
  final String? fileName;
  final int? line;

  DartSourceCodeLocation({this.fileName, this.line});

  @override
  void render(ConsoleMessageBuffer buffer) {
    if (fileName == null) return;
    if (line != null) {
      buffer.write('$fileName:$line');
    } else {
      buffer.write(fileName);
    }
  }

  @override
  String toString() => 'DartSourceCodeLocation($fileName:$line)';
}

/// Logger name for named loggers.
class LoggerName extends LeafSpan {
  final String name;

  LoggerName(this.name);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(name);
  }

  @override
  String toString() => 'LoggerName("$name")';
}

/// Class or instance name.
class ClassName extends LeafSpan {
  final String name;
  final String? instanceHash;

  ClassName(this.name, {this.instanceHash});

  @override
  void render(ConsoleMessageBuffer buffer) {
    if (instanceHash != null) {
      buffer.write('$name@$instanceHash');
    } else {
      buffer.write(name);
    }
  }

  @override
  String toString() => 'ClassName("$name", hash: $instanceHash)';
}

/// Method name where the log was called.
class MethodName extends LeafSpan {
  final String name;

  MethodName(this.name);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(name);
  }

  @override
  String toString() => 'MethodName("$name")';
}

/// Log severity level with brackets.
class BracketedLogLevel extends LeafSpan {
  final ChirpLogLevel level;

  BracketedLogLevel(this.level);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write('[${level.name}]');
  }

  @override
  String toString() => 'BracketedLogLevel(${level.name})';
}

/// The primary log message.
class LogMessage extends LeafSpan {
  final Object? message;

  LogMessage(this.message);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(message?.toString() ?? '');
  }

  @override
  String toString() => 'LogMessage("$message")';
}

/// Structured key-value data rendered inline: ` (key: value, key: value)`.
class InlineData extends LeafSpan {
  final Map<String, Object?>? data;

  InlineData(this.data);

  @override
  void render(ConsoleMessageBuffer buffer) {
    final d = data;
    if (d == null || d.isEmpty) return;
    final str = d.entries
        .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
        .join(', ');
    buffer.write(' ($str)');
  }

  @override
  String toString() => 'InlineData($data)';
}

/// Structured key-value data rendered as multiline YAML.
class MultilineData extends LeafSpan {
  final Map<String, Object?>? data;

  MultilineData(this.data);

  @override
  void render(ConsoleMessageBuffer buffer) {
    final d = data;
    if (d == null || d.isEmpty) return;
    final lines = formatAsYaml(d, 0);
    buffer.write('\n${lines.join('\n')}');
  }

  @override
  String toString() => 'MultilineData($data)';
}

/// Error object.
class ErrorSpan extends LeafSpan {
  final Object? error;

  ErrorSpan(this.error);

  @override
  void render(ConsoleMessageBuffer buffer) {
    if (error == null) return;
    buffer.write(error.toString());
  }

  @override
  String toString() => 'ErrorSpan($error)';
}

/// Stack trace.
class StackTraceSpan extends LeafSpan {
  final StackTrace stackTrace;

  StackTraceSpan(this.stackTrace);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(stackTrace.toString());
  }

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
    final visibleWidths =
        lines.map(ConsoleMessageBuffer.visibleLengthOf).toList();
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
