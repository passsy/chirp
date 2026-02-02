import 'dart:convert';

import 'package:chirp/chirp.dart';

/// AWS CloudWatch compatible JSON formatter.
///
/// Formats logs as single-line JSON according to the structure expected by
/// AWS CloudWatch Logs. Output to stdout is automatically parsed by Lambda,
/// ECS, and other AWS services with the CloudWatch Logs agent.
///
/// ## Output Format
///
/// ```json
/// {
///   "timestamp": "2024-01-15T10:30:45.123Z",
///   "level": "INFO",
///   "message": "Server started",
///   "logger": "MyService",
///   "class": "UserService",
///   "instance": "UserService@a1b2c3d4",
///   "error": "Exception: Something went wrong",
///   "stackTrace": "#0 main (file.dart:10)",
///   "userId": "user_123"
/// }
/// ```
///
/// ## Features
///
/// - Maps Chirp log levels to AWS CloudWatch levels (TRACE, DEBUG, INFO, WARN,
///   ERROR, FATAL)
/// - ISO 8601 timestamps in UTC
/// - Optional source location extraction
/// - Error and stack trace support
/// - Custom data fields merged at root level
///
/// ## Log Level Mapping
///
/// Chirp levels are mapped to AWS CloudWatch levels:
/// - trace → TRACE
/// - debug → DEBUG
/// - info, notice, success → INFO
/// - warning → WARN
/// - error → ERROR
/// - critical, wtf → FATAL
///
/// ## Usage
///
/// ```dart
/// Chirp.root = ChirpLogger()
///   .addConsoleWriter(formatter: AwsMessageFormatter());
///
/// Chirp.info('Server started', data: {'port': 8080});
/// // Output: {"timestamp":"2024-01-15T10:30:45.123Z","level":"INFO","message":"Server started","port":8080}
/// ```
///
/// References:
/// - https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-logformat.html
/// - https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-log-level.html
class AwsMessageFormatter extends ConsoleMessageFormatter {
  /// Whether to include source location in log entries.
  final bool includeSourceLocation;

  /// Controls which timestamp(s) to include in log entries.
  ///
  /// - [TimeDisplay.clock]: Include only `timestamp` (from injectable clock)
  /// - [TimeDisplay.wallClock]: Include only `wallClock` (real system time)
  /// - [TimeDisplay.both] or [TimeDisplay.auto]: Include both timestamps
  /// - [TimeDisplay.off]: Include no timestamps
  final TimeDisplay timeDisplay;

  /// Creates an AWS CloudWatch compatible JSON message formatter.
  AwsMessageFormatter({
    this.includeSourceLocation = false,
    this.timeDisplay = TimeDisplay.auto,
  }) : super();

  @override
  bool get requiresCallerInfo => includeSourceLocation;

  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) {
    final map = <String, dynamic>{};

    // === Core fields ===
    switch (timeDisplay) {
      case TimeDisplay.clock:
        map['timestamp'] = record.timestamp.toUtc().toIso8601String();
      case TimeDisplay.wallClock:
        map['timestamp'] = record.wallClock.toUtc().toIso8601String();
      case TimeDisplay.both:
      case TimeDisplay.auto:
        map['timestamp'] = record.wallClock.toUtc().toIso8601String();
        map['clockTime'] = record.timestamp.toUtc().toIso8601String();
      case TimeDisplay.off:
        break;
    }
    map['level'] = _awsLevel(record.level);
    map['message'] = record.message?.toString();

    // === Logger name (explicit name set on the logger) ===
    if (record.loggerName != null) {
      map['logger'] = record.loggerName;
    }

    // === Class (from instance or caller) ===
    final className = () {
      if (record.instance != null) {
        return record.instance.runtimeType.toString();
      }
      if (includeSourceLocation && record.caller != null) {
        final callerInfo =
            getCallerInfo(record.caller!, skipFrames: record.skipFrames ?? 0);
        return callerInfo?.callerClassName;
      }
      return null;
    }();
    if (className != null) {
      map['class'] = className;
    }

    // === Instance (ClassName@hash, only when instance object is present) ===
    if (record.instance != null && record.instanceHash != null) {
      final hashHex = record.instanceHash!.toRadixString(16).padLeft(8, '0');
      final hash =
          hashHex.length > 8 ? hashHex.substring(hashHex.length - 8) : hashHex;
      map['instance'] = '$className@$hash';
    }

    // === Source Location ===
    if (includeSourceLocation && record.caller != null) {
      final callerInfo =
          getCallerInfo(record.caller!, skipFrames: record.skipFrames ?? 0);
      if (callerInfo != null) {
        map['sourceLocation'] = {
          'file': callerInfo.packageRelativePath,
          'line': callerInfo.line,
          'function': callerInfo.callerMethod,
        };
      }
    }

    // === Error and stack trace ===
    if (record.error != null) {
      map['error'] = record.error.toString();
    }

    if (record.stackTrace != null) {
      map['stackTrace'] = record.stackTrace.toString();
    }

    // === Custom data fields at root level ===
    // User data can override any field
    for (final kv in record.data.entries) {
      map[kv.key] = kv.value;
    }

    buffer.write(jsonEncode(map, toEncodable: _toEncodable));
  }
}

/// Converts non-JSON-serializable objects to strings.
Object? _toEncodable(Object? object) {
  return object?.toString();
}

/// Maps a ChirpLogLevel to AWS CloudWatch level string.
///
/// AWS CloudWatch supports: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
/// https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-log-level.html
String _awsLevel(ChirpLogLevel level) {
  if (level.severity >= ChirpLogLevel.critical.severity) return 'FATAL';
  if (level.severity >= ChirpLogLevel.error.severity) return 'ERROR';
  if (level.severity >= ChirpLogLevel.warning.severity) return 'WARN';
  if (level.severity >= ChirpLogLevel.info.severity) return 'INFO';
  if (level.severity >= ChirpLogLevel.debug.severity) return 'DEBUG';
  return 'TRACE';
}
