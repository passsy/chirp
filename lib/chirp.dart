import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/message_writer.dart';

export 'src/log_entry.dart';
export 'src/message_formatter.dart';
export 'src/message_writer.dart';

/// Function type for transforming an instance into a display name.
///
/// Return a non-null string to use that as the class name,
/// or null to try the next transformer.
typedef ClassNameTransformer = String? Function(Object instance);

/// Main logger class
class Chirp {
  /// Optional name for this logger (required for explicit instances)
  final String? name;

  /// The writers used by this logger
  final List<ChirpMessageWriter> writers;

  /// Create a custom logger instance
  Chirp({
    this.name,
    List<ChirpMessageWriter>? writers,
  }) : writers = List.unmodifiable(writers ?? [ConsoleChirpMessageWriter()]);

  void chirp(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(message, error: error, stackTrace: stackTrace);
  }

  /// Log a message
  ///
  /// When called from the extension, instance is provided automatically.
  /// When called directly on a named logger, uses the logger's name.
  void log(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      message: message,
      date: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      loggerName: name,
    );

    logRecord(entry);
  }

  void logRecord(LogEntry record) {
    for (final writer in writers) {
      writer.write(record);
    }
  }

  /// Global root logger used by the extension
  static Chirp root = Chirp();
}

/// Extension for logging from any object with class context
extension ChirpObjectExt<T extends Object> on T {
  /// Log a message with optional error and stack trace
  void chirp(Object? message, [Object? error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      message: message,
      date: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      instance: this,
      instanceHash: identityHashCode(this),
    );

    Chirp.root.logRecord(entry);
  }

  /// Log an error message (same as chirp, semantic alias)
  void chirpError(Object? message, [Object? error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      message: message,
      date: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      instance: this,
      instanceHash: identityHashCode(this),
    );

    Chirp.root.logRecord(entry);
  }
}
