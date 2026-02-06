import 'package:chirp/src/core/log_record.dart';
import 'package:chirp/src/writers/console_writer.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer.dart';

/// Converts a [LogRecord] into formatted text for output.
///
/// A single formatter can serve both console and file writers. Use
/// [MessageBuffer.write] for plain text output, and [MessageBuffer.console]
/// for console-specific features like ANSI colors:
///
/// ```dart
/// class MyFormatter extends ChirpFormatter {
///   @override
///   void format(LogRecord record, MessageBuffer buffer) {
///     // Color support (ignored for file output)
///     buffer.console?.pushStyle(foreground: Ansi256.red_1);
///     buffer.write('[${record.level.name}]');
///     buffer.console?.popStyle();
///
///     buffer.write(' ${record.message}');
///   }
/// }
/// ```
abstract class ChirpFormatter {
  const ChirpFormatter();

  /// Whether this formatter needs caller info (file, line, class, method).
  ///
  /// When `true`, the logger captures `StackTrace.current` on every log call,
  /// which is expensive. Only enable if the formatter displays source locations.
  bool get requiresCallerInfo => false;

  /// Formats [record] by writing to [buffer].
  void format(LogRecord record, MessageBuffer buffer);
}

/// Unified write target for [ChirpFormatter], wrapping either a
/// [ConsoleMessageBuffer] or [FileMessageBuffer].
///
/// Use [write] for plain text that works with any output. Access [console]
/// or [file] for target-specific features like ANSI styling or structured
/// file data.
class MessageBuffer {
  MessageBuffer(this.buffer) {
    if (buffer is! ConsoleMessageBuffer && buffer is! FileMessageBuffer) {
      throw ArgumentError(
        'MessageBuffer only accepts ConsoleMessageBuffer or '
        'FileMessageBuffer, got ${buffer.runtimeType}',
      );
    }
  }

  final Object buffer;

  /// The underlying [ConsoleMessageBuffer], or `null` when writing to a file.
  ConsoleMessageBuffer? get console =>
      buffer is ConsoleMessageBuffer ? buffer as ConsoleMessageBuffer : null;

  /// The underlying [FileMessageBuffer], or `null` when writing to a console.
  FileMessageBuffer? get file =>
      buffer is FileMessageBuffer ? buffer as FileMessageBuffer : null;

  /// Appends [value] as text to the log output.
  ///
  /// ```dart
  /// buffer.write('[${record.level.name}] ');
  /// buffer.write(record.message);
  /// ```
  void write(Object? value) {
    final c = console;
    if (c != null) {
      c.write(value);
    }
    final f = file;
    if (f != null) {
      f.write(value);
    }
  }

  /// Appends [value] followed by a newline to the log output.
  void writeln(Object? value) {
    final c = console;
    if (c != null) {
      c.writeln(value);
    }
    final f = file;
    if (f != null) {
      f.writeln(value);
    }
  }
}
