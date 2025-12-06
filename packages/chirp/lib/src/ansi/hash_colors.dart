import 'dart:math' as math;

import 'package:chirp/chirp.dart';
import 'package:chirp/src/ansi/readable_colors.g.dart';
import 'package:chirp/src/platform/platform_info.dart';

/// Color palette intensity for hash-based color selection, see [colorForHash]
enum ColorSaturation { high, mid, low }

/// Selects a readable color for [object] based on terminal capabilities.
///
/// This is the main entry point for hash-based color selection. It automatically
/// chooses the best algorithm based on terminal color support:
///
/// - **No color support**: Returns [DefaultColor] (terminal's default foreground)
/// - **ANSI 16 colors**: Returns an [IndexedColor] from the basic 16-color palette
/// - **256-color terminals**: Returns an [IndexedColor] from curated readable colors
/// - **Truecolor terminals**: Returns an [RgbColor] with HSL variance (~7300 variations)
///
/// ## Example
///
/// ```dart
/// final colorSupport = detectTerminalColorSupport();
///
/// // For logger names (vibrant colors)
/// final color = hashColorForTerminal('MyLogger', ColorPalette.vibrant, colorSupport);
///
/// // For class names (subtle colors)
/// final color = hashColorForTerminal('MyClass', ColorPalette.subtle, colorSupport);
///
/// // For method names (muted colors)
/// final color = hashColorForTerminal('myMethod', ColorPalette.muted, colorSupport);
/// ```
///
/// All returned colors are guaranteed to be readable on both light and dark
/// terminal backgrounds.
///
/// See also:
/// - [hashColorAnsi256] for direct 256-color selection with custom palette
/// - [hashColorTruecolor] for direct truecolor selection with custom palette
/// - [readableColors] for the curated color palettes
ConsoleColor colorForHash(
  Object? object, {
  ColorSaturation? saturation,
  TerminalColorSupport? colorSupport,
}) {
  List<IndexedColor> colorPalette() {
    if (saturation == null) {
      return [
        ...readableColorsLowSaturation,
        ...readableColorsMediumSaturation
      ];
    }
    return switch (saturation) {
      ColorSaturation.low => readableColorsLowSaturation,
      ColorSaturation.mid => readableColorsMediumSaturation,
      ColorSaturation.high => readableColorsHighSaturation,
    };
  }

  final support = colorSupport ?? platformColorSupport;
  return switch (support) {
    TerminalColorSupport.none => DefaultColor(),
    TerminalColorSupport.ansi16 => _hashColorAnsi16(object),
    TerminalColorSupport.ansi256 => hashColorAnsi256(object, colorPalette()),
    TerminalColorSupport.truecolor =>
      hashColorTruecolor(object, colorPalette()),
  };
}

IndexedColor _hashColorAnsi16(Object? object) {
  final hash = object.hashCode.abs();

  /// Those are the readable ansi 16 colors, no black/white, not close to red
  const colors = [
    Ansi16.green,
    Ansi16.blue,
    Ansi16.magenta,
    Ansi16.cyan,
    Ansi16.brightGreen,
    Ansi16.brightBlue,
    Ansi16.brightMagenta,
    Ansi16.brightCyan,
  ];

  return colors[hash % colors.length];
}

/// Selects a color from [colors] based on the hash of [object].
///
/// For 256-color terminals, returns an [IndexedColor] from the curated palette.
/// This ensures the color is always readable on both light and dark backgrounds.
///
/// See also:
/// - [colorForHash] for automatic selection based on terminal support
/// - [hashColorTruecolor] for truecolor terminals with more color variation
/// - [readableColors], [readableColorsHighSaturation], etc. for curated palettes
IndexedColor hashColorAnsi256(Object? object, List<IndexedColor> colors) {
  final hash = object.hashCode.abs();
  if (colors.isEmpty) throw ArgumentError('colors must not be empty');
  return colors[hash % colors.length];
}

/// Selects a color with variance for truecolor terminals.
///
/// This function provides ~7300 distinct color variations while maintaining
/// readability on both light and dark terminal backgrounds.
///
/// ## How it works
///
/// 1. **Base color selection**: Picks a color from [colors] (curated readable
///    colors that pass contrast and color-distance checks)
///
/// 2. **HSL variance**: Applies small random variations to saturation (±10%)
///    and lightness (±10%) based on different bits of the hash
///
/// 3. **Guardrails**: Clamps lightness to 42-62% to prevent colors from
///    becoming too light (unreadable on white) or too dark (unreadable on black)
///
/// 4. **Retry mechanism**: If the resulting color fails readability checks
///    (too close to red/yellow, insufficient contrast), tries up to 3 more
///    times with modified hash values. Falls back to the base color if all
///    retries fail.
///
/// ## Readability criteria
///
/// Colors must meet these thresholds (same as readable_colors.g.dart):
/// - CIEDE2000 distance to red (128,0,0) > 30
/// - CIEDE2000 distance to yellow (128,128,0) > 30
/// - WCAG contrast ratio on white background ≥ 2.12
/// - WCAG contrast ratio on black background ≥ 3.1
///
/// ## Performance
///
/// - ~88% of colors pass on first try (0 retries)
/// - ~10% need 1 retry
/// - ~1.5% need 2 retries
/// - ~0.08% need 3 retries
/// - Average: 0.14 retries per color
///
/// ## Example
///
/// ```dart
/// // For logger names (vibrant colors)
/// final color = hashColorTruecolor('MyLogger', readableColorsHighSaturation);
///
/// // For class names (subtle colors)
/// final color = hashColorTruecolor('MyClass', readableColorsLowSaturation);
/// ```
///
/// ## When to use
///
/// - Use [hashColorTruecolor] when the terminal supports truecolor (24-bit RGB)
///   for maximum color variety
/// - Use [hashColorAnsi256] for 256-color terminals or when you need guaranteed
///   indexed colors without any runtime validation
///
/// See also:
/// - [colorForHash] for automatic selection based on terminal support
/// - [hashColorAnsi256] for 256-color terminals
/// - [readableColors] for the curated color palettes
RgbColor hashColorTruecolor(Object? object, List<IndexedColor> colors) {
  if (colors.isEmpty) throw ArgumentError('colors must not be empty');

  var hash = object.hashCode.abs();

  for (var retry = 0; retry < 4; retry++) {
    final baseColor = colors[hash % colors.length];
    final (h, s, l) = _rgbToHsl(baseColor.r, baseColor.g, baseColor.b);

    // Apply variance based on different bits of hash
    // Range: -0.10 to +0.10 (±10%)
    final sVariance = ((hash >> 8) % 21 - 10) / 100;
    final lVariance = ((hash >> 16) % 21 - 10) / 100;

    // Apply guardrails to keep colors readable
    final newS = (s + sVariance).clamp(0.10, 0.95);
    final newL = (l + lVariance).clamp(0.42, 0.62);

    final (r, g, b) = _hslToRgb(h, newS, newL);
    final color = RgbColor(r, g, b);

    if (_isColorReadable(r, g, b)) {
      return color;
    }

    // Try different hash for next iteration
    hash = (hash + 1) * 31;
  }

  // Fallback: return base color unchanged (clamped to guardrails)
  final baseColor = colors[object.hashCode.abs() % colors.length];
  final (h, s, l) = _rgbToHsl(baseColor.r, baseColor.g, baseColor.b);
  final (r, g, b) = _hslToRgb(h, s.clamp(0.10, 0.95), l.clamp(0.42, 0.62));
  return RgbColor(r, g, b);
}

// =============================================================================
// HSL color conversion utilities
// =============================================================================

/// Converts RGB (0-255) to HSL (h: 0-360, s: 0-1, l: 0-1).
(double h, double s, double l) _rgbToHsl(int r, int g, int b) {
  final rf = r / 255;
  final gf = g / 255;
  final bf = b / 255;

  final maxC = math.max(rf, math.max(gf, bf));
  final minC = math.min(rf, math.min(gf, bf));
  final delta = maxC - minC;

  double h = 0;
  double s = 0;
  final l = (maxC + minC) / 2;

  if (delta != 0) {
    s = l > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC);

    if (maxC == rf) {
      h = ((gf - bf) / delta) + (gf < bf ? 6 : 0);
    } else if (maxC == gf) {
      h = ((bf - rf) / delta) + 2;
    } else {
      h = ((rf - gf) / delta) + 4;
    }
    h *= 60;
  }

  return (h, s, l);
}

/// Converts HSL (h: 0-360, s: 0-1, l: 0-1) to RGB (0-255).
(int r, int g, int b) _hslToRgb(double h, double s, double l) {
  if (s == 0) {
    final grey = (l * 255).round();
    return (grey, grey, grey);
  }

  double hueToRgb(double p, double q, double t) {
    var tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  final hNorm = h / 360;

  final r = (hueToRgb(p, q, hNorm + 1 / 3) * 255).round().clamp(0, 255);
  final g = (hueToRgb(p, q, hNorm) * 255).round().clamp(0, 255);
  final b = (hueToRgb(p, q, hNorm - 1 / 3) * 255).round().clamp(0, 255);

  return (r, g, b);
}

// =============================================================================
// Color readability validation
// =============================================================================

/// Readability thresholds (same as readable_colors.g.dart)
const double _minContrastDark = 3.1;
const double _minContrastLight = 2.12;
const double _minDistanceToRed = 30.0;
const double _minDistanceToYellow = 30.0;

/// Checks if a color meets readability criteria.
///
/// A color is readable if it has sufficient contrast on both light and dark
/// backgrounds, and is not too close to red (error) or yellow (warning) colors.
bool _isColorReadable(int r, int g, int b) {
  // Check contrast ratios
  final luminance = _relativeLuminance(r, g, b);
  final contrastOnWhite = _contrastRatio(luminance, 1.0);
  final contrastOnBlack = _contrastRatio(luminance, 0.0);

  if (contrastOnWhite < _minContrastLight) return false;
  if (contrastOnBlack < _minContrastDark) return false;

  // Check distance to red and yellow
  final lab = _rgbToLab(r, g, b);
  const redLab = (31.33, 51.14, 44.23); // Pre-computed for RGB(128,0,0)
  const yellowLab = (51.87, -7.83, 55.44); // Pre-computed for RGB(128,128,0)

  if (_ciede2000(lab, redLab) <= _minDistanceToRed) return false;
  if (_ciede2000(lab, yellowLab) <= _minDistanceToYellow) return false;

  return true;
}

/// Calculates relative luminance (WCAG 2.0).
double _relativeLuminance(int r, int g, int b) {
  double linearize(int c) {
    final v = c / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

/// Calculates WCAG contrast ratio between two luminance values.
double _contrastRatio(double l1, double l2) {
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Converts RGB to CIELAB color space.
(double L, double a, double b) _rgbToLab(int r, int g, int b) {
  // RGB to XYZ
  double pivotRgb(double n) {
    final v = n / 255.0;
    return v > 0.04045
        ? math.pow((v + 0.055) / 1.055, 2.4).toDouble()
        : v / 12.92;
  }

  final rLinear = pivotRgb(r.toDouble()) * 100;
  final gLinear = pivotRgb(g.toDouble()) * 100;
  final bLinear = pivotRgb(b.toDouble()) * 100;

  // Observer = 2°, Illuminant = D65
  final x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375;
  final y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750;
  final z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041;

  // XYZ to Lab
  const refX = 95.047;
  const refY = 100.000;
  const refZ = 108.883;

  double pivotXyz(double n) {
    return n > 0.008856
        ? math.pow(n, 1.0 / 3.0).toDouble()
        : (7.787 * n) + (16.0 / 116.0);
  }

  final xPivot = pivotXyz(x / refX);
  final yPivot = pivotXyz(y / refY);
  final zPivot = pivotXyz(z / refZ);

  return (
    (116.0 * yPivot) - 16.0,
    500.0 * (xPivot - yPivot),
    200.0 * (yPivot - zPivot),
  );
}

/// Calculates CIEDE2000 color difference.
///
/// This is the most accurate perceptual color difference formula,
/// accounting for human vision's varying sensitivity to different hues.
double _ciede2000(
  (double L, double a, double b) lab1,
  (double L, double a, double b) lab2,
) {
  final l1 = lab1.$1;
  final a1 = lab1.$2;
  final b1 = lab1.$3;
  final l2 = lab2.$1;
  final a2 = lab2.$2;
  final b2 = lab2.$3;

  final c1 = math.sqrt(a1 * a1 + b1 * b1);
  final c2 = math.sqrt(a2 * a2 + b2 * b2);
  final cBar = (c1 + c2) / 2;
  final cBar7 = cBar * cBar * cBar * cBar * cBar * cBar * cBar;
  final g = 0.5 * (1 - math.sqrt(cBar7 / (cBar7 + 6103515625)));

  final a1Prime = a1 * (1 + g);
  final a2Prime = a2 * (1 + g);
  final c1Prime = math.sqrt(a1Prime * a1Prime + b1 * b1);
  final c2Prime = math.sqrt(a2Prime * a2Prime + b2 * b2);

  var h1Prime = math.atan2(b1, a1Prime) * 180 / math.pi;
  if (h1Prime < 0) h1Prime += 360;
  var h2Prime = math.atan2(b2, a2Prime) * 180 / math.pi;
  if (h2Prime < 0) h2Prime += 360;

  final deltaLPrime = l2 - l1;
  final deltaCPrime = c2Prime - c1Prime;

  double deltahPrime;
  if (c1Prime * c2Prime == 0) {
    deltahPrime = 0;
  } else {
    final diff = h2Prime - h1Prime;
    if (diff.abs() <= 180) {
      deltahPrime = diff;
    } else if (diff > 180) {
      deltahPrime = diff - 360;
    } else {
      deltahPrime = diff + 360;
    }
  }

  final deltaHPrime =
      2 * math.sqrt(c1Prime * c2Prime) * math.sin(deltahPrime * math.pi / 360);
  final lBarPrime = (l1 + l2) / 2;
  final cBarPrime = (c1Prime + c2Prime) / 2;

  double hBarPrime;
  if (c1Prime * c2Prime == 0) {
    hBarPrime = h1Prime + h2Prime;
  } else if ((h1Prime - h2Prime).abs() <= 180) {
    hBarPrime = (h1Prime + h2Prime) / 2;
  } else if (h1Prime + h2Prime < 360) {
    hBarPrime = (h1Prime + h2Prime + 360) / 2;
  } else {
    hBarPrime = (h1Prime + h2Prime - 360) / 2;
  }

  final t = 1 -
      0.17 * math.cos((hBarPrime - 30) * math.pi / 180) +
      0.24 * math.cos(2 * hBarPrime * math.pi / 180) +
      0.32 * math.cos((3 * hBarPrime + 6) * math.pi / 180) -
      0.20 * math.cos((4 * hBarPrime - 63) * math.pi / 180);

  final deltaTheta =
      30 * math.exp(-((hBarPrime - 275) / 25) * ((hBarPrime - 275) / 25));
  final cBarPrime7 = cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime;
  final rc = 2 * math.sqrt(cBarPrime7 / (cBarPrime7 + 6103515625));

  final lBarPrimeMinus50Sq = (lBarPrime - 50) * (lBarPrime - 50);
  final sl =
      1 + (0.015 * lBarPrimeMinus50Sq) / math.sqrt(20 + lBarPrimeMinus50Sq);
  final sc = 1 + 0.045 * cBarPrime;
  final sh = 1 + 0.015 * cBarPrime * t;
  final rt = -math.sin(2 * deltaTheta * math.pi / 180) * rc;

  final dL = deltaLPrime / sl;
  final dC = deltaCPrime / sc;
  final dH = deltaHPrime / sh;

  return math.sqrt(dL * dL + dC * dC + dH * dH + rt * dC * dH);
}
