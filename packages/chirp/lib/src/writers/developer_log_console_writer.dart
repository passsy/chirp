// ignore_for_file: avoid_redundant_argument_values

import 'dart:developer' as developer;

import 'package:chirp/chirp.dart';

/// Writes to console using [developer.log()].
///
/// **No character limit** - messages are never truncated.
/// **No ANSI color support** - colors are stripped because the output already
/// includes a `[name]` tag prefix that makes ANSI codes look messy.
///
/// **Requires Dart DevTools Service (DDS) connection:**
/// - Shows in Flutter DevTools Logging view
/// - Shows in IDE debug console when debugger is attached
/// - Does NOT show in `adb logcat` or Xcode console
/// - Does NOT work in release builds (AOT compiled)
///
/// **Advantages:**
/// - Unlimited message length
/// - No rate limiting
/// - Structured logging with name/level/error/stackTrace parameters
///
/// **Disadvantages:**
/// - Requires Flutter tooling / debugger attachment
/// - Cannot be viewed with `adb logcat` in Android Studio
/// - Not available in release mode
///
/// ## Log Level Mapping
///
/// [developer.log] expects levels compatible with `package:logging`.
/// Chirp levels are mapped as follows:
///
/// | Chirp Level | Chirp Severity | → | Logging Level | Logging Value |
/// |-------------|----------------|---|---------------|---------------|
/// | trace       | 0              | → | FINEST        | 300           |
/// | debug       | 100            | → | FINE          | 500           |
/// | info        | 200            | → | INFO          | 800           |
/// | notice      | 300            | → | INFO          | 800           |
/// | warning     | 400            | → | WARNING       | 900           |
/// | error       | 500            | → | SEVERE        | 1000          |
/// | critical    | 600            | → | SHOUT         | 1200          |
/// | wtf         | 1000           | → | SHOUT         | 1200          |
///
/// See:
/// - https://api.flutter.dev/flutter/dart-developer/log.html
/// - https://pub.dev/documentation/logging/latest/logging/Level-class.html
class DeveloperLogConsoleWriter extends ChirpWriter {
  /// The formatter that writes log records to a buffer.
  final ChirpFormatter formatter;

  /// Creates a writer that outputs to `dart:developer` log.
  ///
  /// Use this for development with a debugger attached to see unlimited-length
  /// log output. Falls back to [RainbowMessageFormatter] if no [formatter]
  /// is provided. Use [minLevel] to filter out logs below a certain level.
  DeveloperLogConsoleWriter({
    ChirpFormatter? formatter,
    ChirpLogLevel? minLevel,
  }) : formatter = formatter ?? RainbowMessageFormatter() {
    if (minLevel != null) {
      setMinLogLevel(minLevel);
    }
  }

  @override
  bool get requiresCallerInfo => formatter.requiresCallerInfo;

  @override
  void write(LogRecord record) {
    // Colors disabled - developer.log adds its own [name] prefix which
    // makes ANSI codes look messy in the output
    final buffer = MessageBuffer.console(
      capabilities:
          const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
    );
    formatter.format(record, buffer);
    final text = buffer.toString();

    developer.log(
      text,
      name: record.loggerName ?? '',
      level: _mapToLoggingLevel(record.level),
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  /// Maps [ChirpLogLevel] severity to `package:logging` Level values.
  ///
  /// See https://pub.dev/documentation/logging/latest/logging/Level-class.html
  static int _mapToLoggingLevel(ChirpLogLevel level) {
    // package:logging Level values:
    // ALL=0, FINEST=300, FINER=400, FINE=500, CONFIG=700,
    // INFO=800, WARNING=900, SEVERE=1000, SHOUT=1200, OFF=2000
    return switch (level.severity) {
      < 100 => 300, // trace → FINEST
      < 200 => 500, // debug → FINE
      < 400 => 800, // info, notice → INFO
      < 500 => 900, // warning → WARNING
      < 600 => 1000, // error → SEVERE
      _ => 1200, // critical, wtf → SHOUT
    };
  }
}
