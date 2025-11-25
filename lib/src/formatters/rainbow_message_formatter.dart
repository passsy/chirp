import 'package:chirp/chirp.dart';
import 'package:chirp/src/readable_colors.g.dart';
import 'package:chirp/src/xterm_colors.g.dart';

export 'package:chirp/src/formatters/log_span.dart';

/// Function type for transforming an instance into a display name.
typedef ClassNameTransformer = String? Function(Object instance);

const _subtleColors = [
  ...readableColorsLowSaturation,
  ...readableColorsMediumSaturation,
];

/// Default colored formatter using the span-based templating system.
class RainbowMessageFormatter extends ConsoleMessageFormatter {
  final int metaWidth;
  final List<ClassNameTransformer> classNameTransformers;
  final RainbowFormatOptions options;
  final List<SpanTransformer> spanTransformers;

  RainbowMessageFormatter({
    List<ClassNameTransformer>? classNameTransformers,
    this.metaWidth = 80,
    RainbowFormatOptions? options,
    List<SpanTransformer>? spanTransformers,
  })  : options = options ?? const RainbowFormatOptions(),
        classNameTransformers = classNameTransformers ?? [],
        spanTransformers = spanTransformers ?? [],
        super();

  String resolveClassName(Object instance) {
    for (final transformer in classNameTransformers) {
      final result = transformer(instance);
      if (result != null) return result;
    }
    return instance.runtimeType.toString();
  }

  @override
  void format(LogRecord record, ConsoleMessageBuilder builder) {
    final effectiveOptions = options.merge(
        record.formatOptions?.firstWhereTypeOrNull<RainbowFormatOptions>());

    var span = buildSpan(record, effectiveOptions);

    for (final transformer in spanTransformers) {
      span = transformer(span, record);
    }

    renderSpan(span, builder);
  }

  LogSpan buildSpan(LogRecord record, RainbowFormatOptions options) {
    final callerInfo = record.callerInfo;
    final instanceLabel = record.instanceLabel(resolveClassName);

    final levelColor = switch (record.level.severity) {
      > 500 => XtermColor.color203,
      500 => XtermColor.color167,
      > 400 => XtermColor.color173,
      400 => XtermColor.color179,
      _ => null,
    };

    final spans = <LogSpan>[];

    // Timestamp
    if (options.showTime) {
      spans.add(Styled(
        foreground: XtermColor.brightBlack,
        child: Timestamp(record.date),
      ));
    }

    // Location
    if (options.showLocation) {
      final fileName = callerInfo?.callerFileName;
      final location = fileName == null
          ? null
          : Styled(
              foreground: XtermColor.brightBlack,
              child: Location(fileName: fileName, line: callerInfo?.line),
            );
      spans.add(Prefixed(prefix: const Space(), child: location));
    }

    // Logger name
    if (options.showLogger) {
      final name = record.loggerName;
      final loggerName = name == null
          ? null
          : Styled(
              foreground: hashColor(name, readableColorsHighSaturation),
              child: LoggerName(name),
            );
      spans.add(Prefixed(prefix: const Space(), child: loggerName));
    }

    // Class name
    if (options.showClass) {
      LogSpan? className;
      if (instanceLabel != null) {
        className = Styled(
          foreground: hashColor(instanceLabel, readableColorsLowSaturation),
          child: ClassName(
            instanceLabel,
            instanceHash: record.instanceHash?.toRadixString(16),
          ),
        );
      } else if (callerInfo?.callerClassName != null) {
        final cn = callerInfo!.callerClassName!;
        className = Styled(
          foreground: hashColor(cn, readableColorsLowSaturation),
          child: ClassName(cn),
        );
      }
      spans.add(Prefixed(prefix: const Space(), child: className));
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
        methodName = Styled(
          foreground: hashColor(name, _subtleColors),
          child: MethodName(name),
        );
      }
      spans.add(Prefixed(prefix: const Space(), child: methodName));
    }

    // Level
    if (options.showLogLevel) {
      spans.addAll([
        const Space(),
        Styled(
          foreground: levelColor ?? XtermColor.brightBlack,
          child: Level(record.level),
        ),
      ]);
    }

    // Message
    spans.addAll([
      const Space(),
      Styled(
        foreground: levelColor ?? XtermColor.brightBlack,
        child: Message(record.message),
      ),
    ]);

    // Data
    final data = record.data;
    if (data != null && data.isNotEmpty) {
      final dataSpan = switch (options.data) {
        DataPresentation.inline => InlineData(data),
        DataPresentation.multiline => MultilineData(data),
      };
      spans.add(Styled(
        foreground: levelColor ?? XtermColor.brightBlack,
        child: dataSpan,
      ));
    }

    // Error
    if (record.error != null) {
      spans.addAll([
        const NewLine(),
        Styled(foreground: levelColor, child: Error(record.error)),
      ]);
    }

    // Stack trace
    if (record.stackTrace case final stackTrace?) {
      spans.addAll([
        const NewLine(),
        Styled(
          foreground: levelColor ?? XtermColor.brightBlack,
          child: StackTraceSpan(stackTrace),
        ),
      ]);
    }

    return Row(spans);
  }
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
