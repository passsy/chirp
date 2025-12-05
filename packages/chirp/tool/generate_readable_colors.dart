// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:chirp/src/ansi/xterm_colors.g.dart';

/// Calculate color distance using CIEDE2000.
///
/// Returns perceptual color difference (ΔE).
double colorDistance(XtermColor a, XtermColor b) {
  // Convert RGB to Lab
  final lab1 = _rgbToLab(a.r, a.g, a.b);
  final lab2 = _rgbToLab(b.r, b.g, b.b);
  return _ciede2000(lab1, lab2);
}

(double L, double a, double b) _rgbToLab(int r, int g, int b) {
  // RGB to XYZ
  double pivotRgb(double n) {
    final v = n / 255.0;
    return v > 0.04045 ? pow((v + 0.055) / 1.055, 2.4).toDouble() : v / 12.92;
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
        ? pow(n, 1.0 / 3.0).toDouble()
        : (7.787 * n) + (16.0 / 116.0);
  }

  final xPivot = pivotXyz(x / refX);
  final yPivot = pivotXyz(y / refY);
  final zPivot = pivotXyz(z / refZ);

  final labL = (116.0 * yPivot) - 16.0;
  final labA = 500.0 * (xPivot - yPivot);
  final labB = 200.0 * (yPivot - zPivot);

  return (labL, labA, labB);
}

double _ciede2000(
  (double, double, double) lab1,
  (double, double, double) lab2,
) {
  final l1 = lab1.$1;
  final a1 = lab1.$2;
  final b1 = lab1.$3;
  final l2 = lab2.$1;
  final a2 = lab2.$2;
  final b2 = lab2.$3;

  const kL = 1.0;
  const kC = 1.0;
  const kH = 1.0;
  const piVal = 3.141592653589793;

  final c1 = sqrt(a1 * a1 + b1 * b1);
  final c2 = sqrt(a2 * a2 + b2 * b2);
  final cBar = (c1 + c2) / 2;

  final cBar7 = cBar * cBar * cBar * cBar * cBar * cBar * cBar;
  final g = 0.5 * (1 - sqrt(cBar7 / (cBar7 + 6103515625)));

  final a1Prime = a1 * (1 + g);
  final a2Prime = a2 * (1 + g);

  final c1Prime = sqrt(a1Prime * a1Prime + b1 * b1);
  final c2Prime = sqrt(a2Prime * a2Prime + b2 * b2);

  var h1Prime = atan2(b1, a1Prime) * 180 / piVal;
  if (h1Prime < 0) h1Prime += 360;
  var h2Prime = atan2(b2, a2Prime) * 180 / piVal;
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
      2 * sqrt(c1Prime * c2Prime) * sin(deltahPrime * piVal / 360);

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
      0.17 * cos((hBarPrime - 30) * piVal / 180) +
      0.24 * cos(2 * hBarPrime * piVal / 180) +
      0.32 * cos((3 * hBarPrime + 6) * piVal / 180) -
      0.20 * cos((4 * hBarPrime - 63) * piVal / 180);

  final deltaTheta =
      30 * exp(-((hBarPrime - 275) / 25) * ((hBarPrime - 275) / 25));

  final cBarPrime7 = cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime *
      cBarPrime;
  final rc = 2 * sqrt(cBarPrime7 / (cBarPrime7 + 6103515625));

  final lBarPrimeMinus50Sq = (lBarPrime - 50) * (lBarPrime - 50);
  final sl = 1 + (0.015 * lBarPrimeMinus50Sq) / sqrt(20 + lBarPrimeMinus50Sq);
  final sc = 1 + 0.045 * cBarPrime;
  final sh = 1 + 0.015 * cBarPrime * t;
  final rt = -sin(2 * deltaTheta * piVal / 180) * rc;

  final dL = deltaLPrime / (kL * sl);
  final dC = deltaCPrime / (kC * sc);
  final dH = deltaHPrime / (kH * sh);

  return sqrt(dL * dL + dC * dC + dH * dH + rt * dC * dH);
}

const double minContrastDark = 3.1;
const double minContrastLight = 2.12;

(double h, double s, double l) rgbToHsl(int r, int g, int b) {
  final rf = r / 255;
  final gf = g / 255;
  final bf = b / 255;

  final maxC = max(rf, max(gf, bf));
  final minC = min(rf, min(gf, bf));
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

class ColorInfo {
  final XtermColor color;
  final double hue;
  final double saturation;
  final double lightness;
  final double distanceToRed;
  final double distanceToYellow;
  final double distanceToWhite;
  final double distanceToBlack;
  final bool isGrey;
  final bool isRedish;
  final bool isYellowish;
  final bool isTooLight;
  final bool isTooDark;
  final String saturationGroup;

  ColorInfo(this.color)
      : hue = rgbToHsl(color.r, color.g, color.b).$1,
        saturation = rgbToHsl(color.r, color.g, color.b).$2,
        lightness = rgbToHsl(color.r, color.g, color.b).$3,
        distanceToRed = colorDistance(color, XtermColor.red_1),
        distanceToYellow = colorDistance(color, XtermColor.yellow_3),
        distanceToWhite = colorDistance(color, XtermColor.brightWhite_15),
        distanceToBlack = colorDistance(color, XtermColor.black_0),
        isGrey = rgbToHsl(color.r, color.g, color.b).$2 < 0.16,
        isRedish = colorDistance(color, XtermColor.red_1) <= 30,
        isYellowish = colorDistance(color, XtermColor.yellow_3) <= 30,
        isTooLight = color.contrastOnWhite < minContrastLight,
        isTooDark = color.contrastOnBlack < minContrastDark,
        saturationGroup =
            _getSaturationGroup(rgbToHsl(color.r, color.g, color.b).$2);

  bool get isValid =>
      !isGrey && !isRedish && !isYellowish && !isTooLight && !isTooDark;

  String get marker {
    if (isGrey) return '◼️';
    if (isRedish) return '🔴';
    if (isYellowish) return '🟡';
    if (isTooLight) return '⚪️';
    if (isTooDark) return '🌑';
    return ' ';
  }

  static String _getSaturationGroup(double sat) {
    final satPercent = (sat * 100).round();
    if (satPercent == 0) return '0% (grays)';
    if (satPercent <= 33) return 'low';
    if (satPercent <= 60) return 'medium';
    return 'high';
  }
}

void main() {
  // Calculate all properties once
  final colors = XtermColor.values.map((c) => ColorInfo(c)).toList();

  // Group all colors by saturation
  final groups = <String, List<ColorInfo>>{
    '0% (grays)': [],
    'low': [],
    'medium': [],
    'high': [],
  };

  for (final c in colors) {
    groups[c.saturationGroup]!.add(c);
  }

  // Print all colors by group
  for (final entry in groups.entries) {
    print('--- Saturation ${entry.key} ---');
    final sorted = entry.value.toList()..sort((a, b) => a.hue.compareTo(b.hue));

    for (final c in sorted) {
      print(
          '${c.marker} \x1B[38;2;${c.color.r};${c.color.g};${c.color.b}m${c.color.name.padRight(20)}\x1B[0m '
          'HSL(${c.hue.toStringAsFixed(0).padLeft(3)}°, ${(c.saturation * 100).toStringAsFixed(0).padLeft(3)}%, ${(c.lightness * 100).toStringAsFixed(0).padLeft(3)}%) '
          'dR: ${c.distanceToRed.toStringAsFixed(0).padLeft(2)} dY: ${c.distanceToYellow.toStringAsFixed(0).padLeft(2)} '
          'dW: ${c.distanceToWhite.toStringAsFixed(0).padLeft(2)} dB: ${c.distanceToBlack.toStringAsFixed(0).padLeft(2)}');
    }
    print('Count: ${sorted.length}');
    print('');
  }

  print('Total: ${colors.length} colors');

  // Get valid colors
  final validColors = colors.where((c) => c.isValid).toList();

  print('');
  print('=== VALID COLORS (no marker ${validColors.length}) ===');

  // Group valid colors by saturation
  final validGroups = <String, List<ColorInfo>>{
    'low': [],
    'medium': [],
    'high': [],
  };

  for (final c in validColors) {
    validGroups[c.saturationGroup]!.add(c);
  }

  for (final entry in validGroups.entries) {
    if (entry.value.isEmpty) continue;
    print('--- Saturation ${entry.key} (${entry.value.length}) ---');
    final sorted = entry.value.toList()
      ..sort((a, b) => a.distanceToRed.compareTo(b.distanceToRed));

    for (final c in sorted) {
      print(
          '   \x1B[38;2;${c.color.r};${c.color.g};${c.color.b}m${c.color.name.padRight(20)}\x1B[0m '
          'HSL(${c.hue.toStringAsFixed(0).padLeft(3)}°, ${(c.saturation * 100).toStringAsFixed(0).padLeft(3)}%, ${(c.lightness * 100).toStringAsFixed(0).padLeft(3)}%) '
          'dR: ${c.distanceToRed.toStringAsFixed(0).padLeft(2)} dY: ${c.distanceToYellow.toStringAsFixed(0).padLeft(2)} '
          'dW: ${c.distanceToWhite.toStringAsFixed(0).padLeft(2)} dB: ${c.distanceToBlack.toStringAsFixed(0).padLeft(2)}');
    }
    print('');
  }

  print('Valid colors: ${validColors.length}');

  // Generate Dart file with valid colors
  final buffer = StringBuffer();
  buffer.writeln('// GENERATED FILE - DO NOT EDIT');
  buffer.writeln('// Generated by tool/generate_readable_colors.dart');
  buffer.writeln('//');
  buffer.writeln(
      '// These colors are readable on both light and dark terminal backgrounds');
  buffer.writeln(
      '// and do not interfere with red (errors) or yellow (warnings).');
  buffer.writeln('//');
  buffer.writeln('// Filtering criteria:');
  buffer.writeln('// - Distance to red (XtermColor.red_1) > 30');
  buffer.writeln('// - Distance to yellow (XtermColor.yellow_3) > 30');
  buffer.writeln('// - Contrast on white >= $minContrastLight');
  buffer.writeln('// - Contrast on black >= $minContrastDark');
  buffer.writeln('// - Saturation >= 16% (excludes grays)');
  buffer.writeln();
  buffer.writeln("import 'package:chirp/src/ansi/xterm_colors.g.dart';");
  buffer.writeln();

  // Write each saturation group as a separate list
  final groupNames = ['low', 'medium', 'high'];
  final listNames = {
    'low': 'readableColorsLowSaturation',
    'medium': 'readableColorsMediumSaturation',
    'high': 'readableColorsHighSaturation',
  };
  final descriptions = {
    'low': 'Low saturation colors (17-33%) - subtle, muted tones.',
    'medium': 'Medium saturation colors (34-60%) - balanced, clear tones.',
    'high': 'High saturation colors (61-100%) - vibrant, vivid tones.',
  };

  for (final groupName in groupNames) {
    final groupColors = validGroups[groupName]!;
    if (groupColors.isEmpty) continue;

    // Sort by hue
    groupColors.sort((a, b) => b.hue.compareTo(a.hue));

    buffer.writeln('/// ${descriptions[groupName]}');
    buffer.writeln('const List<XtermColor> ${listNames[groupName]} = [');
    for (final c in groupColors) {
      buffer.writeln('  XtermColor.${c.color.name},');
    }
    buffer.writeln('];');
    buffer.writeln();
  }

  // Also write a combined list for convenience
  buffer.writeln(
      '/// All readable colors combined (low + medium + high saturation).');
  buffer.writeln('const List<XtermColor> readableColors = [');
  buffer.writeln('  ...readableColorsLowSaturation,');
  buffer.writeln('  ...readableColorsMediumSaturation,');
  buffer.writeln('  ...readableColorsHighSaturation,');
  buffer.writeln('];');

  final file = File('lib/src/ansi/readable_colors.g.dart');
  file.writeAsStringSync(buffer.toString());
  print('Generated ${file.path}');
}
