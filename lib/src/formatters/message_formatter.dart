import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:chirp/src/stack_trace_util.dart';

/// Single-line compact format
class CompactChirpMessageFormatter extends ConsoleMessageFormatter {
  CompactChirpMessageFormatter() : super();

  @override
  void format(LogRecord record, ConsoleMessageBuilder builder) {
    final hour = record.date.hour.toString().padLeft(2, '0');
    final minute = record.date.minute.toString().padLeft(2, '0');
    final second = record.date.second.toString().padLeft(2, '0');
    final ms = record.date.millisecond.toString().padLeft(3, '0');
    final formattedTime = '$hour:$minute:$second.$ms';

    // Try to get caller location first
    final String? callerLocation = record.caller != null
        ? getCallerInfo(record.caller!)?.callerLocation
        : null;

    final className = record.loggerName ??
        callerLocation ??
        record.instance?.runtimeType.toString() ??
        'Unknown';
    final hash = (record.instanceHash ?? 0).toRadixString(16).padLeft(4, '0');
    final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);

    builder.write('$formattedTime $className@$shortHash ${record.message}');

    if (record.error != null) {
      builder.writeNextLine(record.error);
    }

    if (record.stackTrace != null) {
      builder.writeNextLine(record.stackTrace);
    }
  }
}

/// JSON format for structured logging
class JsonMessageFormatter extends ConsoleMessageFormatter {
  JsonMessageFormatter() : super();

  @override
  void format(LogRecord record, ConsoleMessageBuilder builder) {
    // Try to get caller location first
    final String? callerLocation = record.caller != null
        ? getCallerInfo(record.caller!)?.callerLocation
        : null;

    final className = record.loggerName ??
        callerLocation ??
        record.instance?.runtimeType.toString() ??
        'Unknown';

    final map = <String, dynamic>{
      'timestamp': record.date.toIso8601String(),
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

    if (record.data != null) {
      map['data'] = record.data;
    }

    final jsonObject = jsonEncode(map);
    builder.write(jsonObject);
  }
}

/// Google Cloud Platform (GCP) compatible JSON formatter
///
/// Formats logs according to the structure expected by Google Cloud Logging.
/// See: https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry
class GcpChirpMessageFormatter extends ConsoleMessageFormatter {
  /// Optional GCP project ID
  final String? projectId;

  /// Optional GCP log name
  final String? logName;

  /// Whether to include source location information
  final bool includeSourceLocation;

  GcpChirpMessageFormatter({
    this.projectId,
    this.logName,
    this.includeSourceLocation = false,
  }) : super();

  /// Maps a ChirpLogLevel to GCP-compatible severity string
  String _gcpSeverity(ChirpLogLevel level) {
    // Map based on severity ranges following GCP's specification:
    // https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry
    if (level.severity < 100) {
      return 'DEFAULT'; // 0
    } else if (level.severity < 200) {
      return 'DEBUG'; // 100
    } else if (level.severity < 300) {
      return 'INFO'; // 200
    } else if (level.severity < 400) {
      return 'NOTICE'; // 300
    } else if (level.severity < 500) {
      return 'WARNING'; // 400
    } else if (level.severity < 600) {
      return 'ERROR'; // 500
    } else if (level.severity < 700) {
      return 'CRITICAL'; // 600
    } else if (level.severity < 800) {
      return 'ALERT'; // 700
    } else {
      return 'EMERGENCY'; // 800
    }
  }

  @override
  void format(LogRecord entry, ConsoleMessageBuilder builder) {
    final className =
        entry.loggerName ?? entry.instance?.runtimeType.toString();

    final map = <String, dynamic>{
      'severity': _gcpSeverity(entry.level),
      'message': entry.message?.toString(),
      'timestamp': entry.date.toIso8601String(),
    };

    // Add log name if provided
    if (logName != null) {
      map['logName'] = projectId != null
          ? 'projects/$projectId/logs/$logName'
          : 'logs/$logName';
    }

    // Add labels for classification
    final labels = <String, String>{};
    if (className != null) {
      labels['class'] = className;
    }
    if (entry.instanceHash != null) {
      labels['instance_hash'] =
          entry.instanceHash!.toRadixString(16).padLeft(8, '0');
    }
    if (labels.isNotEmpty) {
      map['labels'] = labels;
    }

    // Merge structured data at root level for GCP
    if (entry.data != null) {
      for (final kv in entry.data!.entries) {
        // Avoid overwriting reserved GCP fields
        if (!map.containsKey(kv.key)) {
          map[kv.key] = kv.value;
        }
      }
    }

    // Add error information
    if (entry.error != null) {
      map['error'] = entry.error.toString();
    }

    if (entry.stackTrace != null) {
      map['stackTrace'] = entry.stackTrace.toString();
    }

    builder.write(jsonEncode(map));
  }
}
