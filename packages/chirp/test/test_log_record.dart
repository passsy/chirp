import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';

/// Default timestamp used for test log records.
final testTimestamp = DateTime(2024, 1, 15, 10, 30, 45, 123);

const _defaultValue = Object();

/// Creates a [LogRecord] for testing with sensible defaults.
///
/// Both [timestamp] and [wallClock] default to [testTimestamp] so tests
/// don't need to specify them unless testing time-related behavior.
LogRecord testRecord({
  Object? message = _defaultValue,
  DateTime? timestamp,
  DateTime? wallClock,
  ChirpLogLevel level = ChirpLogLevel.info,
  String? loggerName,
  Object? instance,
  Object? error,
  StackTrace? stackTrace,
  StackTrace? caller,
  int? skipFrames,
  Map<String, Object?> data = const {},
  List<FormatOptions>? formatOptions,
}) {
  final ts = timestamp ?? testTimestamp;
  return LogRecord(
    message: message != _defaultValue
        ? message
        : 'Test Message from ${clock.now().toIso8601String()}',
    timestamp: ts,
    wallClock: wallClock ?? ts,
    level: level,
    loggerName: loggerName,
    instance: instance,
    error: error,
    stackTrace: stackTrace,
    caller: caller,
    skipFrames: skipFrames,
    data: data,
    formatOptions: formatOptions,
  );
}
