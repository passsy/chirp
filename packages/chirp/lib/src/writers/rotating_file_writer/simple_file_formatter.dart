import 'package:chirp/chirp.dart';

/// Default formatter that produces simple, readable log lines.
///
/// Output format: `2024-01-15T10:30:45.123 [INFO] Message`
///
/// With error: `2024-01-15T10:30:45.123 [ERROR] Message\nError: Something failed\n<stacktrace>`
class SimpleFileFormatter implements FileMessageFormatter {
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

  @override
  void format(LogRecord record, FileMessageBuffer buffer) {
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
      buffer.writeData(record.data);
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
