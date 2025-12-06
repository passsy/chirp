/// A color for console output, supporting both indexed (256-color) and RGB (truecolor) modes.
///
/// Use [IndexedColor] for the 256-color xterm palette, or [RgbColor] for
/// arbitrary 24-bit colors. For predefined colors, see [Ansi16] and [Ansi256].
///
/// ## Example
///
/// ```dart
/// // Using predefined colors
/// buffer.pushStyle(foreground: Ansi16.red);
/// buffer.pushStyle(foreground: Ansi256.orange1_214);
///
/// // Using indexed colors directly
/// buffer.pushStyle(foreground: IndexedColor(196)); // red
///
/// // Using RGB colors (truecolor)
/// buffer.pushStyle(foreground: RgbColor(255, 128, 0)); // orange
/// ```
sealed class ConsoleColor {
  const ConsoleColor();

  /// The red component (0-255).
  int get r;

  /// The green component (0-255).
  int get g;

  /// The blue component (0-255).
  int get b;
}

/// A color from the 256-color xterm palette.
///
/// Codes 0-15 are the standard ANSI colors (see [Ansi16]).
/// Codes 16-231 are a 6x6x6 color cube.
/// Codes 232-255 are a grayscale ramp.
///
/// For predefined colors with names, use [Ansi16] or [Ansi256].
class IndexedColor extends ConsoleColor {
  /// The color code (0-255).
  final int code;

  /// Creates an indexed color from a code (0-255).
  const IndexedColor(this.code)
      : assert(code >= 0 && code <= 255, 'Code must be 0-255');

  @override
  int get r => _getRgbFromCode(code).$1;

  @override
  int get g => _getRgbFromCode(code).$2;

  @override
  int get b => _getRgbFromCode(code).$3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IndexedColor && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'IndexedColor($code)';
}

/// The terminal's default foreground color.
///
/// Use this to represent "no custom color" - the terminal will use its default
/// foreground color. Writers should output `\x1B[39m` (reset foreground) or
/// simply omit color codes when encountering this value.
///
/// This is a singleton - all instances are identical.
class DefaultColor extends ConsoleColor {
  static const _instance = DefaultColor._();

  /// Creates a [DefaultColor] instance (singleton).
  factory DefaultColor() => _instance;

  const DefaultColor._();

  /// RGB values are not meaningful for default color, but required by the
  /// sealed class. Returns middle-gray as a placeholder.
  @override
  int get r => 128;

  @override
  int get g => 128;

  @override
  int get b => 128;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DefaultColor;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'DefaultColor()';
}

/// A 24-bit RGB color for truecolor terminals.
///
/// Allows specifying any color with red, green, and blue components (0-255 each).
/// Falls back to the closest 256-color or 16-color approximation on terminals
/// that don't support truecolor.
class RgbColor extends ConsoleColor {
  @override
  final int r;

  @override
  final int g;

  @override
  final int b;

  /// Creates an RGB color with components in the range 0-255.
  const RgbColor(this.r, this.g, this.b)
      : assert(r >= 0 && r <= 255, 'Red must be 0-255'),
        assert(g >= 0 && g <= 255, 'Green must be 0-255'),
        assert(b >= 0 && b <= 255, 'Blue must be 0-255');

  /// Creates an RGB color from a hex value (e.g., 0xFF8800 for orange).
  const RgbColor.hex(int hex)
      : r = (hex >> 16) & 0xFF,
        g = (hex >> 8) & 0xFF,
        b = hex & 0xFF;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RgbColor && r == other.r && g == other.g && b == other.b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'RgbColor($r, $g, $b)';
}

/// Computes RGB values for a 256-color code.
(int, int, int) _getRgbFromCode(int code) {
  // Standard colors 0-15: use predefined values
  if (code < 16) {
    return _standard16Colors[code];
  }

  // Color cube 16-231: 6x6x6 RGB cube
  if (code < 232) {
    final index = code - 16;
    final r = index ~/ 36;
    final g = (index % 36) ~/ 6;
    final b = index % 6;
    // Map 0-5 to 0, 95, 135, 175, 215, 255
    int toValue(int c) => c == 0 ? 0 : 55 + c * 40;
    return (toValue(r), toValue(g), toValue(b));
  }

  // Grayscale 232-255: 24 shades from dark to light
  final gray = 8 + (code - 232) * 10;
  return (gray, gray, gray);
}

/// Standard 16 ANSI colors (codes 0-15).
const _standard16Colors = <(int, int, int)>[
  (0, 0, 0), // 0: black
  (128, 0, 0), // 1: red (maroon)
  (0, 128, 0), // 2: green
  (128, 128, 0), // 3: yellow (olive)
  (0, 0, 128), // 4: blue (navy)
  (128, 0, 128), // 5: magenta (purple)
  (0, 128, 128), // 6: cyan (teal)
  (192, 192, 192), // 7: white (silver)
  (128, 128, 128), // 8: bright black (gray)
  (255, 0, 0), // 9: bright red
  (0, 255, 0), // 10: bright green (lime)
  (255, 255, 0), // 11: bright yellow
  (0, 0, 255), // 12: bright blue
  (255, 0, 255), // 13: bright magenta (fuchsia)
  (0, 255, 255), // 14: bright cyan (aqua)
  (255, 255, 255), // 15: bright white
];
