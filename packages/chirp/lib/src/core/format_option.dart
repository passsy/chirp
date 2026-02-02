/// Base class for formatter-specific options that control log output display.
///
/// [FormatOptions] allows log messages to carry per-message formatting hints
/// that formatters can use to customize their output. This enables fine-grained
/// control over how individual log entries are displayed without changing
/// global formatter settings.
///
/// ## Using Format Options in Log Calls
///
/// Pass format options when logging to override formatter defaults.
/// For example, with `RainbowFormatOptions` from the `chirp` package:
///
/// ```dart
/// // Show data on multiple lines for this complex log entry
/// Chirp.info(
///   'User logged in',
///   data: {'userId': 'user_123', 'roles': ['admin', 'user']},
///   formatOptions: [RainbowFormatOptions(data: DataPresentation.multiline)],
/// );
///
/// // Hide timestamp and location for a minimal log
/// Chirp.debug(
///   'Quick debug note',
///   formatOptions: [RainbowFormatOptions(showTime: false, showLocation: false)],
/// );
/// ```
///
/// ## Creating Custom Format Options
///
/// Extend this class to define options specific to your formatter:
///
/// ```dart
/// class MyFormatterOptions extends FormatOptions {
///   const MyFormatterOptions({
///     this.uppercase = false,
///     this.maxLength = 100,
///   });
///
///   final bool uppercase;
///   final int maxLength;
/// }
/// ```
///
/// ## Consuming Format Options in Formatters
///
/// Formatters retrieve their specific options from the log record:
///
/// ```dart
/// class MyFormatter implements ChirpFormatter {
///   final MyFormatterOptions defaultOptions;
///
///   MyFormatter({this.defaultOptions = const MyFormatterOptions()});
///
///   String format(LogRecord record) {
///     // Find MyFormatterOptions in the record, or use defaults
///     final options = record.formatOptions
///         ?.whereType<MyFormatterOptions>()
///         .firstOrNull ?? defaultOptions;
///
///     var message = record.message.toString();
///     if (options.uppercase) message = message.toUpperCase();
///     if (message.length > options.maxLength) {
///       message = '${message.substring(0, options.maxLength)}...';
///     }
///     return message;
///   }
/// }
/// ```
///
/// ## Multiple Format Options
///
/// A single log call can include options for multiple formatters. Each
/// formatter extracts only the options it understands:
///
/// ```dart
/// Chirp.info(
///   'User action',
///   formatOptions: [
///     RainbowFormatOptions(data: DataPresentation.multiline),
///     MyFormatterOptions(uppercase: true),
///   ],
/// );
/// ```
class FormatOptions {
  /// Creates a format options instance.
  ///
  /// Subclass this to define custom options for your formatter.
  const FormatOptions();
}

/// Controls which timestamp(s) to include in log output.
///
/// Chirp tracks two timestamps for each log record:
/// - **clock**: The injectable [Clock] time, which can be mocked in tests
/// - **wallClock**: The real system time from `DateTime.now()`
///
/// Used by formatters to determine which timestamp source(s) to include.
/// How timestamps are rendered (format, field names) is up to each formatter.
enum TimeDisplay {
  /// Include only the clock timestamp (from injectable [Clock]).
  ///
  /// The clock can be mocked in tests using `fakeAsync` or a custom [Clock].
  clock,

  /// Include only the wall-clock timestamp (real system time).
  ///
  /// Always reflects actual time, even during tests with mocked clocks.
  wallClock,

  /// Include both wall-clock and clock timestamps.
  both,

  /// Include wall-clock, and additionally clock if they differ significantly.
  ///
  /// Useful when running tests with a mocked clock - you'll see both
  /// the real time and the mocked time when they diverge.
  auto,

  /// Don't include any timestamp.
  off,
}
