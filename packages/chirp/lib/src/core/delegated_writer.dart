import 'package:chirp/src/core/chirp_writer.dart';
import 'package:chirp/src/core/log_record.dart';

/// Signature for writer functions used by [DelegatedChirpWriter].
typedef WriterFunction = void Function(LogRecord record);

/// {@template chirp.DelegatedChirpWriter}
/// A [ChirpWriter] implementation that delegates to a function.
///
/// This allows creating writers inline without defining a class:
///
/// ```dart
/// // Simple writer that collects logs
/// final logs = <LogRecord>[];
/// final collector = DelegatedChirpWriter((record) => logs.add(record));
///
/// // Writer that sends to external service
/// final analyticsWriter = DelegatedChirpWriter((record) {
///   if (record.level >= ChirpLogLevel.error) {
///     analytics.logError(
///       message: record.message.toString(),
///       error: record.error,
///       stackTrace: record.stackTrace,
///     );
///   }
/// });
///
/// // Writer that appends to a file
/// final fileWriter = DelegatedChirpWriter((record) {
///   final line = '${record.timestamp.toIso8601String()} '
///       '[${record.level.name}] ${record.message}\n';
///   logFile.writeAsStringSync(line, mode: FileMode.append);
/// });
///
/// // Use with a logger
/// final logger = ChirpLogger(name: 'MyLogger')
///   .addWriter(collector)
///   .addWriter(analyticsWriter);
/// ```
///
/// ## Interceptors and Filtering
///
/// [DelegatedChirpWriter] inherits interceptor and minimum log level support
/// from [ChirpWriter]:
///
/// ```dart
/// final writer = DelegatedChirpWriter((record) => print(record.message))
///   .setMinLogLevel(ChirpLogLevel.warning)
///   .addInterceptor(myInterceptor);
/// ```
///
/// For more complex writers with state, configuration, or cleanup logic,
/// consider extending [ChirpWriter] directly.
/// {@endtemplate}
class DelegatedChirpWriter extends ChirpWriter {
  /// The function that writes log records.
  final WriterFunction _write;

  final bool _requiresCallerInfo;

  /// {@macro chirp.DelegatedChirpWriter}
  ///
  /// The [write] function receives a [LogRecord] and should output it to the
  /// desired destination (console, file, network, monitoring service, etc.).
  ///
  /// Set [requiresCallerInfo] to `true` if your writer needs access to caller
  /// information (file, line, class, method). This triggers stack trace
  /// capture which has a performance cost.
  ///
  /// **Performance note**: The [write] function is called synchronously for
  /// each log event. For slow operations (network, disk), consider buffering
  /// or handling async operations within your function.
  DelegatedChirpWriter(
    WriterFunction write, {
    bool requiresCallerInfo = false,
  })  : _write = write,
        _requiresCallerInfo = requiresCallerInfo;

  @override
  bool get requiresCallerInfo => _requiresCallerInfo;

  @override
  void write(LogRecord record) => _write(record);
}
