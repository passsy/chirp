// ignore_for_file: avoid_print, unreachable_from_main
import 'dart:math';

import 'package:chirp/src/ansi/readable_colors.g.dart';
import 'package:chirp/src/ansi/xterm_colors.g.dart';

// =============================================================================
// Color conversion and validation utilities
// =============================================================================

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

(int r, int g, int b) hslToRgb(double h, double s, double l) {
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

double relativeLuminance(int r, int g, int b) {
  double linearize(int c) {
    final v = c / 255;
    return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

double contrastRatio(double l1, double l2) {
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

(double L, double a, double b) rgbToLab(int r, int g, int b) {
  double pivotRgb(double n) {
    final v = n / 255.0;
    return v > 0.04045 ? pow((v + 0.055) / 1.055, 2.4).toDouble() : v / 12.92;
  }

  final rLinear = pivotRgb(r.toDouble()) * 100;
  final gLinear = pivotRgb(g.toDouble()) * 100;
  final bLinear = pivotRgb(b.toDouble()) * 100;

  final x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375;
  final y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750;
  final z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041;

  const refX = 95.047;
  const refY = 100.000;
  const refZ = 108.883;

  double pivotXyz(double n) => n > 0.008856
      ? pow(n, 1.0 / 3.0).toDouble()
      : (7.787 * n) + (16.0 / 116.0);

  final xPivot = pivotXyz(x / refX);
  final yPivot = pivotXyz(y / refY);
  final zPivot = pivotXyz(z / refZ);

  return (
    (116.0 * yPivot) - 16.0,
    500.0 * (xPivot - yPivot),
    200.0 * (yPivot - zPivot)
  );
}

double ciede2000((double, double, double) lab1, (double, double, double) lab2) {
  final l1 = lab1.$1;
  final a1 = lab1.$2;
  final b1 = lab1.$3;
  final l2 = lab2.$1;
  final a2 = lab2.$2;
  final b2 = lab2.$3;

  final c1 = sqrt(a1 * a1 + b1 * b1);
  final c2 = sqrt(a2 * a2 + b2 * b2);
  final cBar = (c1 + c2) / 2;
  final cBar7 = cBar * cBar * cBar * cBar * cBar * cBar * cBar;
  final g = 0.5 * (1 - sqrt(cBar7 / (cBar7 + 6103515625)));

  final a1Prime = a1 * (1 + g);
  final a2Prime = a2 * (1 + g);
  final c1Prime = sqrt(a1Prime * a1Prime + b1 * b1);
  final c2Prime = sqrt(a2Prime * a2Prime + b2 * b2);

  var h1Prime = atan2(b1, a1Prime) * 180 / pi;
  if (h1Prime < 0) h1Prime += 360;
  var h2Prime = atan2(b2, a2Prime) * 180 / pi;
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

  final deltaHPrime = 2 * sqrt(c1Prime * c2Prime) * sin(deltahPrime * pi / 360);
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
      0.17 * cos((hBarPrime - 30) * pi / 180) +
      0.24 * cos(2 * hBarPrime * pi / 180) +
      0.32 * cos((3 * hBarPrime + 6) * pi / 180) -
      0.20 * cos((4 * hBarPrime - 63) * pi / 180);

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
  final rt = -sin(2 * deltaTheta * pi / 180) * rc;

  final dL = deltaLPrime / sl;
  final dC = deltaCPrime / sc;
  final dH = deltaHPrime / sh;

  return sqrt(dL * dL + dC * dC + dH * dH + rt * dC * dH);
}

// =============================================================================
// Readability checks
// =============================================================================

const double minContrastDark = 3.1;
const double minContrastLight = 2.12;
const double minDistanceToRed = 30.0;
const double minDistanceToYellow = 30.0;

final _redLab = rgbToLab(128, 0, 0);
final _yellowLab = rgbToLab(128, 128, 0);

class ColorValidation {
  final int r;
  final int g;
  final int b;
  final double contrastOnWhite;
  final double contrastOnBlack;
  final double distanceToRed;
  final double distanceToYellow;

  ColorValidation(this.r, this.g, this.b)
      : contrastOnWhite = contrastRatio(relativeLuminance(r, g, b), 1.0),
        contrastOnBlack = contrastRatio(relativeLuminance(r, g, b), 0.0),
        distanceToRed = ciede2000(rgbToLab(r, g, b), _redLab),
        distanceToYellow = ciede2000(rgbToLab(r, g, b), _yellowLab);

  bool get tooCloseToRed => distanceToRed <= minDistanceToRed;
  bool get tooCloseToYellow => distanceToYellow <= minDistanceToYellow;
  bool get tooLightForWhite => contrastOnWhite < minContrastLight;
  bool get tooDarkForBlack => contrastOnBlack < minContrastDark;

  bool get isValid =>
      !tooCloseToRed &&
      !tooCloseToYellow &&
      !tooLightForWhite &&
      !tooDarkForBlack;

  String get failureReasons {
    final reasons = <String>[];
    if (tooCloseToRed) reasons.add('red');
    if (tooCloseToYellow) reasons.add('yellow');
    if (tooLightForWhite) reasons.add('light');
    if (tooDarkForBlack) reasons.add('dark');
    return reasons.isEmpty ? 'valid' : reasons.join('+');
  }
}

// =============================================================================
// Color variance generator
// =============================================================================

(int r, int g, int b) generateVariantColor(
  XtermColor baseColor,
  int hash, {
  required double satVarianceMax,
  required double lightVarianceMax,
}) {
  final (h, s, l) = rgbToHsl(baseColor.r, baseColor.g, baseColor.b);

  // Use different bits of hash for different variances
  // Range: -max to +max
  final satVariance =
      ((hash >> 8) % 201 - 100) / 100 * satVarianceMax; // -max to +max
  final lightVariance =
      ((hash >> 16) % 201 - 100) / 100 * lightVarianceMax; // -max to +max

  final newS = (s + satVariance).clamp(0.1, 0.95);
  final newL = (l + lightVariance).clamp(0.25, 0.75);

  return hslToRgb(h, newS, newL);
}

// =============================================================================
// Test runner
// =============================================================================

void runTest({
  required double satVariance,
  required double lightVariance,
  required int sampleCount,
  bool verbose = false,
}) {
  final random = Random(42); // Fixed seed for reproducibility
  final baseColors = readableColors.map((c) {
    final code = c.code;
    return XtermColor.values.firstWhere((x) => x.code == code);
  }).toList();

  var validCount = 0;
  var redFailures = 0;
  var yellowFailures = 0;
  var lightFailures = 0;
  var darkFailures = 0;

  final failedExamples =
      <(XtermColor base, int hash, ColorValidation validation)>[];

  for (var i = 0; i < sampleCount; i++) {
    final hash = random.nextInt(1 << 30);
    final baseColor = baseColors[hash % baseColors.length];

    final (r, g, b) = generateVariantColor(
      baseColor,
      hash,
      satVarianceMax: satVariance,
      lightVarianceMax: lightVariance,
    );

    final validation = ColorValidation(r, g, b);

    if (validation.isValid) {
      validCount++;
    } else {
      if (validation.tooCloseToRed) redFailures++;
      if (validation.tooCloseToYellow) yellowFailures++;
      if (validation.tooLightForWhite) lightFailures++;
      if (validation.tooDarkForBlack) darkFailures++;

      if (failedExamples.length < 10) {
        failedExamples.add((baseColor, hash, validation));
      }
    }
  }

  final successRate = (validCount / sampleCount * 100).toStringAsFixed(1);

  print('S±${(satVariance * 100).toStringAsFixed(0).padLeft(2)}% '
      'L±${(lightVariance * 100).toStringAsFixed(0).padLeft(2)}%: '
      '$validCount/$sampleCount valid ($successRate%) '
      '| 🔴$redFailures 🟡$yellowFailures ⚪️$lightFailures 🌑$darkFailures');

  if (verbose && failedExamples.isNotEmpty) {
    print('  Failed examples:');
    for (final (base, hash, validation) in failedExamples) {
      final (r, g, b) = generateVariantColor(
        base,
        hash,
        satVarianceMax: satVariance,
        lightVarianceMax: lightVariance,
      );
      print('    \x1B[38;2;$r;$g;${b}m██\x1B[0m '
          'base=${base.name.padRight(20)} '
          'reason=${validation.failureReasons.padRight(12)} '
          'dR=${validation.distanceToRed.toStringAsFixed(1).padLeft(5)} '
          'dY=${validation.distanceToYellow.toStringAsFixed(1).padLeft(5)} '
          'cW=${validation.contrastOnWhite.toStringAsFixed(2).padLeft(5)} '
          'cB=${validation.contrastOnBlack.toStringAsFixed(2).padLeft(5)}');
    }
  }
}

void analyzeProblematicColors({
  required double satVariance,
  required double lightVariance,
  required int sampleCount,
}) {
  final random = Random(42);
  final baseColors = readableColors.map((c) {
    final code = c.code;
    return XtermColor.values.firstWhere((x) => x.code == code);
  }).toList();

  // Track failures per base color
  final failuresByBase = <String, int>{};
  final failureReasonsByBase = <String, Map<String, int>>{};

  for (var i = 0; i < sampleCount; i++) {
    final hash = random.nextInt(1 << 30);
    final baseColor = baseColors[hash % baseColors.length];

    final (r, g, b) = generateVariantColor(
      baseColor,
      hash,
      satVarianceMax: satVariance,
      lightVarianceMax: lightVariance,
    );

    final validation = ColorValidation(r, g, b);

    if (!validation.isValid) {
      failuresByBase[baseColor.name] =
          (failuresByBase[baseColor.name] ?? 0) + 1;
      failureReasonsByBase.putIfAbsent(baseColor.name, () => {});
      if (validation.tooCloseToRed) {
        failureReasonsByBase[baseColor.name]!['red'] =
            (failureReasonsByBase[baseColor.name]!['red'] ?? 0) + 1;
      }
      if (validation.tooCloseToYellow) {
        failureReasonsByBase[baseColor.name]!['yellow'] =
            (failureReasonsByBase[baseColor.name]!['yellow'] ?? 0) + 1;
      }
      if (validation.tooLightForWhite) {
        failureReasonsByBase[baseColor.name]!['light'] =
            (failureReasonsByBase[baseColor.name]!['light'] ?? 0) + 1;
      }
      if (validation.tooDarkForBlack) {
        failureReasonsByBase[baseColor.name]!['dark'] =
            (failureReasonsByBase[baseColor.name]!['dark'] ?? 0) + 1;
      }
    }
  }

  // Sort by failure count
  final sorted = failuresByBase.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  print('');
  print(
      'PROBLEMATIC BASE COLORS (S±${(satVariance * 100).toInt()}% L±${(lightVariance * 100).toInt()}%):');
  print('-' * 80);

  var cumulativeFixed = 0;
  final totalFailures = sorted.fold<int>(0, (sum, e) => sum + e.value);

  for (final entry in sorted) {
    final name = entry.key;
    final count = entry.value;
    final reasons = failureReasonsByBase[name]!;
    final reasonStr =
        reasons.entries.map((e) => '${e.key}:${e.value}').join(' ');

    // Find the base color to show it
    final baseColor = baseColors.firstWhere((c) => c.name == name);
    final (h, s, l) = rgbToHsl(baseColor.r, baseColor.g, baseColor.b);

    cumulativeFixed += count;
    final newSuccessRate =
        ((sampleCount - totalFailures + cumulativeFixed) / sampleCount * 100)
            .toStringAsFixed(1);

    print('\x1B[38;2;${baseColor.r};${baseColor.g};${baseColor.b}m██\x1B[0m '
        '${name.padRight(24)} '
        'failures=${count.toString().padLeft(3)} '
        'HSL(${h.toStringAsFixed(0).padLeft(3)}°,${(s * 100).toStringAsFixed(0).padLeft(3)}%,${(l * 100).toStringAsFixed(0).padLeft(3)}%) '
        '$reasonStr '
        '→ remove for $newSuccessRate%');
  }

  print('');
  print('Total failures: $totalFailures/$sampleCount');
  print('Unique problematic colors: ${sorted.length}');

  // Show which colors to remove for 99%+ success
  print('');
  print('TO ACHIEVE 99%+ SUCCESS RATE, REMOVE:');
  cumulativeFixed = 0;
  for (final entry in sorted) {
    cumulativeFixed += entry.value;
    final newSuccessRate =
        (sampleCount - totalFailures + cumulativeFixed) / sampleCount * 100;
    if (newSuccessRate >= 99.0) {
      print(
          '  → Remove ${sorted.takeWhile((e) => e != entry).length + 1} colors listed above');
      break;
    }
  }
}

void main() {
  const sampleCount = 1000;

  print('Testing color variance with $sampleCount random hashes');
  print('Base colors: ${readableColors.length} from readable_colors.g.dart');
  print('');
  print('Thresholds: dRed>$minDistanceToRed dYellow>$minDistanceToYellow '
      'cWhite≥$minContrastLight cBlack≥$minContrastDark');
  print('');

  print('=' * 80);
  print('SATURATION VARIANCE ONLY (Lightness fixed)');
  print('=' * 80);
  for (final sVar in [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30]) {
    runTest(satVariance: sVar, lightVariance: 0.0, sampleCount: sampleCount);
  }

  print('');
  print('=' * 80);
  print('LIGHTNESS VARIANCE ONLY (Saturation fixed)');
  print('=' * 80);
  for (final lVar in [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30]) {
    runTest(satVariance: 0.0, lightVariance: lVar, sampleCount: sampleCount);
  }

  print('');
  print('=' * 80);
  print('COMBINED VARIANCE');
  print('=' * 80);
  for (final variance in [0.05, 0.10, 0.15, 0.20]) {
    runTest(
        satVariance: variance,
        lightVariance: variance,
        sampleCount: sampleCount);
  }

  print('');
  print('=' * 80);
  print('RECOMMENDED SETTINGS (with examples of failures)');
  print('=' * 80);
  runTest(
      satVariance: 0.10,
      lightVariance: 0.05,
      sampleCount: sampleCount,
      verbose: true);

  print('');
  runTest(
      satVariance: 0.05,
      lightVariance: 0.05,
      sampleCount: sampleCount,
      verbose: true);

  // Test guardrails approach
  print('');
  print('=' * 80);
  print('GUARDRAILS APPROACH: Clamp + Retry');
  print('=' * 80);

  testGuardrailsApproach(sampleCount: 10000);
}

// =============================================================================
// Guardrails approach
// =============================================================================

(int r, int g, int b) generateVariantColorWithGuardrails(
  XtermColor baseColor,
  int hash, {
  required double satVarianceMax,
  required double lightVarianceMax,
  required double minLightness,
  required double maxLightness,
  required double minSaturation,
  required double maxSaturation,
}) {
  final (h, s, l) = rgbToHsl(baseColor.r, baseColor.g, baseColor.b);

  final satVariance = ((hash >> 8) % 201 - 100) / 100 * satVarianceMax;
  final lightVariance = ((hash >> 16) % 201 - 100) / 100 * lightVarianceMax;

  // Apply guardrails
  final newS = (s + satVariance).clamp(minSaturation, maxSaturation);
  final newL = (l + lightVariance).clamp(minLightness, maxLightness);

  return hslToRgb(h, newS, newL);
}

(int r, int g, int b, int retries) generateWithRetry(
  List<XtermColor> baseColors,
  int hash, {
  required double satVarianceMax,
  required double lightVarianceMax,
  required double minLightness,
  required double maxLightness,
  required double minSaturation,
  required double maxSaturation,
  required int maxRetries,
}) {
  var currentHash = hash;

  for (var retry = 0; retry <= maxRetries; retry++) {
    final baseColor = baseColors[currentHash % baseColors.length];

    final (r, g, b) = generateVariantColorWithGuardrails(
      baseColor,
      currentHash,
      satVarianceMax: satVarianceMax,
      lightVarianceMax: lightVarianceMax,
      minLightness: minLightness,
      maxLightness: maxLightness,
      minSaturation: minSaturation,
      maxSaturation: maxSaturation,
    );

    final validation = ColorValidation(r, g, b);
    if (validation.isValid) {
      return (r, g, b, retry);
    }

    // Try next hash
    currentHash = (currentHash + 1) * 31; // Simple hash mixing
  }

  // Fallback: return base color unchanged
  final baseColor = baseColors[hash % baseColors.length];
  return (baseColor.r, baseColor.g, baseColor.b, maxRetries + 1);
}

void testGuardrailsApproach({required int sampleCount}) {
  final random = Random(42);
  final baseColors = readableColors.map((c) {
    final code = c.code;
    return XtermColor.values.firstWhere((x) => x.code == code);
  }).toList();

  final configs = <String, Map<String, double>>{
    'No guardrails (S±10% L±10%)': {
      'satVar': 0.10,
      'lightVar': 0.10,
      'minL': 0.25,
      'maxL': 0.75,
      'minS': 0.10,
      'maxS': 0.95,
    },
    'Clamp L to 40-65%': {
      'satVar': 0.10,
      'lightVar': 0.10,
      'minL': 0.40,
      'maxL': 0.65,
      'minS': 0.10,
      'maxS': 0.95,
    },
    'Clamp L to 42-62%': {
      'satVar': 0.10,
      'lightVar': 0.10,
      'minL': 0.42,
      'maxL': 0.62,
      'minS': 0.10,
      'maxS': 0.95,
    },
    'Clamp L to 45-60%': {
      'satVar': 0.10,
      'lightVar': 0.10,
      'minL': 0.45,
      'maxL': 0.60,
      'minS': 0.10,
      'maxS': 0.95,
    },
    'Clamp L 42-62% + S 20-80%': {
      'satVar': 0.10,
      'lightVar': 0.10,
      'minL': 0.42,
      'maxL': 0.62,
      'minS': 0.20,
      'maxS': 0.80,
    },
    'Higher var S±15% L±15%, L 42-62%': {
      'satVar': 0.15,
      'lightVar': 0.15,
      'minL': 0.42,
      'maxL': 0.62,
      'minS': 0.10,
      'maxS': 0.95,
    },
  };

  print('Testing guardrails with $sampleCount samples (no retry):');
  print('');

  for (final entry in configs.entries) {
    final cfg = entry.value;
    var validCount = 0;

    for (var i = 0; i < sampleCount; i++) {
      final hash = random.nextInt(1 << 30);
      final baseColor = baseColors[hash % baseColors.length];

      final (r, g, b) = generateVariantColorWithGuardrails(
        baseColor,
        hash,
        satVarianceMax: cfg['satVar']!,
        lightVarianceMax: cfg['lightVar']!,
        minLightness: cfg['minL']!,
        maxLightness: cfg['maxL']!,
        minSaturation: cfg['minS']!,
        maxSaturation: cfg['maxS']!,
      );

      if (ColorValidation(r, g, b).isValid) validCount++;
    }

    final rate = (validCount / sampleCount * 100).toStringAsFixed(1);
    print('${entry.key.padRight(40)} $validCount/$sampleCount ($rate%)');

    // Reset random for next config
    random.nextInt(1); // consume one to keep sequences comparable
  }

  // Test with retry
  print('');
  print('Testing with RETRY mechanism (max 3 retries):');
  print('');

  final retryConfigs = <String, Map<String, double>>{
    'L 42-62%, retry up to 3x': {
      'satVar': 0.10,
      'lightVar': 0.10,
      'minL': 0.42,
      'maxL': 0.62,
      'minS': 0.10,
      'maxS': 0.95,
    },
    'L 40-65%, retry up to 3x': {
      'satVar': 0.15,
      'lightVar': 0.15,
      'minL': 0.40,
      'maxL': 0.65,
      'minS': 0.10,
      'maxS': 0.95,
    },
  };

  for (final entry in retryConfigs.entries) {
    final cfg = entry.value;
    var validCount = 0;
    var totalRetries = 0;
    final retriesDist = <int, int>{};

    for (var i = 0; i < sampleCount; i++) {
      final hash = random.nextInt(1 << 30);

      final (r, g, b, retries) = generateWithRetry(
        baseColors,
        hash,
        satVarianceMax: cfg['satVar']!,
        lightVarianceMax: cfg['lightVar']!,
        minLightness: cfg['minL']!,
        maxLightness: cfg['maxL']!,
        minSaturation: cfg['minS']!,
        maxSaturation: cfg['maxS']!,
        maxRetries: 3,
      );

      if (ColorValidation(r, g, b).isValid) validCount++;
      totalRetries += retries;
      retriesDist[retries] = (retriesDist[retries] ?? 0) + 1;
    }

    final rate = (validCount / sampleCount * 100).toStringAsFixed(1);
    final avgRetries = (totalRetries / sampleCount).toStringAsFixed(2);
    print('${entry.key.padRight(40)} $validCount/$sampleCount ($rate%)');
    print(
        '   Retry distribution: ${retriesDist.entries.map((e) => '${e.key}:${e.value}').join(' ')}');
    print('   Avg retries: $avgRetries');
  }

  // Visual demo
  print('');
  print('Visual demo (L 42-62%, with retry):');
  for (var i = 0; i < 15; i++) {
    final hash = Random().nextInt(1 << 30);
    final (r, g, b, retries) = generateWithRetry(
      baseColors,
      hash,
      satVarianceMax: 0.10,
      lightVarianceMax: 0.10,
      minLightness: 0.42,
      maxLightness: 0.62,
      minSaturation: 0.10,
      maxSaturation: 0.95,
      maxRetries: 3,
    );
    final baseColor = baseColors[hash % baseColors.length];
    final validation = ColorValidation(r, g, b);
    final status = validation.isValid ? '✓' : '✗';
    print('\x1B[38;2;$r;$g;${b}m████\x1B[0m '
        'base=\x1B[38;2;${baseColor.r};${baseColor.g};${baseColor.b}m████\x1B[0m '
        '${baseColor.name.padRight(22)} retries=$retries $status');
  }
}
