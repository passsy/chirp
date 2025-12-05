import 'dart:convert';

import 'package:chirp/chirp.dart';

/// JSON format for structured logging
class JsonMessageFormatter extends ConsoleMessageFormatter {
  JsonMessageFormatter() : super();

  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) {
    // Try to get caller location first
    final String? callerLocation = record.caller != null
        ? getCallerInfo(record.caller!)?.callerLocation
        : null;

    final className = record.loggerName ??
        callerLocation ??
        record.instance?.runtimeType.toString() ??
        'Unknown';

    final map = <String, dynamic>{
      'timestamp': record.timestamp.toIso8601String(),
      'level': record.level.name,
      'class': className,
      'hash': (record.instanceHash ?? 0).toRadixString(16).padLeft(4, '0'),
      'message': record.message?.toString(),
    };

    if (record.error != null) {
      map['error'] = record.error.toString();
    }

    if (record.stackTrace != null) {
      map['stackTrace'] = record.stackTrace.toString();
    }

    final data = record.data;
    if (data.isNotEmpty) {
      map['data'] = data;
    }

    final jsonObject = jsonEncode(map);
    buffer.write(jsonObject);
  }
}
