import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:chirp/src/xterm_colors.g.dart';

/// Base class for all log spans.
///
/// Spans are composable building blocks for log output. Third-party developers
/// should extend this class to create custom spans.
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
///   LogSpan build() => Row([Text('$emoji '), child]);
/// }
/// ```
abstract class LogSpan {
  const LogSpan();

  /// Builds this span into another span (or itself for RenderSpans).
  LogSpan build();
}

/// A span that renders directly to a [ConsoleMessageBuilder].
///
/// Most spans should extend [LogSpan] and return composed spans from [build].
/// Only extend [RenderSpan] for primitive spans that write text directly.
abstract class RenderSpan extends LogSpan {
  const RenderSpan();

  @override
  LogSpan build() => this;

  /// Renders this span to the builder.
  void render(ConsoleMessageBuilder builder);
}

/// Renders a [LogSpan] tree to a [ConsoleMessageBuilder].
///
/// Repeatedly calls [LogSpan.build] until reaching a [RenderSpan],
/// then calls [RenderSpan.render].
void renderSpan(LogSpan span, ConsoleMessageBuilder builder) {
  var current = span;
  while (current is! RenderSpan) {
    current = current.build();
  }
  current.render(builder);
}

// =============================================================================
// Span interfaces for traversal
// =============================================================================

/// Interface for spans that have a single child.
///
/// Implement this to allow generic span traversal and transformation.
abstract interface class SingleChildSpan implements LogSpan{
  /// The child span (may be null for optional children like [Prefixed]).
  LogSpan? get child;
}

/// Interface for spans that have multiple children.
///
/// Implement this to allow generic span traversal and transformation.
abstract interface class MultiChildSpan implements LogSpan {
  /// The child spans.
  List<LogSpan> get children;
}

// =============================================================================
// Primitive RenderSpans
// =============================================================================

/// Plain text span.
class Text extends RenderSpan {
  final String value;

  const Text(this.value);

  @override
  void render(ConsoleMessageBuilder builder) {
    builder.write(value);
  }

  @override
  String toString() => 'Text("$value")';
}

/// A single space.
class Space extends RenderSpan {
  const Space();

  @override
  void render(ConsoleMessageBuilder builder) {
    builder.write(' ');
  }

  @override
  String toString() => 'Space()';
}

/// A line break.
class NewLine extends RenderSpan {
  const NewLine();

  @override
  void render(ConsoleMessageBuilder builder) {
    builder.write('\n');
  }

  @override
  String toString() => 'NewLine()';
}

/// A row of spans rendered sequentially.
class Row extends RenderSpan implements MultiChildSpan {
  @override
  final List<LogSpan> children;

  const Row(this.children);

  @override
  void render(ConsoleMessageBuilder builder) {
    for (final child in children) {
      renderSpan(child, builder);
    }
  }

  @override
  String toString() => 'Row($children)';
}

/// Applies foreground and/or background color to a child span.
///
/// Renders the child to plain text, then writes it with the specified colors.
class Styled extends RenderSpan implements SingleChildSpan {
  @override
  final LogSpan child;
  final XtermColor? foreground;
  final XtermColor? background;

  const Styled({
    required this.child,
    this.foreground,
    this.background,
  });

  @override
  void render(ConsoleMessageBuilder builder) {
    final temp = ConsoleMessageBuilder();
    renderSpan(child, temp);
    final text = temp.build();
    builder.write(text, foreground: foreground, background: background);
  }

  @override
  String toString() => 'Styled(fg: $foreground, bg: $background, child: $child)';
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
    if (child == null) return const Row([]);
    return Row([prefix, child!]);
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
    return Text('$hour:$minute:$second.$ms');
  }

  @override
  String toString() => 'Timestamp($date)';
}

/// Source code location (file and line).
class Location extends LogSpan {
  final String? fileName;
  final int? line;

  const Location({this.fileName, this.line});

  @override
  LogSpan build() {
    if (fileName == null) return const Text('');
    if (line != null) {
      return Text('$fileName:$line');
    }
    return Text(fileName!);
  }

  @override
  String toString() => 'Location($fileName:$line)';
}

/// Logger name for named loggers.
class LoggerName extends LogSpan {
  final String name;

  const LoggerName(this.name);

  @override
  LogSpan build() => Text(name);

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
      return Text('$name@$instanceHash');
    }
    return Text(name);
  }

  @override
  String toString() => 'ClassName("$name", hash: $instanceHash)';
}

/// Method name where the log was called.
class MethodName extends LogSpan {
  final String name;

  const MethodName(this.name);

  @override
  LogSpan build() => Text(name);

  @override
  String toString() => 'MethodName("$name")';
}

/// Log severity level.
class Level extends LogSpan {
  final ChirpLogLevel level;

  const Level(this.level);

  @override
  LogSpan build() => Text('[${level.name}]');

  @override
  String toString() => 'Level(${level.name})';
}

/// The primary log message.
class Message extends LogSpan {
  final Object? message;

  const Message(this.message);

  @override
  LogSpan build() => Text(message?.toString() ?? '');

  @override
  String toString() => 'Message("$message")';
}

/// Structured key-value data rendered inline: ` (key: value, key: value)`.
class InlineData extends LogSpan {
  final Map<String, Object?>? data;

  const InlineData(this.data);

  @override
  LogSpan build() {
    final d = data;
    if (d == null || d.isEmpty) return const Text('');
    final str = d.entries
        .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
        .join(', ');
    return Text(' ($str)');
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
    if (d == null || d.isEmpty) return const Text('');
    final lines = formatAsYaml(d, 0);
    return Text('\n${lines.join('\n')}');
  }

  @override
  String toString() => 'MultilineData($data)';
}

/// Error object.
class Error extends LogSpan {
  final Object? error;

  const Error(this.error);

  @override
  LogSpan build() {
    if (error == null) return const Text('');
    return Text(error.toString());
  }

  @override
  String toString() => 'Error($error)';
}

/// Stack trace.
class StackTraceSpan extends LogSpan {
  final StackTrace stackTrace;

  const StackTraceSpan(this.stackTrace);

  @override
  LogSpan build() => Text(stackTrace.toString());

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
class Box extends RenderSpan implements SingleChildSpan {
  @override
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
  void render(ConsoleMessageBuilder builder) {
    final temp = ConsoleMessageBuilder();
    renderSpan(child, temp);
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

  @override
  String toString() => 'Box(style: $style, child: $child)';
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
// Extension for span lists
// =============================================================================

extension LogSpanListExt on List<LogSpan> {
  Iterable<T> whereSpanType<T extends LogSpan>() => whereType<T>();

  List<LogSpan> removeSpanType<T extends LogSpan>() =>
      where((s) => s is! T).toList();

  List<LogSpan> mapSpanType<T extends LogSpan>(LogSpan Function(T) mapper) =>
      map((s) => s is T ? mapper(s) : s).toList();
}

// =============================================================================
// Span tree utilities
// =============================================================================

/// Result of finding a span in the tree.
class SpanMatch<T extends LogSpan> {
  /// The found span.
  final T span;

  /// Parent spans from root to immediate parent (does not include [span]).
  final List<LogSpan> parents;

  const SpanMatch(this.span, this.parents);

  @override
  String toString() => 'SpanMatch($span, parents: $parents)';
}

/// Finds the first span of type [T] in the tree and returns it with its parents.
///
/// Returns `null` if no span of type [T] is found.
/// The [parents] list contains the path from root to the found span (exclusive).
SpanMatch<T>? findSpan<T extends LogSpan>(LogSpan span) {
  return _findSpan<T>(span, []);
}

SpanMatch<T>? _findSpan<T extends LogSpan>(LogSpan span, List<LogSpan> parents) {
  // Found the target
  if (span is T) {
    return SpanMatch(span, parents);
  }

  final newParents = [...parents, span];

  // Handle MultiChildSpan (Row)
  if (span is MultiChildSpan) {
    for (final child in (span as MultiChildSpan).children) {
      final result = _findSpan<T>(child, newParents);
      if (result != null) return result;
    }
  }

  // Handle SingleChildSpan (Styled, Box, Prefixed)
  if (span is SingleChildSpan) {
    final child = (span as SingleChildSpan).child;
    if (child != null) {
      final result = _findSpan<T>(child, newParents);
      if (result != null) return result;
    }
  }

  // Handle Prefixed.prefix
  if (span is Prefixed) {
    final result = _findSpan<T>(span.prefix, newParents);
    if (result != null) return result;
  }

  return null;
}
