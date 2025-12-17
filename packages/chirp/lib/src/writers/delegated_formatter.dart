import 'package:chirp/src/core/log_record.dart';
import 'package:chirp/src/utils/stack_trace_util.dart';
import 'package:chirp/src/writers/console_writer.dart';

/// Signature for formatter functions used by [DelegatedConsoleMessageFormatter].
typedef FormatterFunction = void Function(
  LogRecord record,
  ConsoleMessageBuffer buffer,
);

/// {@template chirp.DelegatedConsoleMessageFormatter}
/// A [ConsoleMessageFormatter] implementation that delegates to a function.
///
/// This allows creating formatters inline without defining a class:
///
/// ```dart
/// // Simple formatter
/// final simpleFormatter = DelegatedConsoleMessageFormatter((record, buffer) {
///   buffer.write('[${record.level.name}] ${record.message}');
/// });
///
/// // Formatter with colors
/// final colorFormatter = DelegatedConsoleMessageFormatter((record, buffer) {
///   buffer.pushStyle(foreground: Ansi256.cyan_6);
///   buffer.write(record.timestamp.toIso8601String());
///   buffer.popStyle();
///   buffer.write(' ');
///   buffer.pushStyle(foreground: Ansi256.yellow_3, bold: true);
///   buffer.write('[${record.level.name.toUpperCase()}]');
///   buffer.popStyle();
///   buffer.write(' ${record.message}');
/// });
///
/// // Formatter that includes structured data
/// final dataFormatter = DelegatedConsoleMessageFormatter((record, buffer) {
///   buffer.write('${record.message}');
///   if (record.data.isNotEmpty) {
///     buffer.write(' | ');
///     buffer.pushStyle(dim: true);
///     buffer.write(record.data.entries
///         .map((e) => '${e.key}=${e.value}')
///         .join(', '));
///     buffer.popStyle();
///   }
/// });
///
/// // Use with PrintConsoleWriter
/// final writer = PrintConsoleWriter(formatter: simpleFormatter);
/// ```
///
/// ## Using the Buffer
///
/// The [ConsoleMessageBuffer] provides methods for building styled output:
/// - [ConsoleMessageBuffer.write] - Write text with optional inline colors
/// - [ConsoleMessageBuffer.pushStyle] / [ConsoleMessageBuffer.popStyle] - Manage nested styles
/// - [ConsoleMessageBuffer.capabilities] - Query terminal capabilities
///
/// ## Debugging
///
/// By default, the creation site is captured for debugging. This helps
/// identify which delegated formatter is which when inspecting in a debugger:
///
/// ```dart
/// print(formatter); // DelegatedConsoleMessageFormatter(my_service.dart:42)
/// ```
///
/// For more complex formatters with configuration or state, consider extending
/// [ConsoleMessageFormatter] directly.
/// {@endtemplate}
class DelegatedConsoleMessageFormatter extends ConsoleMessageFormatter {
  /// The function that formats log records.
  final FormatterFunction _format;

  final bool _requiresCallerInfo;

  /// Stack trace captured at construction time, for debugging.
  ///
  /// Only captured when assertions are enabled (debug mode).
  final StackTrace? creationStackTrace;

  /// {@macro chirp.DelegatedConsoleMessageFormatter}
  ///
  /// The [format] function receives a [LogRecord] and a [ConsoleMessageBuffer].
  /// Write the formatted output to the buffer using its methods.
  ///
  /// Set [requiresCallerInfo] to `true` if your formatter needs access to
  /// caller information (file, line, class, method). This triggers stack trace
  /// capture which has a performance cost.
  DelegatedConsoleMessageFormatter(
    FormatterFunction format, {
    bool requiresCallerInfo = false,
  })  : _format = format,
        _requiresCallerInfo = requiresCallerInfo,
        creationStackTrace = debugCaptureStackTrace();

  @override
  bool get requiresCallerInfo => _requiresCallerInfo;

  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) =>
      _format(record, buffer);

  @override
  String toString() {
    final stackTrace = creationStackTrace;
    if (stackTrace != null) {
      final info = getCallerInfo(stackTrace);
      if (info != null) {
        return 'DelegatedConsoleMessageFormatter(${info.callerLocation})';
      }
    }
    return 'DelegatedConsoleMessageFormatter';
  }
}
