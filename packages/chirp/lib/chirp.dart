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
export 'package:chirp/src/core/chirp_interceptor.dart' show ChirpInterceptor;
export 'package:chirp/src/core/chirp_logger.dart' show ChirpLogger;
export 'package:chirp/src/core/chirp_root.dart'
    show Chirp, ChirpInstanceLogger, ChirpLoggerConsoleWriterExt, LogRecordExt;
export 'package:chirp/src/core/chirp_writer.dart' show ChirpWriter;
export 'package:chirp/src/core/delegated_interceptor.dart'
    show DelegatedChirpInterceptor;
export 'package:chirp/src/core/delegated_writer.dart' show DelegatedChirpWriter;
export 'package:chirp/src/core/format_option.dart'
    show FormatOptions, TimeDisplay;
export 'package:chirp/src/core/log_level.dart' show ChirpLogLevel;
export 'package:chirp/src/core/log_record.dart' show LogRecord;
export 'package:chirp/src/formatters/aws_message_formatter.dart'
    show AwsMessageFormatter;
export 'package:chirp/src/formatters/compact_message_formatter.dart'
    show CompactChirpMessageFormatter;
export 'package:chirp/src/formatters/gcp_message_formatter.dart'
    show GcpMessageFormatter;
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
export 'package:chirp/src/utils/stack_trace_util.dart'
    show StackFrameInfo, getCallerInfo, parseStackFrame;
export 'package:chirp/src/writers/console_writer.dart'
    show
        ConsoleMessageBuffer,
        ConsoleMessageFormatter,
        PrintConsoleWriter,
        splitIntoChunks,
        stripAnsiCodes;
export 'package:chirp/src/writers/delegated_formatter.dart'
    show DelegatedConsoleMessageFormatter;
export 'package:chirp/src/writers/developer_log_console_writer.dart'
    show DeveloperLogConsoleWriter;
export 'package:chirp/src/writers/file_writer.dart'
    show
        FileMessageFormatter,
        FileRotationConfig,
        FileRotationInterval,
        FileWriterErrorHandler,
        FlushStrategy,
        JsonFileFormatter,
        RotatingFileWriter,
        SimpleFileFormatter,
        defaultFileWriterErrorHandler;
