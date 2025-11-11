import 'dart:convert';

import 'package:ansicolor/ansicolor.dart';
import 'package:chirp/chirp.dart';
import 'package:chirp/src/stack_trace_util.dart';

/// Transforms LogEntry into formatted string
abstract class ChirpMessageFormatter {
  ChirpMessageFormatter();

  String format(LogRecord entry);
}

/// Function type for transforming an instance into a display name.
///
/// Return a non-null string to use that as the class name,
/// or null to try the next transformer.
typedef ClassNameTransformer = String? Function(Object instance);

/// Default colored formatter (from experiment code)
class RainbowMessageFormatter extends ChirpMessageFormatter {
  /// Width of the metadata section (timestamp + padding + label)
  final int metaWidth;

  /// Class name transformers for resolving instance class names
  final List<ClassNameTransformer> classNameTransformers;

  RainbowMessageFormatter({
    List<ClassNameTransformer>? classNameTransformers,
    this.metaWidth = 60,
  })  : classNameTransformers = classNameTransformers ?? [],
        super();

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

  @override
  String format(LogRecord entry) {
    ansiColorDisabled = false;

    final String? callerLocation = () {
      if (entry.caller != null) {
        return getCallerLocation(entry.caller!);
      }
      return null;
    }();

    final String? instanceInfo = () {
      if (entry.instance != null) {
        final className = resolveClassName(entry.instance!);
        final instanceHash = entry.instanceHash ?? 0;

        // Always include instance hash for clarity
        final hashHex = instanceHash.toRadixString(16).padLeft(4, '0');
        final shortHash =
            hashHex.substring(hashHex.length >= 4 ? hashHex.length - 4 : 0);
        return '$className:$shortHash';
      }
      return null;
    }();

    final label = [callerLocation, instanceInfo, entry.loggerName]
        .whereType<Object>()
        .join(" ");

    // Generate readable color using HSL
    final double hue;
    double saturation = 0.7;
    double lightness = 0.7;

    if (entry.error != null) {
      // Use red color for errors/exceptions
      hue = 0.0; // Red
      saturation = 0.7;
      lightness = 0.6;
    } else {
      final hashableThing = () {
        if (instanceInfo != null) return instanceInfo;
        if (entry.loggerName != null) return entry.loggerName;
        if (entry.caller != null) {
          final name = getCallerName(entry.caller!);
          if (name != null) {
            return name;
          }
        }
        return null;
      }();
      if (hashableThing != null) {
        // Hue varies by class name, avoiding red shades (reserved for errors)
        // Hue range: 60° to 300° (yellow → green → cyan → blue → magenta, skipping red)
        final hash = hashableThing.hashCode;
        const minHue = 60.0;
        const maxHue = 300.0;
        const hueRange = maxHue - minHue;
        final hueDegrees = minHue + (hash.abs() % hueRange.toInt());
        hue = hueDegrees / 360.0;
      } else {
        hue = 0.0;
        saturation = 0.0; // white
      }
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
    final justText = '$formattedTime $label';
    final remaining = metaWidth - justText.length;
    final meta = '$formattedTime ${"".padRight(remaining, '=')} $label';

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
  CompactChirpMessageFormatter() : super();

  @override
  String format(LogRecord entry) {
    final hour = entry.date.hour.toString().padLeft(2, '0');
    final minute = entry.date.minute.toString().padLeft(2, '0');
    final second = entry.date.second.toString().padLeft(2, '0');
    final ms = entry.date.millisecond.toString().padLeft(3, '0');
    final formattedTime = '$hour:$minute:$second.$ms';

    // Try to get caller location first
    final String? callerLocation =
        entry.caller != null ? getCallerLocation(entry.caller!) : null;

    final className = entry.loggerName ??
        callerLocation ??
        (entry.instance != null
            ? entry.instance!.runtimeType.toString()
            : entry.className) ??
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
  JsonChirpMessageFormatter() : super();

  @override
  String format(LogRecord entry) {
    final className = entry.loggerName ??
        (entry.instance != null
            ? entry.instance!.runtimeType.toString()
            : entry.className) ??
        'Unknown';

    final map = <String, dynamic>{
      'timestamp': entry.date.toIso8601String(),
      'level': entry.level.name,
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

    if (entry.data != null) {
      map['data'] = entry.data;
    }

    return jsonEncode(map);
  }
}

/// Google Cloud Platform (GCP) compatible JSON formatter
///
/// Formats logs according to the structure expected by Google Cloud Logging.
/// See: https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry
class GcpChirpMessageFormatter extends ChirpMessageFormatter {
  /// Optional GCP project ID
  final String? projectId;

  /// Optional GCP log name
  final String? logName;

  /// Whether to include source location information
  final bool includeSourceLocation;

  GcpChirpMessageFormatter({
    this.projectId,
    this.logName,
    this.includeSourceLocation = false,
  }) : super();

  /// Maps a ChirpLogLevel to GCP-compatible severity string
  String _gcpSeverity(ChirpLogLevel level) {
    // Map based on severity ranges following GCP's specification:
    // https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry
    if (level.severity < 100) {
      return 'DEFAULT'; // 0
    } else if (level.severity < 200) {
      return 'DEBUG'; // 100
    } else if (level.severity < 300) {
      return 'INFO'; // 200
    } else if (level.severity < 400) {
      return 'NOTICE'; // 300
    } else if (level.severity < 500) {
      return 'WARNING'; // 400
    } else if (level.severity < 600) {
      return 'ERROR'; // 500
    } else if (level.severity < 700) {
      return 'CRITICAL'; // 600
    } else if (level.severity < 800) {
      return 'ALERT'; // 700
    } else {
      return 'EMERGENCY'; // 800
    }
  }

  @override
  String format(LogRecord entry) {
    final className = entry.loggerName ??
        (entry.instance != null
            ? entry.instance!.runtimeType.toString()
            : entry.className);

    final map = <String, dynamic>{
      'severity': _gcpSeverity(entry.level),
      'message': entry.message?.toString(),
      'timestamp': entry.date.toIso8601String(),
    };

    // Add log name if provided
    if (logName != null) {
      map['logName'] = projectId != null
          ? 'projects/$projectId/logs/$logName'
          : 'logs/$logName';
    }

    // Add labels for classification
    final labels = <String, String>{};
    if (className != null) {
      labels['class'] = className;
    }
    if (entry.instanceHash != null) {
      labels['instance_hash'] =
          entry.instanceHash!.toRadixString(16).padLeft(8, '0');
    }
    if (labels.isNotEmpty) {
      map['labels'] = labels;
    }

    // Merge structured data at root level for GCP
    if (entry.data != null) {
      for (final kv in entry.data!.entries) {
        // Avoid overwriting reserved GCP fields
        if (!map.containsKey(kv.key)) {
          map[kv.key] = kv.value;
        }
      }
    }

    // Add error information
    if (entry.error != null) {
      map['error'] = entry.error.toString();
    }

    if (entry.stackTrace != null) {
      map['stackTrace'] = entry.stackTrace.toString();
    }

    return jsonEncode(map);
  }
}
