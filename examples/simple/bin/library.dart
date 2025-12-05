import 'package:chirp_protocol/chirp_protocol.dart';

/// Library logger with default minimum level.
///
/// By default, only warnings and errors are shown to avoid spamming users.
/// Apps that adopt this logger can enable verbose logging with:
/// ```dart
/// libraryLogger.setMinLogLevel(ChirpLogLevel.trace);
/// ```
final libraryLogger =
    ChirpLogger(name: 'lib').setMinLogLevel(ChirpLogLevel.warning);
// ..addConsoleWriter();

/// Simple example demonstrating that chirp in libraries don't log by default
void main() {
  libraryLogger.info('Hello from Chirp!');
  libraryLogger.debug('This is a debug message');

  // starts logging here due to minLogLevel
  libraryLogger.warning('This is a warning');
  libraryLogger.error('This is an error',
      error: Exception('Something went wrong'));
}
