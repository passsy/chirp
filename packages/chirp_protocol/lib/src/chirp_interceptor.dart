import 'package:chirp_protocol/src/log_record.dart';

/// Intercepts log records before they reach a writer.
///
/// Interceptors can:
/// - **Pass through**: Return the record unchanged
/// - **Transform**: Return a modified copy of the record (e.g., redaction, enrichment)
/// - **Reject**: Return `null` to prevent the record from being written
///
/// Interceptors are executed in order. Each interceptor receives the output of
/// the previous one. If any interceptor returns `null`, the chain stops.
///
/// ## Example: Level Filter
///
/// ```dart
/// class LevelInterceptor extends ChirpInterceptor {
///   final ChirpLogLevel minLevel;
///   LevelInterceptor(this.minLevel);
///
///   @override
///   LogRecord? intercept(LogRecord record) {
///     return record.level >= minLevel ? record : null;
///   }
/// }
/// ```
///
/// ## Example: Redaction
///
/// ```dart
/// class RedactSecretsInterceptor extends ChirpInterceptor {
///   @override
///   LogRecord? intercept(LogRecord record) {
///     final redacted = record.message.toString().replaceAll(
///       RegExp(r'password=\S+'),
///       'password=***',
///     );
///     return record.copyWith(message: redacted);
///   }
/// }
/// ```
abstract class ChirpInterceptor {
  /// Whether this interceptor requires caller info (file, line, class, method).
  ///
  /// If `true`, the logger will capture `StackTrace.current` for each log call.
  /// If all interceptors and writers return `false`, the expensive stack trace
  /// capture is skipped.
  ///
  /// Override this in subclasses that need to inspect caller information.
  /// Default is `false`.
  bool get requiresCallerInfo => false;

  /// Intercepts a log record.
  ///
  /// Return the [record] unchanged to pass through, a modified copy to transform,
  /// or `null` to reject (prevent writing).
  LogRecord? intercept(LogRecord record);
}
