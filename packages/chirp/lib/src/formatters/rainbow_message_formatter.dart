import 'package:chirp/chirp.dart';

export 'package:chirp/src/span/span_foundation.dart';

/// Default colored formatter using the span-based templating system.
class RainbowMessageFormatter extends SpanBasedFormatter {
  final int metaWidth;
  final RainbowFormatOptions options;

  RainbowMessageFormatter({
    this.metaWidth = 80,
    RainbowFormatOptions? options,
    super.spanTransformers,
  }) : options = options ?? const RainbowFormatOptions();

  @override
  bool get requiresCallerInfo =>
      options.showLocation || options.showClass || options.showMethod;

  @override
  LogSpan buildSpan(LogRecord record) {
    final effectiveOptions = options.merge(
        record.formatOptions?.firstWhereTypeOrNull<RainbowFormatOptions>());

    return _buildRainbowLogSpan(
      record: record,
      options: effectiveOptions,
    );
  }
}

LogSpan dimmed(LogSpan span) {
  return AnsiStyled(
    dim: true,
    foreground: Ansi256.white_7,
    child: span,
  );
}

/// Builds a span tree for a [LogRecord] with rainbow colors.
LogSpan _buildRainbowLogSpan({
  required LogRecord record,
  required RainbowFormatOptions options,
}) {
  final callerInfo = record.callerInfo;

  final levelColor = () {
    final level = record.level;
    if (level > ChirpLogLevel.error) return Ansi256.indianRed1_203;
    if (level >= ChirpLogLevel.error) return Ansi256.indianRed_167;
    if (level > ChirpLogLevel.warning) return Ansi256.lightSalmon3_173;
    if (level >= ChirpLogLevel.warning) return Ansi256.lightGoldenrod3_179;
    if (level == ChirpLogLevel.success) return Ansi256.green_2;
    return null;
  }();

  final spans = <LogSpan>[];

  // Timestamp
  if (options.showTime) {
    spans.addAll([dimmed(Timestamp(record.timestamp))]);
  }

  // Level
  if (options.showLogLevel) {
    spans.addAll([
      Surrounded(
        prefix: Whitespace(),
        child: AnsiStyled(
          foreground: levelColor ?? Ansi256.white_7,
          child: BracketedLogLevel(record.level),
        ),
      )
    ]);
  }

  // Location
  if (options.showLocation) {
    final fileName = callerInfo?.callerFileName;
    final location = fileName == null
        ? null
        : AnsiStyled(
            foreground: Ansi256.lightSkyBlue3_110,
            child: DartSourceCodeLocation(
                fileName: fileName, line: callerInfo?.line),
          );
    spans.add(Surrounded(prefix: Whitespace(), child: location));
  }

  // Logger name
  if (options.showLogger) {
    final name = record.loggerName;
    final loggerName = name == null
        ? null
        : AnsiStyled(
            foreground: colorForHash(name, saturation: ColorSaturation.high),
            child: LoggerName(name),
          );
    spans.add(Surrounded(prefix: Whitespace(), child: loggerName));
  }

  // Class name
  if (options.showClass) {
    final classNameSpan = ClassName.fromRecord(record, hashLength: 4);
    LogSpan? className;
    if (classNameSpan != null) {
      className = AnsiStyled(
        foreground:
            colorForHash(classNameSpan.name, saturation: ColorSaturation.low),
        child: classNameSpan,
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
      methodName = AnsiStyled(
        foreground: colorForHash(name, saturation: ColorSaturation.low),
        child: MethodName(name),
      );
    }
    spans.add(Surrounded(prefix: Whitespace(), child: methodName));
  }

  // Message
  spans.addAll([
    Whitespace(),
    if (levelColor == null)
      dimmed(LogMessage(record.message))
    else
      AnsiStyled(
        foreground: levelColor,
        child: LogMessage(record.message),
      ),
  ]);

  // Data
  final data = record.data;
  if (data.isNotEmpty) {
    final dataSpan = switch (options.data) {
      DataPresentation.inline => InlineData(data),
      DataPresentation.multiline => MultilineData(data),
    };
    if (levelColor == null) {
      spans.add(dimmed(dataSpan));
    } else {
      spans.add(AnsiStyled(
        foreground: levelColor,
        child: dataSpan,
      ));
    }
  }

  // Error
  if (record.error != null) {
    spans.addAll([
      NewLine(),
      AnsiStyled(
        foreground: levelColor ?? Ansi256.grey50_244,
        child: ErrorSpan(record.error),
      ),
    ]);
  }

  // Stack trace
  if (record.stackTrace case final stackTrace?) {
    spans.addAll([
      NewLine(),
      AnsiStyled(
        foreground: levelColor ?? Ansi256.grey50_244,
        child: StackTraceSpan(stackTrace),
      ),
    ]);
  }

  return SpanSequence(children: spans);
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
