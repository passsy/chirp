import 'package:chirp/chirp.dart';
import 'package:chirp/src/readable_colors.g.dart';
import 'package:chirp/src/stack_trace_util.dart';
import 'package:chirp/src/xterm_colors.g.dart';

/// Function type for transforming an instance into a display name.
///
/// Return a non-null string to use that as the class name,
/// or null to try the next transformer.
typedef ClassNameTransformer = String? Function(Object instance);

/// Default colored formatter (from experiment code)
class RainbowMessageFormatter extends ConsoleMessageFormatter {
  /// Width of the metadata section (timestamp + padding + label)
  final int metaWidth;

  /// Class name transformers for resolving instance class names
  final List<ClassNameTransformer> classNameTransformers;

  /// Formatting options for this formatter
  final RainbowFormatOptions options;

  RainbowMessageFormatter({
    List<ClassNameTransformer>? classNameTransformers,
    this.metaWidth = 80,
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

  @override
  void format(LogRecord record, ConsoleMessageBuilder builder) {
    // Check for plain layout option
    final effectiveOptions = options.merge(
        record.formatOptions?.firstWhereTypeOrNull<RainbowFormatOptions>());

    // Create layout context
    final context = _LayoutContext(
      formatter: this,
      record: record,
      builder: builder,
      effectiveOptions: effectiveOptions,
    );

    // Select and apply layout
    if (effectiveOptions.layout == LayoutStyle.plain) {
      _PlainLayout().format(context);
    } else {
      _AlignedLayout().format(context);
    }
  }
}

/// Format options specific to [RainbowMessageFormatter]
///
/// Extends [FormatOptions] to provide type safety for rainbow formatter options.
class RainbowFormatOptions extends FormatOptions {
  const RainbowFormatOptions({
    this.data = DataPresentation.inline,
    this.layout = LayoutStyle.aligned,
  });

  final DataPresentation data;
  final LayoutStyle layout;

  /// Merge this options with another, preferring values from [other]
  RainbowFormatOptions merge(RainbowFormatOptions? other) {
    final merged = RainbowFormatOptions(
      data: other?.data ?? data,
      layout: other?.layout ?? layout,
    );
    return merged;
  }
}

enum LayoutStyle {
  /// Aligned layout with metadata, pipes, colors, and indentation
  aligned,

  /// Plain layout - only message and data at left margin, no metadata or formatting
  ///
  /// Useful for copying output without needing to strip formatting.
  /// Example output:
  /// ```txt
  /// Line 1
  /// Line 2
  /// key=value
  /// ```
  plain,
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

extension _FirstWhereTypeOrNull<T> on Iterable<T> {
  R? firstWhereTypeOrNull<R>() {
    return whereType<R>().firstOrNull;
  }
}

/// Shared context for layout formatters.
class _LayoutContext {
  final RainbowMessageFormatter formatter;
  final LogRecord record;
  final ConsoleMessageBuilder builder;
  final RainbowFormatOptions effectiveOptions;

  _LayoutContext({
    required this.formatter,
    required this.record,
    required this.builder,
    required this.effectiveOptions,
  });

  /// Level-based color for messages
  late final XtermColor? levelColor = () {
    if (record.level.severity >= 500) {
      return XtermColor.color167; // red for errors
    } else if (record.level.severity >= 400) {
      return XtermColor.color179; // orange for warnings
    }
    return null;
  }();

  /// Caller info from stack trace
  late final StackFrameInfo? callerInfo = record.callerInfo;

  /// Instance label like "UserService@a1b2"
  late final String? instanceLabel =
      record.instanceLabel(formatter.resolveClassName);

  /// Subtle colors for methods
  static const subtleColors = [
    ...readableColorsLowSaturation,
    ...readableColorsMediumSaturation,
  ];

  /// Time segment like "12:34:56.789"
  late final _StyledSegment timeSegment =
      (text: record.formattedTime, color: XtermColor.brightBlack);

  /// Location segment like "main:279"
  late final _StyledSegment? locationSegment = () {
    final location = callerInfo?.callerLocation;
    if (location == null) return null;
    return (text: location, color: XtermColor.brightBlack);
  }();

  /// Method segment like "processUser"
  late final _StyledSegment? methodSegment = () {
    if (callerInfo == null) return null;

    final method = callerInfo!.callerMethod;
    final className = callerInfo!.callerClassName;

    String methodName;
    if (className != null && method.startsWith('$className.')) {
      methodName = method.substring(className.length + 1);
    } else {
      methodName = method;
    }

    return (text: methodName, color: hashColor(methodName, subtleColors));
  }();

  /// Class/instance segment like "UserService@a1b2" or "UserService"
  late final _StyledSegment? classSegment = () {
    if (instanceLabel != null) {
      return (
        text: instanceLabel!,
        color: hashColor(instanceLabel!, readableColorsLowSaturation),
      );
    } else if (callerInfo?.callerClassName != null) {
      final className = callerInfo!.callerClassName!;
      return (
        text: className,
        color: hashColor(className, readableColorsLowSaturation),
      );
    }
    return null;
  }();

  /// Logger name segment
  late final _StyledSegment? loggerSegment = () {
    if (record.loggerName == null) return null;
    return (
      text: record.loggerName!,
      color: hashColor(record.loggerName!, readableColorsHighSaturation),
    );
  }();
}

/// Plain layout - metadata line in color, then message/data at left margin.
class _PlainLayout {
  void format(_LayoutContext context) {
    final formatter = context.formatter;
    final entry = context.record;
    final builder = context.builder;

    const greyColor = XtermColor.brightBlack;

    // Level-based color for messages (different from penColor which is hash-based)
    final XtermColor? levelColor;
    if (entry.level.severity >= 500) {
      levelColor = XtermColor.color167; // red for errors
    } else if (entry.level.severity >= 400) {
      levelColor = XtermColor.color179; // orange for warnings
    } else if (entry.level.severity >= 300) {
      levelColor = null; // default for notices
    } else {
      levelColor = greyColor; // grey for info/debug/trace
    }

    final messageColor = levelColor;
    final dataColor = levelColor;
    const pipeColor = greyColor;
    final stackTraceColor = levelColor;

    // Compute caller info and label
    final callerInfo = entry.callerInfo;

    final instanceLabel = entry.instanceLabel(formatter.resolveClassName);

    final String? extractedMethodName = () {
      if (instanceLabel != null && callerInfo != null) {
        final method = callerInfo.callerMethod;
        final instanceClass = instanceLabel.split('@').first;
        if (method.startsWith('$instanceClass.')) {
          return method.substring(instanceClass.length + 1);
        }
      }
      return null;
    }();

    // Build label parts for separate styling
    final location = callerInfo?.callerLocation; // main:279
    final String? methodPart; // processUser or UserService.processUser
    final String? coloredPart; // UserService@57c5 (gets penColor)

    if (extractedMethodName != null) {
      methodPart = extractedMethodName;
      coloredPart = instanceLabel;
    } else if (instanceLabel != null && callerInfo != null) {
      methodPart = callerInfo.callerMethod;
      coloredPart = instanceLabel;
    } else if (instanceLabel != null) {
      methodPart = null;
      coloredPart = instanceLabel;
    } else if (callerInfo?.callerClassName != null) {
      methodPart = callerInfo!
          .callerMethod
          .substring(callerInfo.callerClassName!.length + 1);
      coloredPart = callerInfo.callerClassName;
    } else if (callerInfo != null) {
      methodPart = callerInfo.callerMethod;
      coloredPart = null;
    } else {
      methodPart = null;
      coloredPart = null;
    }

    // Print metadata line with separate colors for each part
    final formattedTime = entry.formattedTime;
    builder.write(formattedTime, foreground: greyColor);
    if (location != null) {
      builder.write(' ');
      builder.write(location, foreground: greyColor);
    }
    if (methodPart != null) {
      builder.write(' ');
      // Color methodPart based on its own hash (low+medium saturation)
      final subtleColors = [
        ...readableColorsLowSaturation,
        ...readableColorsMediumSaturation,
      ];
      final methodColor = subtleColors.isNotEmpty
          ? subtleColors[methodPart.hashCode.abs() % subtleColors.length]
          : greyColor;
      builder.write(methodPart, foreground: methodColor);
    }
    if (coloredPart != null) {
      builder.write(' ');
      builder.write(coloredPart,
          foreground: hashColor(coloredPart, readableColorsLowSaturation));
    }
    if (entry.loggerName != null) {
      builder.write(' ');
      // Color logger name based on its hash (high saturation for visibility)
      final loggerNameColor = readableColorsHighSaturation.isNotEmpty
          ? readableColorsHighSaturation[entry.loggerName.hashCode.abs() %
              readableColorsHighSaturation.length]
          : greyColor;
      builder.write(entry.loggerName!, foreground: loggerNameColor);
    }
    // builder.write(' │ <plain message below>', foreground: pipeColor);
    builder.write(' <plain message below>', foreground: pipeColor);

    // Add message at left margin in grey (or warning/error color)
    final messageStr = entry.message?.toString() ?? '';
    if (messageStr.isNotEmpty) {
      for (final line in messageStr.split('\n')) {
        builder.write('\n');
        builder.write(line, foreground: messageColor);
      }
    }

    // Add data at left margin in grey (or warning/error color)
    if (entry.data != null && entry.data!.isNotEmpty) {
      for (final dataEntry in entry.data!.entries) {
        builder.write('\n');
        builder.write('${dataEntry.key}=${dataEntry.value}',
            foreground: dataColor);
      }
    }

    // Add error/stacktrace if present (in warning/error color)
    if (entry.error != null) {
      for (final line in entry.error.toString().split('\n')) {
        builder.write('\n');
        builder.write(line, foreground: levelColor);
      }
    }
    if (entry.stackTrace != null) {
      for (final line in entry.stackTrace.toString().split('\n')) {
        builder.write('\n');
        builder.write(line, foreground: stackTraceColor);
      }
    }
  }
}

/// A styled text segment with text and optional color.
typedef _StyledSegment = ({String text, XtermColor? color});

/// Aligned layout with metadata, pipes, colors, and indentation.
class _AlignedLayout {
  void format(_LayoutContext context) {
    final levelColor = context.levelColor;
    final messageColor = levelColor ?? XtermColor.brightBlack;
    final dataColor = levelColor ?? XtermColor.brightBlack;
    const pipeColor = XtermColor.brightBlack;
    final stackTraceColor = levelColor ?? XtermColor.brightBlack;

    // Build segments from individual getters
    final segments = [
      context.timeSegment,
      context.locationSegment,
      context.methodSegment,
      context.classSegment,
      context.loggerSegment,
    ].whereType<_StyledSegment>().toList();

    // Calculate widths
    final metaText = segments.map((s) => s.text).join(' ');
    final messageStr = context.record.message?.toString() ?? '';
    final messageLines = messageStr.split('\n');
    final indent = ''.padRight(metaText.length);

    // Add grey pipe separator before warnings/errors
    if (context.record.level.severity >= 400) {
      context.builder.write('$indent\n', foreground: XtermColor.brightBlack);
    }

    // Write segments
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) context.builder.write(' ');
      final segment = segments[i];
      context.builder.write(segment.text, foreground: segment.color);
    }

    context.builder.write(' ', foreground: pipeColor);

    // Write message
    if (messageLines.length <= 1) {
      context.builder.write(messageStr, foreground: messageColor);
    } else {
      context.builder.write(messageLines[0], foreground: messageColor);
      for (var i = 1; i < messageLines.length; i++) {
        context.builder.write('\n');
        context.builder.write(indent, foreground: XtermColor.brightBlack);
        context.builder.write(' ', foreground: pipeColor);
        context.builder.write(messageLines[i], foreground: messageColor);
      }
    }

    // Write data
    if (context.record.data != null && context.record.data!.isNotEmpty) {
      if (context.effectiveOptions.data == DataPresentation.inline) {
        final dataStr = context.record.data!.entries
            .map((e) => '${e.key}=${e.value}')
            .join(', ');
        context.builder.write(' ($dataStr)', foreground: dataColor);
      } else {
        for (final dataEntry in context.record.data!.entries) {
          context.builder.write('\n');
          context.builder.write('$indent ${dataEntry.key}=${dataEntry.value}',
              foreground: dataColor);
        }
      }
    }

    // Write error
    if (context.record.error != null) {
      for (final line in context.record.error.toString().split('\n')) {
        context.builder.write('\n');
        context.builder.write(line, foreground: levelColor);
      }
    }

    // Write stack trace
    if (context.record.stackTrace != null) {
      for (final line in context.record.stackTrace.toString().split('\n')) {
        context.builder.write('\n');
        context.builder.write(line, foreground: stackTraceColor);
      }
    }
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

XtermColor hashColor(Object? object, List<XtermColor> colors) {
  final hash = object.hashCode.abs();
  if (colors.isEmpty) {
    throw ArgumentError('colors must not be empty');
  }
  return colors[hash % colors.length];
}
