import 'package:chirp/src/ansi/console_color.dart';

/// The standard 16 ANSI colors (codes 0-15).
///
/// These are the basic terminal colors that work on virtually all terminals.
/// Colors 0-7 are the normal colors, 8-15 are the "bright" variants.
///
/// Note: The exact appearance of these colors varies by terminal and theme.
/// For example, "red" (code 1) is typically a dark red/maroon, while
/// "brightRed" (code 9) is a vivid red.
///
/// ## Example
///
/// ```dart
/// buffer.pushStyle(foreground: Ansi16.red);
/// buffer.write('Error!');
/// buffer.popStyle();
/// ```
abstract final class Ansi16 {
  // Normal colors (0-7)

  /// Black (code 0) - #000000
  static const black = IndexedColor(0);

  /// Red/Maroon (code 1) - #800000
  static const red = IndexedColor(1);

  /// Green (code 2) - #008000
  static const green = IndexedColor(2);

  /// Yellow/Olive (code 3) - #808000
  static const yellow = IndexedColor(3);

  /// Blue/Navy (code 4) - #000080
  static const blue = IndexedColor(4);

  /// Magenta/Purple (code 5) - #800080
  static const magenta = IndexedColor(5);

  /// Cyan/Teal (code 6) - #008080
  static const cyan = IndexedColor(6);

  /// White/Silver (code 7) - #c0c0c0
  static const white = IndexedColor(7);

  // Bright colors (8-15)

  /// Bright Black/Gray (code 8) - #808080
  static const brightBlack = IndexedColor(8);

  /// Bright Red (code 9) - #ff0000
  static const brightRed = IndexedColor(9);

  /// Bright Green/Lime (code 10) - #00ff00
  static const brightGreen = IndexedColor(10);

  /// Bright Yellow (code 11) - #ffff00
  static const brightYellow = IndexedColor(11);

  /// Bright Blue (code 12) - #0000ff
  static const brightBlue = IndexedColor(12);

  /// Bright Magenta/Fuchsia (code 13) - #ff00ff
  static const brightMagenta = IndexedColor(13);

  /// Bright Cyan/Aqua (code 14) - #00ffff
  static const brightCyan = IndexedColor(14);

  /// Bright White (code 15) - #ffffff
  static const brightWhite = IndexedColor(15);

  // Convenience aliases

  /// Alias for [brightBlack] - Gray (code 8)
  static const gray = brightBlack;

  /// Alias for [brightBlack] - Grey (code 8)
  static const grey = brightBlack;
}
