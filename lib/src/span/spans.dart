import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:chirp/src/xterm_colors.g.dart';

// =============================================================================
// Primitive RenderSpans
// =============================================================================

/// Plain text span.
class PlainText extends RenderSpan {
  final String value;

  const PlainText(this.value);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(value);
  }

  @override
  String toString() => 'PlainText("$value")';
}

/// A single space.
class Whitespace extends RenderSpan {
  const Whitespace();

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write(' ');
  }

  @override
  String toString() => 'Whitespace()';
}

/// A line break.
class NewLine extends RenderSpan {
  const NewLine();

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write('\n');
  }

  @override
  String toString() => 'NewLine()';
}

/// A sequence of spans rendered sequentially.
class SpanSequence extends RenderSpan implements MultiChildSpan {
  @override
  final List<LogSpan> children;

  const SpanSequence(this.children);

  @override
  void render(ConsoleMessageBuffer buffer) {
    for (final child in children) {
      renderSpan(child, buffer);
    }
  }

  @override
  String toString() => 'SpanSequence($children)';
}

/// Applies foreground and/or background color to a child span.
///
/// Renders the child to plain text, then writes it with the specified colors.
class AnsiColored extends RenderSpan implements SingleChildSpan {
  @override
  final LogSpan child;
  final XtermColor? foreground;
  final XtermColor? background;

  const AnsiColored({
    required this.child,
    this.foreground,
    this.background,
  });

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.pushColor(foreground: foreground, background: background);
    renderSpan(child, buffer);
    buffer.popColor();
  }

  @override
  String toString() =>
      'AnsiColored(fg: $foreground, bg: $background, child: $child)';
}

// =============================================================================
// Composite LogSpans
// =============================================================================

/// Renders a prefix before an optional child.
///
/// If [child] is null, builds to an empty [Row].
/// If [child] is non-null, builds to [Row] with [prefix] then [child].
class Prefixed extends LogSpan implements SingleChildSpan {
  final LogSpan prefix;
  @override
  final LogSpan? child;

  const Prefixed({required this.prefix, this.child});

  @override
  LogSpan build() {
    if (child == null) return const SpanSequence([]);
    return SpanSequence([prefix, child!]);
  }

  @override
  String toString() => 'Prefixed(prefix: $prefix, child: $child)';
}

// =============================================================================
// Semantic spans - these mark specific types of log content
// =============================================================================

/// Timestamp when the log was created.
class Timestamp extends LogSpan {
  final DateTime date;

  const Timestamp(this.date);

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
class DartSourceCodeLocation extends LogSpan {
  final String? fileName;
  final int? line;

  const DartSourceCodeLocation({this.fileName, this.line});

  @override
  LogSpan build() {
    if (fileName == null) return const PlainText('');
    if (line != null) {
      return PlainText('$fileName:$line');
    }
    return PlainText(fileName!);
  }

  @override
  String toString() => 'DartSourceCodeLocation($fileName:$line)';
}

/// Logger name for named loggers.
class LoggerName extends LogSpan {
  final String name;

  const LoggerName(this.name);

  @override
  LogSpan build() => PlainText(name);

  @override
  String toString() => 'LoggerName("$name")';
}

/// Class or instance name.
class ClassName extends LogSpan {
  final String name;
  final String? instanceHash;

  const ClassName(this.name, {this.instanceHash});

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
class MethodName extends LogSpan {
  final String name;

  const MethodName(this.name);

  @override
  LogSpan build() => PlainText(name);

  @override
  String toString() => 'MethodName("$name")';
}

/// Log severity level with brackets.
class BracketedLogLevel extends LogSpan {
  final ChirpLogLevel level;

  const BracketedLogLevel(this.level);

  @override
  LogSpan build() => PlainText('[${level.name}]');

  @override
  String toString() => 'BracketedLogLevel(${level.name})';
}

/// The primary log message.
class LogMessage extends LogSpan {
  final Object? message;

  const LogMessage(this.message);

  @override
  LogSpan build() => PlainText(message?.toString() ?? '');

  @override
  String toString() => 'LogMessage("$message")';
}

/// Structured key-value data rendered inline: ` (key: value, key: value)`.
class InlineData extends LogSpan {
  final Map<String, Object?>? data;

  const InlineData(this.data);

  @override
  LogSpan build() {
    final d = data;
    if (d == null || d.isEmpty) return const PlainText('');
    final str = d.entries
        .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
        .join(', ');
    return PlainText(' ($str)');
  }

  @override
  String toString() => 'InlineData($data)';
}

/// Structured key-value data rendered as multiline YAML.
class MultilineData extends LogSpan {
  final Map<String, Object?>? data;

  const MultilineData(this.data);

  @override
  LogSpan build() {
    final d = data;
    if (d == null || d.isEmpty) return const PlainText('');
    final lines = formatAsYaml(d, 0);
    return PlainText('\n${lines.join('\n')}');
  }

  @override
  String toString() => 'MultilineData($data)';
}

/// Error object.
class ErrorSpan extends LogSpan {
  final Object? error;

  const ErrorSpan(this.error);

  @override
  LogSpan build() {
    if (error == null) return const PlainText('');
    return PlainText(error.toString());
  }

  @override
  String toString() => 'ErrorSpan($error)';
}

/// Stack trace.
class StackTraceSpan extends LogSpan {
  final StackTrace stackTrace;

  const StackTraceSpan(this.stackTrace);

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
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
    horizontal: '─',
    vertical: '│',
  );

  static const double = BoxBorderChars(
    topLeft: '╔',
    topRight: '╗',
    bottomLeft: '╚',
    bottomRight: '╝',
    horizontal: '═',
    vertical: '║',
  );

  static const rounded = BoxBorderChars(
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
    horizontal: '─',
    vertical: '│',
  );

  static const heavy = BoxBorderChars(
    topLeft: '┏',
    topRight: '┓',
    bottomLeft: '┗',
    bottomRight: '┛',
    horizontal: '━',
    vertical: '┃',
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
class Bordered extends RenderSpan implements SingleChildSpan {
  @override
  final LogSpan child;
  final BoxBorderStyle style;
  final XtermColor? borderColor;
  final int padding;

  const Bordered({
    required this.child,
    this.style = BoxBorderStyle.single,
    this.borderColor,
    this.padding = 1,
  });

  @override
  void render(ConsoleMessageBuffer buffer) {
    final temp = buffer.createChildBuffer();
    renderSpan(child, temp);
    final content = temp.build();

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
