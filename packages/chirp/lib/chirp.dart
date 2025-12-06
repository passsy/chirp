/// A lightweight, flexible logging library for Dart.
///
/// Chirp provides instance tracking, child loggers, structured logging,
/// and multiple output formats with ANSI color support.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:chirp/chirp.dart';
///
/// void main() {
///   // Zero-config - works immediately
///   Chirp.info('Hello, Chirp!');
///
///   // Or configure with a custom formatter
///   Chirp.root = ChirpLogger()
///     .addConsoleWriter(formatter: RainbowMessageFormatter());
///
///   Chirp.info('User logged in', data: {'userId': 'abc123'});
/// }
/// ```
///
/// See the [README](https://pub.dev/packages/chirp) for full documentation.
library;

export 'package:chirp/src/ansi/ansi16.dart' show Ansi16;
export 'package:chirp/src/ansi/ansi256.g.dart' show Ansi256;
export 'package:chirp/src/ansi/console_color.dart'
    show ConsoleColor, DefaultColor, IndexedColor, RgbColor;
export 'package:chirp/src/ansi/hash_colors.dart'
    show ColorSaturation, colorForHash;
export 'package:chirp/src/core/chirp_interceptor.dart' show ChirpInterceptor;
export 'package:chirp/src/core/chirp_logger.dart' show ChirpLogger;
export 'package:chirp/src/core/chirp_root.dart'
    show Chirp, ChirpInstanceLogger, ChirpLoggerConsoleWriterExt, LogRecordExt;
export 'package:chirp/src/core/chirp_writer.dart' show ChirpWriter;
export 'package:chirp/src/core/format_option.dart' show FormatOptions;
export 'package:chirp/src/core/log_level.dart' show ChirpLogLevel;
export 'package:chirp/src/core/log_record.dart' show LogRecord;
export 'package:chirp/src/formatters/compact_message_formatter.dart'
    show CompactChirpMessageFormatter;
export 'package:chirp/src/formatters/json_message_formatter.dart'
    show JsonMessageFormatter;
export 'package:chirp/src/formatters/rainbow_message_formatter.dart'
    show DataPresentation, RainbowFormatOptions, RainbowMessageFormatter;
export 'package:chirp/src/formatters/simple_console_message_formatter.dart'
    show
        BracketedLoggerName,
        FullTimestamp,
        KeyValueData,
        SimpleConsoleMessageFormatter;
export 'package:chirp/src/platform/color_support.dart'
    show TerminalColorSupport;
export 'package:chirp/src/platform/terminal_capabilities.dart'
    show TerminalCapabilities;
export 'package:chirp/src/span/span_based_formatter.dart'
    show SpanBasedFormatter, SpanFormatOptions, SpanTransformer;
export 'package:chirp/src/span/span_foundation.dart'
    show
        LeafSpan,
        LogSpan,
        MultiChildSpan,
        SingleChildSpan,
        SlottedSpan,
        renderSpan;
export 'package:chirp/src/span/spans.dart'
    show
        Aligned,
        AnsiStyled,
        Bordered,
        BoxBorderChars,
        BoxBorderStyle,
        BracketedLogLevel,
        ChirpLogo,
        ClassName,
        DartSourceCodeLocation,
        EmptySpan,
        ErrorSpan,
        HorizontalAlign,
        InlineData,
        LogMessage,
        LoggerName,
        MethodName,
        MultilineData,
        NewLine,
        PlainText,
        SpanSequence,
        StackTraceSpan,
        Surrounded,
        Timestamp,
        Whitespace;
export 'package:chirp/src/utils/stack_trace_util.dart'
    show StackFrameInfo, getCallerInfo, parseStackFrame;
export 'package:chirp/src/writers/console_writer.dart'
    show
        ConsoleMessageBuffer,
        ConsoleMessageFormatter,
        PrintConsoleWriter,
        splitIntoChunks,
        stripAnsiCodes;
export 'package:chirp/src/writers/developer_log_console_writer.dart'
    show DeveloperLogConsoleWriter;
