import 'package:chirp/chirp.dart';

import 'library.dart';

/// Simple example demonstrating that chirp works out of the box.
///
/// Run with: dart run bin/main.dart
void main() {
  // No configuration needed - just import and log!
  Chirp.info('Hello from Chirp!');
  Chirp.debug('This is a debug message');
  Chirp.warning('This is a warning');
  Chirp.error('This is an error', error: Exception('Something went wrong'));

  // Instance logging also works
  final service = MyService();
  service.doWork();

  // Library loggers have minLogLevel set - only warnings+ shown by default
  libraryLogger.info('This is silent due to minLogLevel');
  libraryLogger.warning('This warning is visible from the library');

  // Adopt the library logger to use app's writers/formatting
  Chirp.root = ChirpLogger().addConsoleWriter().adopt(libraryLogger);
  libraryLogger.warning('Now using Chirp.root writers (printed once)');

  // Library's minLogLevel still applies - info is filtered
  libraryLogger.info('Still silent - library minLogLevel blocks this');

  // Enable verbose logging for the library when debugging
  libraryLogger.setMinLogLevel(ChirpLogLevel.trace);
  libraryLogger.info('Now visible after enabling verbose logging!');
  libraryLogger.debug('Debug messages too!');
}

class MyService {
  void doWork() {
    chirp.info('Doing work from MyService instance');
  }
}
