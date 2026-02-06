import 'package:chirp/src/core/chirp_formatter.dart';
import 'package:chirp/src/core/log_record.dart';
import 'package:chirp/src/utils/stack_trace_util.dart';

/// {@template chirp.DelegatedMessageFormatter}
/// A [ChirpFormatter] implementation that delegates to a function.
///
/// This allows creating formatters inline without defining a class:
///
/// ```dart
/// // Simple formatter
/// final simpleFormatter = DelegatedMessageFormatter((record, buffer) {
///   buffer.write('[${record.level.name}] ${record.message}');
/// });
///
/// // Formatter with colors
/// final colorFormatter = DelegatedMessageFormatter((record, buffer) {
///   buffer.console?.pushStyle(foreground: Ansi256.cyan_6);
///   buffer.write(record.timestamp.toIso8601String());
///   buffer.console?.popStyle();
///   buffer.write(' ');
///   buffer.console?.pushStyle(foreground: Ansi256.yellow_3, bold: true);
///   buffer.write('[${record.level.name.toUpperCase()}]');
///   buffer.console?.popStyle();
///   buffer.write(' ${record.message}');
/// });
///
/// // Formatter that includes structured data
/// final dataFormatter = DelegatedMessageFormatter((record, buffer) {
///   buffer.write('${record.message}');
///   if (record.data.isNotEmpty) {
///     buffer.write(' | ');
///     buffer.console?.pushStyle(dim: true);
///     buffer.write(record.data.entries
///         .map((e) => '${e.key}=${e.value}')
///         .join(', '));
///     buffer.console?.popStyle();
///   }
/// });
///
/// // Use with PrintConsoleWriter
/// final writer = PrintConsoleWriter(formatter: simpleFormatter);
/// ```
///
/// ## Using the Buffer
///
/// The [MessageBuffer] provides methods for building styled output:
/// - [MessageBuffer.write] - Write text to any output target
/// - [MessageBuffer.console] - Access console-specific features like ANSI colors
/// - [MessageBuffer.file] - Access file-specific features like structured data
///
/// ## Debugging
///
/// By default, the creation site is captured for debugging. This helps
/// identify which delegated formatter is which when inspecting in a debugger:
///
/// ```dart
/// print(formatter); // DelegatedMessageFormatter(my_service.dart:42)
/// ```
///
/// For more complex formatters with configuration or state, consider extending
/// [ChirpFormatter] directly.
/// {@endtemplate}
class DelegatedMessageFormatter extends ChirpFormatter {
  /// The function that formats log records.
  final void Function(LogRecord record, MessageBuffer buffer) _format;

  final bool _requiresCallerInfo;

  /// Stack trace captured at construction time, for debugging.
  ///
  /// Only captured when assertions are enabled (debug mode).
  final StackTrace? creationStackTrace;

  /// {@macro chirp.DelegatedMessageFormatter}
  ///
  /// The [format] function receives a [LogRecord] and a [MessageBuffer].
  /// Write the formatted output to the buffer using its methods.
  ///
  /// Set [requiresCallerInfo] to `true` if your formatter needs access to
  /// caller information (file, line, class, method). This triggers stack trace
  /// capture which has a performance cost.
  DelegatedMessageFormatter(
    void Function(LogRecord record, MessageBuffer buffer) format, {
    bool requiresCallerInfo = false,
  })  : _format = format,
        _requiresCallerInfo = requiresCallerInfo,
        creationStackTrace = debugCaptureStackTrace();

  @override
  bool get requiresCallerInfo => _requiresCallerInfo;

  @override
  void format(LogRecord record, MessageBuffer buffer) =>
      _format(record, buffer);

  @override
  String toString() {
    final stackTrace = creationStackTrace;
    if (stackTrace != null) {
      final info = getCallerInfo(stackTrace);
      if (info != null) {
        return 'DelegatedMessageFormatter(${info.callerLocation})';
      }
    }
    return 'DelegatedMessageFormatter';
  }
}
