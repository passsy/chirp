import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

export 'package:chirp/src/span/span_foundation.dart';

/// Default colored formatter using the span-based templating system.
///
/// Output format:
/// ```text
/// 10:30:45.123 UserService@a1b2 [info] User logged in (userId: "abc")
/// ```
///
/// Uses ANSI colors to highlight different parts: timestamp (dim), class names
/// (unique color per class), log levels (color-coded by severity), and more.
class RainbowMessageFormatter extends SpanBasedFormatter {
  /// Width reserved for metadata (timestamp, class, level) before the message.
  ///
  /// Longer metadata is truncated; shorter is padded for alignment.
  // ignore: deprecated_consistency
  final int metaWidth;

  /// Controls which elements are shown in the output.
  final RainbowFormatOptions options;

  /// Creates a rainbow message formatter.
  ///
  /// - [metaWidth]: Width for metadata column (default: 80)
  /// - [options]: Controls visibility of timestamp, level, class, etc.
  /// - [spanTransformers]: Customize the span tree before rendering
  RainbowMessageFormatter({
    @Deprecated(
        "This feature has been removed and setting metaWidth has no effect")
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
      LogMessage(record.message)
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
      DataPresentation.inline => Surrounded(
          prefix: PlainText(' ('),
          child: InlineData(data),
          suffix: PlainText(')'),
        ),
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

/// Format options for [RainbowMessageFormatter].
///
/// Controls which elements are displayed in the formatted log output.
class RainbowFormatOptions extends FormatOptions {
  /// Creates format options for the rainbow formatter.
  const RainbowFormatOptions({
    this.data = DataPresentation.inline,
    this.showTime = true,
    this.showLocation = true,
    this.showLogger = true,
    this.showClass = true,
    this.showMethod = true,
    this.showLogLevel = true,
  });

  /// How structured data is rendered ([DataPresentation.inline] or multiline).
  final DataPresentation data;

  /// Whether to show the timestamp.
  final bool showTime;

  /// Whether to show the source code location.
  final bool showLocation;

  /// Whether to show the logger name.
  final bool showLogger;

  /// Whether to show the class name.
  final bool showClass;

  /// Whether to show the method name.
  final bool showMethod;

  /// Whether to show the log level.
  final bool showLogLevel;

  /// Merges [other] options into this, with [other] values taking precedence.
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

/// How structured data should be rendered in log output.
///
/// Used by [RainbowFormatOptions.dataPresentation] to control data rendering.
enum DataPresentation {
  /// Data is rendered on the same line as the message.
  inline,

  /// Data is rendered on separate lines below the message.
  multiline,
}

extension _FirstWhereTypeOrNull<T> on Iterable<T> {
  R? firstWhereTypeOrNull<R>() => whereType<R>().firstOrNull;
}
