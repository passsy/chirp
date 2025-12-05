/// The logging interface of Chirp
///
/// This package provides the core logging interfaces and types that libraries
/// should depend on. For a full logging implementation with writers and
/// formatters, depend on `chirp` instead.
///
/// ## For Library Authors
///
/// Depend on `chirp_protocol` to use logging without pulling in implementations:
///
/// ```yaml
/// dependencies:
///   chirp_protocol: ^0.5.0
/// ```
///
/// Then create a logger for your package:
///
/// ```dart
/// import 'package:chirp_protocol/chirp_protocol.dart';
///
/// final logger = ChirpLogger('my_library');
///
/// class MyLibraryService {
///   void doWork() {
///     logger.info('Doing work', data: {'step': 1});
///   }
/// }
/// ```
///
/// ## For App Developers
///
/// Depend on `chirp` instead, which re-exports this package and provides
/// writers and formatters:
///
/// ```yaml
/// dependencies:
///   chirp: ^0.5.0
/// ```
///
/// To receive logs from libraries that use `chirp_protocol`, add a writer
/// to the library's logger:
///
/// ```dart
/// import 'package:chirp/chirp.dart';
/// import 'package:my_library/my_library.dart' as my_library;
///
/// void main() {
///   // Connect the library's logger to your app's logging
///   my_library.logger.addWriter(
///     PrintConsoleWriter(formatter: RainbowMessageFormatter()),
///   );
///
///   // Now library logs will appear in your app's output
///   my_library.doSomething();
/// }
/// ```
library;

export 'src/chirp_interceptor.dart' show ChirpInterceptor;
export 'src/chirp_logger.dart' show ChirpLogger;
export 'src/chirp_writer.dart' show ChirpWriter;
export 'src/format_option.dart' show FormatOptions;
export 'src/log_level.dart' show ChirpLogLevel;
export 'src/log_record.dart' show LogRecord;
