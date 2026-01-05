import 'dart:convert';

import 'package:chirp/chirp.dart';

/// JSON format for structured logging.
///
/// Outputs log records as single-line JSON objects, ideal for log aggregation
/// services and machine parsing.
///
/// ## Output Format
///
/// ```json
/// {
///   "timestamp": "2024-01-15T10:30:45.123Z",
///   "level": "info",
///   "message": "Server started",
///   "logger": "MyService",
///   "instanceHash": "a1b2c3d4",
///   "error": "Exception: Something went wrong",
///   "stackTrace": "#0 main (file.dart:10)",
///   "userId": "user_123"
/// }
/// ```
///
/// ## Features
///
/// - ISO 8601 timestamps in UTC
/// - Lowercase log level names matching Chirp's level names
/// - Custom data fields merged at root level
/// - Optional logger name and instance hash
/// - Error and stack trace support
///
/// ## Usage
///
/// ```dart
/// Chirp.root = ChirpLogger()
///   .addConsoleWriter(formatter: JsonMessageFormatter());
///
/// Chirp.info('Server started', data: {'port': 8080});
/// ```
class JsonMessageFormatter extends ConsoleMessageFormatter {
  /// Whether to include source location in log entries.
  final bool includeSourceLocation;

  /// Creates a JSON message formatter.
  JsonMessageFormatter({
    this.includeSourceLocation = false,
  }) : super();

  @override
  bool get requiresCallerInfo => includeSourceLocation;

  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) {
    final map = <String, dynamic>{};

    // === Core fields ===
    map['timestamp'] = record.timestamp.toUtc().toIso8601String();
    map['level'] = record.level.name;
    map['message'] = record.message?.toString();

    // === Logger name (explicit name set on the logger) ===
    if (record.loggerName != null) {
      map['logger'] = record.loggerName;
    }

    // === Instance info (class name and hash, only together) ===
    if (record.instance != null) {
      map['instance'] = record.instance.runtimeType.toString();
      if (record.instanceHash != null) {
        final hashHex =
            record.instanceHash!.toRadixString(16).padLeft(8, '0');
        map['instanceHash'] =
            hashHex.length > 8 ? hashHex.substring(hashHex.length - 8) : hashHex;
      }
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
