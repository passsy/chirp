import 'package:chirp/chirp.dart';

/// JSON formatter for structured log files.
///
/// Produces one JSON object per line (JSONL/NDJSON format), suitable for
/// log aggregation systems like Elasticsearch, Splunk, or CloudWatch.
///
/// Use `.jsonl` or `.ndjson` file extension when using this formatter:
///
/// ```dart
/// final writer = RotatingFileWriter(
///   baseFilePath: '/var/log/app.jsonl',
///   formatter: JsonFileFormatter(),
/// );
/// ```
class JsonFileFormatter implements FileMessageFormatter {
  /// Creates a JSON file formatter.
  const JsonFileFormatter();

  @override
  bool get requiresCallerInfo => false;

  @override
  String format(LogRecord record) {
    final map = <String, Object?>{
      'timestamp': record.timestamp.toIso8601String(),
      'level': record.level.name,
      'message': record.message?.toString(),
    };

    if (record.loggerName != null) {
      map['logger'] = record.loggerName;
    }

    if (record.data.isNotEmpty) {
      map['data'] = record.data;
    }

    if (record.error != null) {
      map['error'] = record.error.toString();
    }

    if (record.stackTrace != null) {
      map['stackTrace'] = record.stackTrace.toString();
    }

    // Simple JSON encoding without external dependency
    return _encodeJson(map);
  }
}

String _encodeJson(Map<String, Object?> map) {
  final pairs = <String>[];
  for (final entry in map.entries) {
    final key = _escapeString(entry.key);
    final value = _encodeValue(entry.value);
    pairs.add('"$key":$value');
  }
  return '{${pairs.join(',')}}';
}

String _encodeValue(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value.toString();
  if (value is num) return value.toString();
  if (value is String) return '"${_escapeString(value)}"';
  if (value is Map) {
    final pairs = <String>[];
    for (final entry in value.entries) {
      final key = _escapeString(entry.key.toString());
      final val = _encodeValue(entry.value);
      pairs.add('"$key":$val');
    }
    return '{${pairs.join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_encodeValue).join(',')}]';
  }
  return '"${_escapeString(value.toString())}"';
}

String _escapeString(String s) {
  return s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
}
