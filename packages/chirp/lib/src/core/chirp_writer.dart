import 'package:chirp/src/core/chirp_interceptor.dart';
import 'package:chirp/src/core/chirp_logger.dart';
import 'package:chirp/src/core/log_level.dart';
import 'package:chirp/src/core/log_record.dart';

/// {@template chirp.ChirpWriter}
/// Abstract interface for log output destinations.
///
/// A [ChirpWriter] receives [LogRecord] instances and writes them to a
/// destination such as the console, a file, a network endpoint, or a
/// monitoring service.
/// {@endtemplate}
///
/// ## Implementing Custom Writers
///
/// Create custom writers by implementing this interface:
///
/// ```dart
/// class FileWriter extends ChirpWriter {
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
/// ## Interceptors
///
/// Writers can have interceptors that transform or filter records before writing:
///
/// ```dart
/// final writer = PrintConsoleWriter()
///   .addInterceptor(LevelInterceptor(ChirpLogLevel.warning))
///   .addInterceptor(RedactSecretsInterceptor());
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
/// - [ChirpInterceptor] for transforming/filtering records
abstract class ChirpWriter {
  /// {@macro chirp.ChirpWriter}
  ChirpWriter();

  final List<ChirpInterceptor> _interceptors = [];

  /// Interceptors attached to this writer.
  ///
  /// Interceptors are executed in order when a record is written.
  List<ChirpInterceptor> get interceptors => List.unmodifiable(_interceptors);

  /// Adds an interceptor to this writer and returns this writer for chaining.
  ///
  /// Example:
  /// ```dart
  /// final writer = PrintConsoleWriter()
  ///   .setMinLogLevel(ChirpLogLevel.warning)
  ///   .addInterceptor(RedactSecretsInterceptor())
  ///   .addInterceptor(RateLimitInterceptor());
  /// ```
  ChirpWriter addInterceptor(ChirpInterceptor interceptor) {
    _interceptors.add(interceptor);
    _notifyLoggersInterceptorsChanged();
    return this;
  }

  /// Removes an interceptor from this writer.
  bool removeInterceptor(ChirpInterceptor interceptor) {
    final removed = _interceptors.remove(interceptor);
    if (removed) {
      _notifyLoggersInterceptorsChanged();
    }
    return removed;
  }

  /// Backing field for [minLogLevel].
  ChirpLogLevel? _minLogLevel;

  /// Minimum log level for this writer.
  ///
  /// Records below this level are skipped by this writer. Default is `null`
  /// (no filtering - accept all levels).
  ///
  /// This provides writer-level filtering in addition to logger-level filtering.
  /// Use this when different writers should handle different log levels.
  ///
  /// Use [setMinLogLevel] to change this value.
  ChirpLogLevel? get minLogLevel => _minLogLevel;

  /// Sets the minimum log level and returns this writer for chaining.
  ///
  /// Pass `null` to reset to no filtering (accept all levels).
  ///
  /// Example:
  /// ```dart
  /// final writer = PrintConsoleWriter()
  ///   .setMinLogLevel(ChirpLogLevel.warning);
  ///
  /// // Reset to accept all
  /// writer.setMinLogLevel(null);
  /// ```
  ChirpWriter setMinLogLevel(ChirpLogLevel? level) {
    _minLogLevel = level;
    return this;
  }

  /// Whether this writer requires caller info (file, line, class, method).
  ///
  /// If `true`, the logger will capture `StackTrace.current` for each log call.
  /// If all writers return `false`, the expensive stack trace capture is skipped.
  ///
  /// Override this in subclasses to specify requirements.
  /// Default is `false`.
  bool get requiresCallerInfo => false;

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

/// Storage for loggers attached to writers, kept private to this file.
final Expando<List<ChirpLogger>> _writerLoggers = Expando('writerLoggers');

/// Soft-private extension for package-internal use.
///
/// This extension is intentionally not exported from `chirp_writer.dart`.
/// It provides internal APIs needed for cross-file communication within the
/// package (e.g., between [ChirpWriter] and [ChirpLogger]).
///
/// **Not part of the public API** - may change without notice.
///
/// Advanced users can access this by importing the src file directly,
/// but doing so is discouraged and unsupported. If you find yourself needing
/// these APIs, please open an issue - we'd like to understand your use case
/// and potentially expose a proper public API.
extension $PrivateChirpWriter on ChirpWriter {
  void _notifyLoggersInterceptorsChanged() {
    for (final logger in attachedLoggers) {
      logger.updateRequiresCallerInfo();
    }
  }

  /// List of [ChirpLogger] attached to the [ChirpWriter]
  List<ChirpLogger> get attachedLoggers => _writerLoggers[this] ??= [];
}
