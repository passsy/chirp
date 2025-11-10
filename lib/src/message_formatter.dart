import 'dart:convert';

import 'package:ansicolor/ansicolor.dart';
import 'package:chirp/chirp.dart';

/// Transforms LogEntry into formatted string
abstract class ChirpMessageFormatter {
  /// Class name transformers for resolving instance class names
  final List<ClassNameTransformer> classNameTransformers;

  ChirpMessageFormatter({List<ClassNameTransformer>? classNameTransformers})
      : classNameTransformers = classNameTransformers ?? [];

  String format(LogEntry entry);

  /// Resolve class name from instance using transformers
  String resolveClassName(Object instance) {
    // Try each transformer in order
    for (final transformer in classNameTransformers) {
      final result = transformer(instance);
      if (result != null) return result;
    }

    // Fallback to runtimeType
    return instance.runtimeType.toString();
  }
}

/// Default colored formatter (from experiment code)
class DefaultChirpMessageFormatter extends ChirpMessageFormatter {
  DefaultChirpMessageFormatter({super.classNameTransformers});

  @override
  String format(LogEntry entry) {
    ansiColorDisabled = false;

    final className = entry.loggerName ??
        (entry.instance != null ? resolveClassName(entry.instance!) : entry.className) ??
        'Unknown';
    final instanceHash = entry.instanceHash ?? 0;

    // Always include instance hash for clarity
    final hashHex = instanceHash.toRadixString(16).padLeft(4, '0');
    final shortHash = hashHex.substring(hashHex.length >= 4 ? hashHex.length - 4 : 0);
    final classLabel = '$className:$shortHash';

    // Generate readable color using HSL
    final double hue;
    const saturation = 0.7;
    const lightness = 0.6;

    if (entry.error != null) {
      // Use red color for errors/exceptions
      hue = 0.0; // Red
    } else {
      // Hue varies by class name, avoiding red shades (reserved for errors)
      // Hue range: 60° to 300° (yellow → green → cyan → blue → magenta, skipping red)
      final hash = classLabel.hashCode;
      const minHue = 60.0;
      const maxHue = 300.0;
      const hueRange = maxHue - minHue;
      final hueDegrees = minHue + (hash.abs() % hueRange.toInt());
      hue = hueDegrees / 360.0;
    }

    final rgb = _hslToRgb(hue, saturation, lightness);
    final pen = AnsiPen()..rgb(r: rgb.$1, g: rgb.$2, b: rgb.$3);

    // Format timestamp
    final now = entry.date;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    final formattedTime = '$hour:$minute:$second.$ms';

    // Build meta line with padding
    const metaWidth = 60;
    final justText = '$formattedTime $classLabel';
    final remaining = metaWidth - justText.length;
    final meta = '$formattedTime ${"".padRight(remaining, '=')} $classLabel';

    // Split message into lines
    final messageStr = entry.message?.toString() ?? '';
    final messageLines = messageStr.split('\n');

    // Build exception/stack trace lines
    final buffer = StringBuffer();
    if (entry.error != null) {
      buffer.write('\n${entry.error}');
    }
    if (entry.stackTrace != null) {
      buffer.write('\n${entry.stackTrace}');
    }
    final extraLines = buffer.toString();

    // Format output with color
    final coloredExtraLines = extraLines.isNotEmpty
        ? extraLines.split('\n').map((line) => pen(line)).join('\n')
        : '';

    // Build final output
    final output = StringBuffer();
    if (messageLines.length <= 1) {
      output.write(pen('$meta │ $messageStr'));
      if (coloredExtraLines.isNotEmpty) {
        output.write(coloredExtraLines);
      }
    } else {
      output.write(pen(meta));
      output.write(' │ \n');
      output.write(messageLines.map((line) => pen(line)).join('\n'));
      if (coloredExtraLines.isNotEmpty) {
        output.write(coloredExtraLines);
      }
    }

    return output.toString();
  }
}

/// Converts HSL color to RGB.
///
/// All values are in range 0.0 to 1.0.
/// Returns (r, g, b) tuple.
(double, double, double) _hslToRgb(double h, double s, double l) {
  if (s == 0.0) {
    // Achromatic (gray)
    return (l, l, l);
  }

  double hue2rgb(double p, double q, double t) {
    var t2 = t;
    if (t2 < 0) t2 += 1;
    if (t2 > 1) t2 -= 1;
    if (t2 < 1 / 6) return p + (q - p) * 6 * t2;
    if (t2 < 1 / 2) return q;
    if (t2 < 2 / 3) return p + (q - p) * (2 / 3 - t2) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;

  final r = hue2rgb(p, q, h + 1 / 3);
  final g = hue2rgb(p, q, h);
  final b = hue2rgb(p, q, h - 1 / 3);

  return (r, g, b);
}

/// Single-line compact format
class CompactChirpMessageFormatter extends ChirpMessageFormatter {
  CompactChirpMessageFormatter({super.classNameTransformers});

  @override
  String format(LogEntry entry) {
    final hour = entry.date.hour.toString().padLeft(2, '0');
    final minute = entry.date.minute.toString().padLeft(2, '0');
    final second = entry.date.second.toString().padLeft(2, '0');
    final ms = entry.date.millisecond.toString().padLeft(3, '0');
    final formattedTime = '$hour:$minute:$second.$ms';

    final className = entry.loggerName ??
        (entry.instance != null ? resolveClassName(entry.instance!) : entry.className) ??
        'Unknown';
    final hash = (entry.instanceHash ?? 0).toRadixString(16).padLeft(4, '0');
    final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);

    final buffer = StringBuffer();
    buffer.write('$formattedTime $className:$shortHash ${entry.message}');

    if (entry.error != null) {
      buffer.write('\n${entry.error}');
    }

    if (entry.stackTrace != null) {
      buffer.write('\n${entry.stackTrace}');
    }

    return buffer.toString();
  }
}

/// JSON format for structured logging
class JsonChirpMessageFormatter extends ChirpMessageFormatter {
  JsonChirpMessageFormatter({super.classNameTransformers});

  @override
  String format(LogEntry entry) {
    final className = entry.loggerName ??
        (entry.instance != null ? resolveClassName(entry.instance!) : entry.className) ??
        'Unknown';

    final map = <String, dynamic>{
      'timestamp': entry.date.toIso8601String(),
      'class': className,
      'hash': (entry.instanceHash ?? 0).toRadixString(16).padLeft(4, '0'),
      'message': entry.message?.toString(),
    };

    if (entry.error != null) {
      map['error'] = entry.error.toString();
    }

    if (entry.stackTrace != null) {
      map['stackTrace'] = entry.stackTrace.toString();
    }

    return jsonEncode(map);
  }
}
