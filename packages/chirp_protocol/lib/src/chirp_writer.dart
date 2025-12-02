import 'package:chirp_protocol/src/log_record.dart';

/// Abstract interface for log output destinations.
///
/// A [ChirpWriter] receives [LogRecord] instances and writes them to a
/// destination such as the console, a file, a network endpoint, or a
/// monitoring service.
///
/// ## Implementing Custom Writers
///
/// Create custom writers by implementing this interface:
///
/// ```dart
/// class FileWriter implements ChirpWriter {
///   final File logFile;
///
///   FileWriter(String path) : logFile = File(path);
///
///   @override
///   void write(LogRecord record) {
///     final line = '${record.date.toIso8601String()} '
///         '[${record.level.name}] ${record.message}\n';
///     logFile.writeAsStringSync(line, mode: FileMode.append);
///   }
/// }
/// ```
///
/// ## Writer Considerations
///
/// When implementing a writer, consider:
///
/// - **Performance**: Writers are called synchronously. For slow operations
///   (network, disk), consider buffering or async processing.
/// - **Error handling**: Writers should handle their own errors gracefully
///   to avoid disrupting the application.
/// - **Thread safety**: If your writer maintains state, ensure thread safety
///   for concurrent access.
/// - **Resource cleanup**: Implement cleanup logic (close files, flush buffers)
///   when the application shuts down.
///
/// See also:
/// - [LogRecord] for the data structure passed to writers
abstract class ChirpWriter {
  /// Writes a log record to this writer's destination.
  ///
  /// Implementations should process the [record] and output it to their
  /// respective destination (console, file, network, etc.).
  ///
  /// This method is called synchronously for each log event. Long-running
  /// operations should be handled asynchronously to avoid blocking the
  /// application.
  void write(LogRecord record);
}
