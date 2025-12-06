/// Levels of terminal color support.
///
/// Based on https://github.com/webdiscus/ansis/blob/master/src/color-support.js
enum TerminalColorSupport {
  /// No color support - plain text output only.
  none,

  /// Basic 16 ANSI colors (standard + bright variants).
  ///
  /// Uses escape codes like `\x1B[31m` (red) or `\x1B[91m` (bright red).
  ansi16,

  /// Extended 256-color palette (xterm colors).
  ///
  /// Uses escape codes like `\x1B[38;5;196m` (color index 196).
  /// Includes the 16 basic colors, a 6x6x6 color cube, and 24 grayscale shades.
  ansi256,

  /// True color / 24-bit RGB support (16.7 million colors).
  ///
  /// Uses escape codes like `\x1B[38;2;255;128;0m` (RGB values).
  truecolor;

  /// Whether any color output is supported.
  bool get supportsColors => this != none;

  /// Whether 256-color mode is supported.
  bool get supports256 => index >= ansi256.index;

  /// Whether true color (24-bit RGB) is supported.
  bool get supportsTruecolor => index >= truecolor.index;
}
