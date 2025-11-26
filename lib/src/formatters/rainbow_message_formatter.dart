import 'package:chirp/chirp.dart';
import 'package:chirp/src/readable_colors.g.dart';

export 'package:chirp/src/span/span_foundation.dart';

/// Function type for transforming an instance into a display name.
typedef ClassNameTransformer = String? Function(Object instance);

const _subtleColors = [
  ...readableColorsLowSaturation,
  ...readableColorsMediumSaturation,
];

/// Default colored formatter using the span-based templating system.
class RainbowMessageFormatter extends SpanBasedFormatter {
  final int metaWidth;
  final List<ClassNameTransformer> classNameTransformers;
  final RainbowFormatOptions options;

  RainbowMessageFormatter({
    List<ClassNameTransformer>? classNameTransformers,
    this.metaWidth = 80,
    RainbowFormatOptions? options,
    super.spanTransformers,
  })  : options = options ?? const RainbowFormatOptions(),
        classNameTransformers = classNameTransformers ?? [];

  String resolveClassName(Object instance) {
    for (final transformer in classNameTransformers) {
      final result = transformer(instance);
      if (result != null) return result;
    }
    return instance.runtimeType.toString();
  }

  @override
  LogSpan buildSpan(LogRecord record) {
    final effectiveOptions = options.merge(
        record.formatOptions?.firstWhereTypeOrNull<RainbowFormatOptions>());

    return _buildRainbowLogSpan(
      record: record,
      options: effectiveOptions,
      classNameResolver: resolveClassName,
    );
  }
}

/// Builds a span tree for a [LogRecord] with rainbow colors.
LogSpan _buildRainbowLogSpan({
  required LogRecord record,
  required RainbowFormatOptions options,
  required String Function(Object) classNameResolver,
}) {
  final callerInfo = record.callerInfo;
  final instanceLabel = record.instanceLabel(classNameResolver);

  final levelColor = switch (record.level.severity) {
    > 500 => XtermColor.indianRed1_203,
    500 => XtermColor.indianRed_167,
    > 400 => XtermColor.lightSalmon3_173,
    400 => XtermColor.lightGoldenrod3_179,
    _ => null,
  };

  final spans = <LogSpan>[];

  // Timestamp
  if (options.showTime) {
    spans.add(AnsiColored(
      foreground: XtermColor.brightBlack_8,
      child: Timestamp(record.date),
    ));
  }

  // Location
  if (options.showLocation) {
    final fileName = callerInfo?.callerFileName;
    final location = fileName == null
        ? null
        : AnsiColored(
            foreground: XtermColor.brightBlack_8,
            child:
                DartSourceCodeLocation(fileName: fileName, line: callerInfo?.line),
          );
    spans.add(Surrounded(prefix: Whitespace(), child: location));
  }

  // Logger name
  if (options.showLogger) {
    final name = record.loggerName;
    final loggerName = name == null
        ? null
        : AnsiColored(
            foreground: hashColor(name, readableColorsHighSaturation),
            child: LoggerName(name),
          );
    spans.add(Surrounded(prefix: Whitespace(), child: loggerName));
  }

  // Class name
  if (options.showClass) {
    LogSpan? className;
    if (instanceLabel != null) {
      className = AnsiColored(
        foreground: hashColor(instanceLabel, readableColorsLowSaturation),
        child: ClassName(instanceLabel),
      );
    } else if (callerInfo?.callerClassName != null) {
      final cn = callerInfo!.callerClassName!;
      className = AnsiColored(
        foreground: hashColor(cn, readableColorsLowSaturation),
        child: ClassName(cn),
      );
    }
    spans.add(Surrounded(prefix: Whitespace(), child: className));
  }

  // Method name
  if (options.showMethod) {
    LogSpan? methodName;
    if (callerInfo != null) {
      var name = callerInfo.callerMethod;
      final cn = callerInfo.callerClassName;
      if (cn != null && name.startsWith('$cn.')) {
        name = name.substring(cn.length + 1);
      }
      methodName = AnsiColored(
        foreground: hashColor(name, _subtleColors),
        child: MethodName(name),
      );
    }
    spans.add(Surrounded(prefix: Whitespace(), child: methodName));
  }

  // Level
  if (options.showLogLevel) {
    spans.addAll([
      Whitespace(),
      AnsiColored(
        foreground: levelColor ?? XtermColor.brightBlack_8,
        child: BracketedLogLevel(record.level),
      ),
    ]);
  }

  // Message
  spans.addAll([
    Whitespace(),
    AnsiColored(
      foreground: levelColor ?? XtermColor.brightBlack_8,
      child: LogMessage(record.message),
    ),
  ]);

  // Data
  final data = record.data;
  if (data != null && data.isNotEmpty) {
    final dataSpan = switch (options.data) {
      DataPresentation.inline => InlineData(data),
      DataPresentation.multiline => MultilineData(data),
    };
    spans.add(AnsiColored(
      foreground: levelColor ?? XtermColor.brightBlack_8,
      child: dataSpan,
    ));
  }

  // Error
  if (record.error != null) {
    spans.addAll([
      NewLine(),
      AnsiColored(foreground: levelColor, child: ErrorSpan(record.error)),
    ]);
  }

  // Stack trace
  if (record.stackTrace case final stackTrace?) {
    spans.addAll([
      NewLine(),
      AnsiColored(
        foreground: levelColor ?? XtermColor.brightBlack_8,
        child: StackTraceSpan(stackTrace),
      ),
    ]);
  }

  return SpanSequence(spans);
}

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
  final bool showTime;
  final bool showLocation;
  final bool showLogger;
  final bool showClass;
  final bool showMethod;
  final bool showLogLevel;

  RainbowFormatOptions merge(RainbowFormatOptions? other) {
    return RainbowFormatOptions(
      data: other?.data ?? data,
      showTime: other?.showTime ?? showTime,
      showLocation: other?.showLocation ?? showLocation,
      showLogger: other?.showLogger ?? showLogger,
      showClass: other?.showClass ?? showClass,
      showMethod: other?.showMethod ?? showMethod,
      showLogLevel: other?.showLogLevel ?? showLogLevel,
    );
  }
}

enum DataPresentation { inline, multiline }

extension _FirstWhereTypeOrNull<T> on Iterable<T> {
  R? firstWhereTypeOrNull<R>() => whereType<R>().firstOrNull;
}

XtermColor hashColor(Object? object, List<XtermColor> colors) {
  final hash = object.hashCode.abs();
  if (colors.isEmpty) throw ArgumentError('colors must not be empty');
  return colors[hash % colors.length];
}
