import 'package:chirp/chirp.dart';

/// Default formatter that produces simple, readable log lines.
///
/// Output format: `2024-01-15T10:30:45.123 [INFO] Message`
///
/// With error: `2024-01-15T10:30:45.123 [ERROR] Message\nError: Something failed\n<stacktrace>`
class SimpleFileFormatter extends ChirpFormatter {
  /// Whether to include the logger name in output.
  final bool includeLoggerName;

  /// Whether to include structured data in output.
  final bool includeData;

  /// Creates a simple file formatter.
  const SimpleFileFormatter({
    this.includeLoggerName = true,
    this.includeData = true,
  });

  @override
  bool get requiresCallerInfo => false;

  /// Uses `'\x1E\n'` (ASCII Record Separator + newline) instead of plain
  /// `'\n'` because this formatter produces multi-line output — errors and
  /// stack traces contain literal newlines (see [format]).
  ///
  /// Without `\x1E`, a single log record with a stack trace would be split
  /// into many "lines" when read back by [RotatingFileReader], making it
  /// impossible to reconstruct the original record. The `\x1E` byte
  /// (U+001E, rarely found in log text) provides an unambiguous record
  /// boundary. The trailing `\n` keeps the file visually readable in
  /// editors — each record still starts on a new line.
  ///
  /// Example file content (`·` = `\x1E`):
  /// ```text
  /// 2024-01-15T10:30:45 [INFO    ] All good·
  /// 2024-01-15T10:30:46 [ERROR   ] Failed
  /// Error: Exception: boom
  /// #0  main (file.dart:10)·
  /// ```
  ///
  /// Single-line formatters like [JsonLogFormatter] (which escapes `\n` in
  /// JSON strings) keep the default `'\n'` from [ChirpFormatter].
  @override
  String get recordSeparator => '\x1E\n';

  @override
  void format(LogRecord record, MessageBuffer buffer) {
    // Timestamp
    buffer.write(record.timestamp.toIso8601String());
    buffer.write(' ');

    // Level
    buffer.write('[');
    buffer.write(record.level.name.toUpperCase().padRight(8));
    buffer.write('] ');

    // Logger name
    if (includeLoggerName && record.loggerName != null) {
      buffer.write('[');
      buffer.write(record.loggerName);
      buffer.write('] ');
    }

    // Message
    buffer.write(record.message);

    // Structured data
    if (includeData && record.data.isNotEmpty) {
      buffer.write(' ');
      buffer.file!.writeData(record.data);
    }

    // Error
    if (record.error != null) {
      buffer.write('\nError: ');
      buffer.write(record.error);
    }

    // Stack trace
    if (record.stackTrace != null) {
      buffer.write('\n');
      buffer.write(record.stackTrace);
    }
  }
}
