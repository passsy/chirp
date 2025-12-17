import 'package:chirp/src/core/chirp_interceptor.dart';
import 'package:chirp/src/core/log_record.dart';

/// Signature for interceptor functions used by [DelegatedChirpInterceptor].
///
/// Return the [record] unchanged to pass through, a modified copy to transform,
/// or `null` to reject (prevent writing).
typedef InterceptorFunction = LogRecord? Function(LogRecord record);

/// {@template chirp.DelegatedChirpInterceptor}
/// A [ChirpInterceptor] implementation that delegates to a function.
///
/// This allows creating interceptors inline without defining a class:
///
/// ```dart
/// // Filter logs by level
/// final levelFilter = DelegatedChirpInterceptor(
///   (record) => record.level >= ChirpLogLevel.warning ? record : null,
/// );
///
/// // Redact sensitive data
/// final redactor = DelegatedChirpInterceptor((record) {
///   final message = record.message.toString();
///   if (message.contains('password')) {
///     return record.copyWith(
///       message: message.replaceAll(RegExp(r'password=\S+'), 'password=***'),
///     );
///   }
///   return record;
/// });
///
/// // Add context from zone
/// final contextEnricher = DelegatedChirpInterceptor((record) {
///   final requestId = Zone.current['requestId'];
///   if (requestId != null) {
///     return record.copyWith(data: {...record.data, 'requestId': requestId});
///   }
///   return record;
/// });
/// ```
///
/// For more complex interceptors with state or configuration, consider
/// extending [ChirpInterceptor] directly.
/// {@endtemplate}
class DelegatedChirpInterceptor extends ChirpInterceptor {
  /// The function that intercepts log records.
  final InterceptorFunction _intercept;

  final bool _requiresCallerInfo;

  /// {@macro chirp.DelegatedChirpInterceptor}
  ///
  /// The [intercept] function receives a [LogRecord] and should return:
  /// - The record unchanged to pass through
  /// - A modified copy (via [LogRecord.copyWith]) to transform
  /// - `null` to reject the record and prevent it from being written
  ///
  /// Set [requiresCallerInfo] to `true` if your interceptor needs access to
  /// caller information (file, line, class, method). This triggers stack trace
  /// capture which has a performance cost.
  const DelegatedChirpInterceptor(
    InterceptorFunction intercept, {
    bool requiresCallerInfo = false,
  })  : _intercept = intercept,
        _requiresCallerInfo = requiresCallerInfo;

  @override
  bool get requiresCallerInfo => _requiresCallerInfo;

  @override
  LogRecord? intercept(LogRecord record) => _intercept(record);
}
