import 'package:ansicolor/ansicolor.dart';
import 'package:chirp/chirp.dart';
import 'package:chirp/src/stack_trace_util.dart';

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
    this.metaWidth = 80,
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

    final StackFrameInfo? callerInfo = () {
      if (entry.caller != null) {
        return getCallerInfo(entry.caller!);
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
        return '$className@$shortHash';
      }
      return null;
    }();

    // Extract method name if instanceInfo and callerMethod share the same class name
    final String? extractedMethodName = () {
      if (instanceInfo != null && callerInfo?.callerMethod != null) {
        final method = callerInfo!.callerMethod;
        // Extract class name from instanceInfo (e.g., "UserService" from "UserService@1fec")
        final instanceClass = instanceInfo.split('@').first;

        // Check if method starts with the same class name
        if (method.startsWith('$instanceClass.')) {
          // Extract just the method name (e.g., "processUser" from "UserService.processUser")
          return method.substring(instanceClass.length + 1);
        }
      }
      return null;
    }();

    final label = [
      callerInfo?.callerLocation, // main:166
      if (extractedMethodName != null) ...[
        extractedMethodName, // processUser
        instanceInfo, // UserService@1fec
      ] else if (instanceInfo != null) ...[
        callerInfo?.callerMethod, // UserService.processUser
        instanceInfo, // UserService@1fec
      ] else if (callerInfo?.callerClassName != null) ...[
        // No instance but has class name - split method and class for static methods
        // For "UserService.logStatic", show "logStatic" then "UserService"
        callerInfo!.callerMethod
            .substring(callerInfo.callerClassName!.length + 1), // logStatic
        callerInfo.callerClassName, // UserService
      ] else
        // Top-level function - show as is
        callerInfo?.callerMethod,
      entry.loggerName // UserLogger
    ].whereType<Object>().join(" ");

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
        if (entry.instance != null) {
          return entry.instance.runtimeType.toString();
        }
        if (entry.loggerName != null) return entry.loggerName;
        if (callerInfo?.callerClassName != null) {
          return callerInfo!.callerClassName;
        }
        final name = callerInfo?.callerName;
        if (name != null) {
          return name;
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

        // Vary lightness based on instance hash to differentiate instances
        // Lightness range: 0.6 to 0.8 (readable range)
        if (entry.instanceHash != null) {
          const minLightness = 0.6;
          const maxLightness = 0.8;
          const lightnessRange = maxLightness - minLightness;
          final lightnessOffset =
              (entry.instanceHash!.abs() % 100) / 100.0 * lightnessRange;
          lightness = minLightness + lightnessOffset;
        }
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

    // Calculate actual meta width (can exceed metaWidth if label is very long)
    final actualMetaWidth = meta.length;

    // Split message into lines
    final messageStr = entry.message?.toString() ?? '';
    final messageLines = messageStr.split('\n');

    // Build data lines with indentation to align after │
    final dataBuffer = StringBuffer();
    if (entry.data != null && entry.data!.isNotEmpty) {
      // Calculate indentation to align with the │ separator
      // meta is actualMetaWidth chars, then we add " │ "
      // so │ is at position actualMetaWidth+1
      // For data lines: actualMetaWidth spaces + " │" puts │ at actualMetaWidth+1
      final indent = ''.padRight(actualMetaWidth);

      for (final dataEntry in entry.data!.entries) {
        dataBuffer.write('\n$indent │ ${dataEntry.key}=${dataEntry.value}');
      }
    }

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
    final coloredDataLines = dataBuffer.toString().isNotEmpty
        ? dataBuffer.toString().split('\n').map((line) => pen(line)).join('\n')
        : '';
    final coloredExtraLines = extraLines.isNotEmpty
        ? extraLines.split('\n').map((line) => pen(line)).join('\n')
        : '';

    // Build final output
    final output = StringBuffer();
    if (messageLines.length <= 1) {
      output.write(pen('$meta │ $messageStr'));
      if (coloredDataLines.isNotEmpty) {
        output.write(coloredDataLines);
      }
      if (coloredExtraLines.isNotEmpty) {
        output.write(coloredExtraLines);
      }
    } else {
      output.write(pen(meta));
      output.write(' │ \n');
      output.write(messageLines.map((line) => pen(line)).join('\n'));
      if (coloredDataLines.isNotEmpty) {
        output.write(coloredDataLines);
      }
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
