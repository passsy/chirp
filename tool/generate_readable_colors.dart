// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import '../lib/src/xterm_colors.g.dart';

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
        distanceToRed = XtermColor.distance(color, XtermColor.red),
        distanceToYellow = XtermColor.distance(color, XtermColor.yellow),
        distanceToWhite = XtermColor.distance(color, XtermColor.brightWhite),
        distanceToBlack = XtermColor.distance(color, XtermColor.black),
        isGrey = rgbToHsl(color.r, color.g, color.b).$2 < 0.16,
        isRedish = XtermColor.distance(color, XtermColor.red) <= 30,
        isYellowish = XtermColor.distance(color, XtermColor.yellow) <= 30,
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
    if (isTooLight) return '🌞';
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
  buffer.writeln('// - Distance to red (XtermColor.red) > 30');
  buffer.writeln('// - Distance to yellow (XtermColor.yellow) > 30');
  buffer.writeln('// - Contrast on white >= $minContrastLight');
  buffer.writeln('// - Contrast on black >= $minContrastDark');
  buffer.writeln('// - Saturation >= 16% (excludes grays)');
  buffer.writeln();
  buffer.writeln("import 'xterm_colors.g.dart';");
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

  final file = File('lib/src/readable_colors.g.dart');
  file.writeAsStringSync(buffer.toString());
  print('Generated ${file.path}');
}
