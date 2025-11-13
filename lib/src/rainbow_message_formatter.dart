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

  /// Whether to use ANSI color codes in output
  final bool color;

  /// Formatting options for this formatter
  final RainbowFormatOptions options;

  RainbowMessageFormatter({
    List<ClassNameTransformer>? classNameTransformers,
    this.metaWidth = 80,
    this.color = true,
    RainbowFormatOptions? options,
  })  : options = options ?? const RainbowFormatOptions(),
        classNameTransformers = classNameTransformers ?? [],
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

  /// Remove anonymous closure markers from method names
  String _cleanMethodName(String methodName) {
    return methodName.replaceAll('.<anonymous closure>', '');
  }

  @override
  String format(LogRecord entry) {
    ansiColorDisabled = !color;

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
          final methodName = method.substring(instanceClass.length + 1);
          return _cleanMethodName(methodName);
        }
      }
      return null;
    }();

    final label = [
      callerInfo?.callerLocation, // main:166
      if (extractedMethodName != null) ...[
        extractedMethodName, // processUser
        instanceInfo, // UserService@1fec
      ] else if (instanceInfo != null && callerInfo != null) ...[
        _cleanMethodName(callerInfo.callerMethod), // UserService.processUser
        instanceInfo, // UserService@1fec
      ] else if (instanceInfo != null) ...[
        instanceInfo, // UserService@1fec (no caller info)
      ] else if (callerInfo?.callerClassName != null) ...[
        // No instance but has class name - split method and class for static methods
        // For "UserService.logStatic", show "logStatic" then "UserService"
        _cleanMethodName(callerInfo!.callerMethod
            .substring(callerInfo.callerClassName!.length + 1)), // logStatic
        callerInfo.callerClassName, // UserService
      ] else if (callerInfo?.callerMethod != null)
        // Top-level function - show as is
        _cleanMethodName(callerInfo!.callerMethod),
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
      // Use per-message formatOptions if provided, otherwise use formatter's default
      final effectiveOptions = options.merge(
          entry.formatOptions?.firstWhereTypeOrNull<RainbowFormatOptions>());

      if (effectiveOptions.data == DataPresentation.inline) {
        // Inline mode: write all data on a single line
        final dataStr =
            entry.data!.entries.map((e) => '${e.key}=${e.value}').join(', ');
        dataBuffer.write(' ($dataStr)');
      } else {
        // Multi-line mode: one property per line with indentation
        // Calculate indentation to align with the │ separator
        // meta is actualMetaWidth chars, then we add " │ "
        // so │ is at position actualMetaWidth+1
        // For data lines: actualMetaWidth spaces + " │" puts │ at actualMetaWidth+1
        final indent = ''.padRight(actualMetaWidth);

        for (final dataEntry in entry.data!.entries) {
          dataBuffer.write('\n$indent │ ${dataEntry.key}=${dataEntry.value}');
        }
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
    final dataStr = dataBuffer.toString();
    final effectiveOptions = options.merge(
        entry.formatOptions?.firstWhereTypeOrNull<RainbowFormatOptions>());
    final coloredDataLines = dataStr.isNotEmpty &&
            effectiveOptions.data == DataPresentation.multiline
        ? dataStr.split('\n').map((line) => pen(line)).join('\n')
        : '';
    final inlineDataStr =
        dataStr.isNotEmpty && effectiveOptions.data == DataPresentation.inline
            ? pen(dataStr)
            : '';
    final coloredExtraLines = extraLines.isNotEmpty
        ? extraLines.split('\n').map((line) => pen('  $line')).join('\n')
        : '';

    // Build final output
    final output = StringBuffer();
    if (messageLines.length <= 1) {
      output.write(pen('$meta │ $messageStr'));
      if (inlineDataStr.isNotEmpty) {
        output.write(inlineDataStr);
      }
      if (coloredDataLines.isNotEmpty) {
        output.write(coloredDataLines);
      }
      if (coloredExtraLines.isNotEmpty) {
        output.write(coloredExtraLines);
      }
    } else {
      // Multiline message: indent all lines to align with │
      final indent = ''.padRight(actualMetaWidth);
      output.write(pen(meta));
      output.write(pen(' │ \n'));
      output.write(
          messageLines.map((line) => pen('$indent │ $line')).join('\n'));
      if (inlineDataStr.isNotEmpty) {
        output.write(inlineDataStr);
      }
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

/// Format options specific to [RainbowMessageFormatter]
///
/// Extends [FormatOptions] to provide type safety for rainbow formatter options.
class RainbowFormatOptions extends FormatOptions {
  const RainbowFormatOptions({this.data = DataPresentation.multiline});

  final DataPresentation data;

  /// Merge this options with another, preferring values from [other]
  RainbowFormatOptions merge(RainbowFormatOptions? other) {
    final merged = RainbowFormatOptions(
      data: other?.data ?? data,
    );
    return merged;
  }
}

enum DataPresentation {
  /// Display all data properties inline on the same line as the message
  ///
  /// Example: `User logged in (userId=user_123, action=login)`
  inline,

  /// Display each data property on a separate line
  ///
  /// Example:
  /// ```txt
  /// User logged in
  /// │ userId=user_123
  /// │ action=login
  /// ```
  multiline,
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

extension _FirstWhereTypeOrNull<T> on Iterable<T> {
  R? firstWhereTypeOrNull<R>() {
    return whereType<R>().firstOrNull;
  }
}
