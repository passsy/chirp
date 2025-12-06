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
