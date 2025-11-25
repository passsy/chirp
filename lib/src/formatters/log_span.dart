import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:chirp/src/xterm_colors.g.dart';

/// Base class for all log spans.
///
/// Spans are composable building blocks for log output. Each span knows how
/// to render itself to a [ConsoleMessageBuilder]. Third-party developers can
/// create custom spans by extending this class.
///
/// ## Example: Custom span
///
/// ```dart
/// class EmojiSpan extends LogSpan {
///   final String emoji;
///   final LogSpan child;
///
///   const EmojiSpan(this.emoji, {required this.child});
///
///   @override
///   void build(ConsoleMessageBuilder builder) {
///     builder.write('$emoji ');
///     child.build(builder);
///   }
/// }
/// ```
abstract class LogSpan {
  const LogSpan();

  /// Builds this span by writing to the builder.
  void build(ConsoleMessageBuilder builder);
}

/// Plain text span.
class Text extends LogSpan {
  final String value;

  const Text(this.value);

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write(value);
  }
}

/// Applies foreground and/or background color to a child span.
///
/// Renders the child to plain text, then writes it with the specified colors.
class Styled extends LogSpan {
  final LogSpan child;
  final XtermColor? foreground;
  final XtermColor? background;

  const Styled({
    required this.child,
    this.foreground,
    this.background,
  });

  @override
  void build(ConsoleMessageBuilder builder) {
    // Render child to plain text
    final temp = ConsoleMessageBuilder();
    child.build(temp);
    final text = temp.build();

    // Write with our colors
    builder.write(text, foreground: foreground, background: background);
  }
}

/// A row of spans rendered sequentially.
class Row extends LogSpan {
  final List<LogSpan> children;

  const Row(this.children);

  @override
  void build(ConsoleMessageBuilder builder) {
    for (final child in children) {
      child.build(builder);
    }
  }
}

/// A single space.
class Space extends LogSpan {
  const Space();

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write(' ');
  }
}

/// A line break.
class NewLine extends LogSpan {
  const NewLine();

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write('\n');
  }
}

/// Renders a prefix before an optional child.
///
/// If [child] is null, nothing is rendered.
/// If [child] is non-null, renders [prefix] then [child].
class Prefixed extends LogSpan {
  final LogSpan prefix;
  final LogSpan? child;

  const Prefixed({required this.prefix, this.child});

  @override
  void build(ConsoleMessageBuilder builder) {
    if (child == null) return;
    prefix.build(builder);
    child!.build(builder);
  }
}

// =============================================================================
// Semantic spans - these mark specific types of log content
// =============================================================================

/// Timestamp when the log was created.
class Timestamp extends LogSpan {
  final DateTime date;

  const Timestamp(this.date);

  @override
  void build(ConsoleMessageBuilder builder) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    builder.write('$hour:$minute:$second.$ms');
  }
}

/// Source code location (file and line).
class Location extends LogSpan {
  final String? fileName;
  final int? line;

  const Location({this.fileName, this.line});

  @override
  void build(ConsoleMessageBuilder builder) {
    if (fileName == null) return;
    if (line != null) {
      builder.write('$fileName:$line');
    } else {
      builder.write(fileName);
    }
  }
}

/// Logger name for named loggers.
class LoggerName extends LogSpan {
  final String name;

  const LoggerName(this.name);

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write(name);
  }
}

/// Class or instance name.
class ClassName extends LogSpan {
  final String name;
  final String? instanceHash;

  const ClassName(this.name, {this.instanceHash});

  @override
  void build(ConsoleMessageBuilder builder) {
    if (instanceHash != null) {
      builder.write('$name@$instanceHash');
    } else {
      builder.write(name);
    }
  }
}

/// Method name where the log was called.
class MethodName extends LogSpan {
  final String name;

  const MethodName(this.name);

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write(name);
  }
}

/// Log severity level.
class Level extends LogSpan {
  final ChirpLogLevel level;

  const Level(this.level);

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write('[${level.name}]');
  }
}

/// The primary log message.
class Message extends LogSpan {
  final Object? message;

  const Message(this.message);

  @override
  void build(ConsoleMessageBuilder builder) {
    builder.write(message?.toString() ?? '');
  }
}

/// Structured key-value data rendered inline: ` (key: value, key: value)`.
class InlineData extends LogSpan {
  final Map<String, Object?>? data;

  const InlineData(this.data);

  @override
  void build(ConsoleMessageBuilder builder) {
    final d = data;
    if (d == null || d.isEmpty) return;
    final str = d.entries
        .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
        .join(', ');
    builder.write(' ($str)');
  }
}

/// Structured key-value data rendered as multiline YAML.
class MultilineData extends LogSpan {
  final Map<String, Object?>? data;

  const MultilineData(this.data);

  @override
  void build(ConsoleMessageBuilder builder) {
    final d = data;
    if (d == null || d.isEmpty) return;
    final lines = formatAsYaml(d, 0);
    for (final line in lines) {
      builder.write('\n$line');
    }
  }
}

/// Error object.
class Error extends LogSpan {
  final Object? error;

  const Error(this.error);

  @override
  void build(ConsoleMessageBuilder builder) {
    if (error == null) return;
    builder.write(error.toString());
  }
}

/// Stack trace.
class StackTraceSpan extends LogSpan {
  final StackTrace? stackTrace;

  const StackTraceSpan(this.stackTrace);

  @override
  void build(ConsoleMessageBuilder builder) {
    if (stackTrace == null) return;
    builder.write(stackTrace.toString());
  }
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
class Box extends LogSpan {
  final LogSpan child;
  final BoxBorderStyle style;
  final XtermColor? borderColor;
  final int padding;

  const Box({
    required this.child,
    this.style = BoxBorderStyle.single,
    this.borderColor,
    this.padding = 1,
  });

  @override
  void build(ConsoleMessageBuilder builder) {
    final temp = ConsoleMessageBuilder();
    child.build(temp);
    final content = temp.build();

    final lines = content.isEmpty ? <String>[] : content.split('\n');
    if (lines.isEmpty) return;

    final chars = BoxBorderChars.fromStyle(style);
    final maxWidth =
        lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
    final paddingStr = ' ' * padding;
    final innerWidth = maxWidth + (padding * 2);

    // Top border
    builder.write(
      chars.topLeft + chars.horizontal * innerWidth + chars.topRight,
      foreground: borderColor,
    );
    builder.write('\n');

    // Content lines
    for (final line in lines) {
      builder.write(chars.vertical, foreground: borderColor);
      builder.write(paddingStr + line.padRight(maxWidth) + paddingStr);
      builder.write(chars.vertical, foreground: borderColor);
      builder.write('\n');
    }

    // Bottom border
    builder.write(
      chars.bottomLeft + chars.horizontal * innerWidth + chars.bottomRight,
      foreground: borderColor,
    );
  }
}

// =============================================================================
// Span transformer
// =============================================================================

/// Callback type for transforming log spans before rendering.
typedef SpanTransformer = LogSpan Function(
  LogSpan span,
  LogRecord record,
);

// =============================================================================
// Extension for rendering span lists
// =============================================================================

extension LogSpanListExt on List<LogSpan> {
  void renderTo(ConsoleMessageBuilder builder) {
    for (final span in this) {
      span.build(builder);
    }
  }

  Iterable<T> whereSpanType<T extends LogSpan>() => whereType<T>();

  List<LogSpan> removeSpanType<T extends LogSpan>() =>
      where((s) => s is! T).toList();

  List<LogSpan> mapSpanType<T extends LogSpan>(LogSpan Function(T) mapper) =>
      map((s) => s is T ? mapper(s) : s).toList();
}
