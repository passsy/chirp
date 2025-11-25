import 'package:chirp/chirp.dart';
import 'package:chirp/src/xterm_colors.g.dart';

/// Writes to console using print()
class ConsoleWriter implements ChirpWriter {
  final ConsoleMessageFormatter formatter;
  final void Function(String)? output;

  ConsoleWriter({ConsoleMessageFormatter? formatter, this.output})
      : formatter = formatter ?? RainbowMessageFormatter();

  @override
  void write(LogRecord record) {
    const bool consoleSupportsColors = true;
    final builder = ConsoleMessageBuffer(useColors: consoleSupportsColors);
    formatter.format(record, builder);
    final text = builder.build();

    if (output != null) {
      output!(text);
    } else {
      // ignore: avoid_print
      print(text);
    }
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
/// print(buffer.build()); // "Hello " in red, "World" in blue, "!" in red
/// ```
class ConsoleMessageBuffer {
  /// Whether to emit ANSI color codes.
  ///
  /// When false, all color operations are no-ops and output is plain text.
  final bool useColors;

  final List<(XtermColor?, XtermColor?)> _colorStack = [];

  ConsoleMessageBuffer({
    this.useColors = false,
  });

  final StringBuffer _buffer = StringBuffer();

  /// Pushes a color onto the stack and writes its ANSI escape code.
  ///
  /// The color remains active until [popColor] is called.
  /// Nested calls create a color stack - inner colors override outer ones.
  void pushColor({XtermColor? foreground, XtermColor? background}) {
    _colorStack.add((foreground, background));
    if (useColors) {
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
    if (useColors) {
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
  /// If [foreground] or [background] is provided and [useColors] is true,
  /// the value is wrapped with push/pop color calls.
  void write(Object? value, {XtermColor? foreground, XtermColor? background}) {
    if (useColors && (foreground != null || background != null)) {
      pushColor(foreground: foreground, background: background);
      _buffer.write(value ?? 'null');
      popColor();
    } else {
      _buffer.write(value);
    }
  }

  /// Returns the accumulated buffer contents as a string.
  String build() {
    return _buffer.toString();
  }

  /// Returns the visible length of the buffer contents, excluding ANSI codes.
  int get visibleLength => stripAnsiCodes(_buffer.toString()).length;

  /// Creates a new buffer with the same settings but empty contents.
  ///
  /// Useful for spans that need to pre-render children to measure them.
  ConsoleMessageBuffer createChildBuffer() {
    return ConsoleMessageBuffer(useColors: useColors);
  }

  /// Strips ANSI escape codes from a string.
  ///
  /// Useful for calculating visible text width when content may contain
  /// color codes or other terminal control sequences.
  static String stripAnsiCodes(String s) {
    var result = s;
    for (final pattern in _ansiPatterns) {
      result = result.replaceAll(pattern, '');
    }
    return result;
  }

  /// Returns the visible length of a string, excluding ANSI escape codes.
  static int visibleLengthOf(String s) {
    return stripAnsiCodes(s).length;
  }

  static final _ansiPatterns = [
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
}
