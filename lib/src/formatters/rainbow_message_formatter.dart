import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:chirp/src/readable_colors.g.dart';
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

    final levelColor = context.levelColor;
    final messageColor = levelColor ?? XtermColor.brightBlack;
    final dataColor = levelColor ?? XtermColor.brightBlack;
    final stackTraceColor = levelColor ?? XtermColor.brightBlack;

    // Build segments from individual getters, filtering by options
    final segments = [
      if (effectiveOptions.showTime) context.timeSegment,
      if (effectiveOptions.showLocation) context.locationSegment,
      if (effectiveOptions.showLogger) context.loggerSegment,
      if (effectiveOptions.showClass) context.classSegment,
      if (effectiveOptions.showMethod) context.methodSegment,
      if (effectiveOptions.showLogLevel) context.logLevelSegment,
    ].whereType<_StyledSegment>().toList();

    // Calculate widths
    final metaText = segments.map((s) => s.text).join(' ');
    final messageStr = context.record.message?.toString() ?? '';
    final indent = ''.padRight(metaText.length);

    // Add a newline before warnings/errors
    if (context.record.level.severity >= 400) {
      context.builder.write('$indent\n', foreground: XtermColor.brightBlack);
    }

    // Write segments
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) context.builder.write(' ');
      final segment = segments[i];
      context.builder.write(segment.text, foreground: segment.color);
    }

    context.builder.write(' ' /*, foreground: XtermColor.brightBlack*/
        );
    context.builder.write(messageStr, foreground: messageColor);

    // Write data
    final data = context.record.data;
    if (data != null && data.isNotEmpty) {
      if (context.effectiveOptions.data == DataPresentation.inline) {
        final dataStr = data.entries
            .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
            .join(', ');
        context.builder.write(' ($dataStr)', foreground: dataColor);
      } else {
        // YAML-like multiline format
        final yamlLines = formatAsYaml(data, 0);
        for (final line in yamlLines) {
          context.builder.write('\n');
          context.builder.write(line, foreground: dataColor);
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

/// Format options specific to [RainbowMessageFormatter]
///
/// Extends [FormatOptions] to provide type safety for rainbow formatter options.
class RainbowFormatOptions extends FormatOptions {
  const RainbowFormatOptions({
    this.data = DataPresentation.inline,
    this.showTime = true,
    this.showLocation = true,
    this.showLogger = true,
    this.showClass = true,
    this.showMethod = true,
    this.showLogLevel = true,
  });

  final DataPresentation data;

  /// Whether to show the time segment (e.g., "12:34:56.789")
  final bool showTime;

  /// Whether to show the location segment (e.g., "main.dart:279")
  final bool showLocation;

  /// Whether to show the logger name segment
  final bool showLogger;

  /// Whether to show the class/instance segment (e.g., "UserService@a1b2")
  final bool showClass;

  /// Whether to show the method segment (e.g., "processUser")
  final bool showMethod;

  /// Whether to show the log level segment (e.g., "[INFO]")
  final bool showLogLevel;

  /// Merge this options with another, preferring values from [other]
  RainbowFormatOptions merge(RainbowFormatOptions? other) {
    final merged = RainbowFormatOptions(
      data: other?.data ?? data,
      showTime: other?.showTime ?? showTime,
      showLocation: other?.showLocation ?? showLocation,
      showLogger: other?.showLogger ?? showLogger,
      showClass: other?.showClass ?? showClass,
      showMethod: other?.showMethod ?? showMethod,
      showLogLevel: other?.showLogLevel ?? showLogLevel,
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
    switch (record.level.severity) {
      case > 500:
        return XtermColor.color203;
      case 500:
        return XtermColor.color167;
      case > 400:
        return XtermColor.color173;
      case 400:
        return XtermColor.color179;
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

  late final _StyledSegment logLevelSegment = () {
    return (
      text: "[${record.level.name}]",
      color: levelColor ?? XtermColor.brightBlack
    );
  }();

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
    final label = instanceLabel;
    if (label != null) {
      return (
        text: label,
        color: hashColor(label, readableColorsLowSaturation),
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
    final loggerName = record.loggerName;
    if (loggerName == null) return null;
    return (
      text: loggerName,
      color: hashColor(loggerName, readableColorsHighSaturation),
    );
  }();
}

/// A styled text segment with text and optional color.
typedef _StyledSegment = ({String text, XtermColor? color});

XtermColor hashColor(Object? object, List<XtermColor> colors) {
  final hash = object.hashCode.abs();
  if (colors.isEmpty) {
    throw ArgumentError('colors must not be empty');
  }
  return colors[hash % colors.length];
}
