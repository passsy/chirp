import 'package:chirp/chirp.dart';

class JsonLogFormatter extends ChirpFormatter {
  final TimeDisplay timeDisplay;

  const JsonLogFormatter({
    this.timeDisplay = TimeDisplay.auto,
  });

  @override
  bool get requiresCallerInfo => true;

  @override
  void format(LogRecord record, MessageBuffer buffer) {
    final map = <String, Object?>{};

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

    map['level'] = record.level.name;
    map['message'] = record.message?.toString();

    if (record.loggerName != null) {
      map['logger'] = record.loggerName;
    }

    StackFrameInfo? callerInfo;
    if (record.caller != null) {
      callerInfo =
          getCallerInfo(record.caller!, skipFrames: record.skipFrames ?? 0);
    }

    String? className;
    if (record.instance != null) {
      className = record.instance.runtimeType.toString();
    } else if (callerInfo != null) {
      className = callerInfo.callerClassName;
    }

    if (className != null) {
      map['class'] = className;
    }

    if (record.instance != null) {
      var hashHex =
          identityHashCode(record.instance).toRadixString(16).padLeft(8, '0');
      if (hashHex.length > 8) {
        hashHex = hashHex.substring(hashHex.length - 8);
      }
      map['instance'] = '$className@$hashHex';
    }

    if (callerInfo != null) {
      map['sourceLocation'] = {
        'file': callerInfo.packageRelativePath,
        'line': callerInfo.line,
        'function': callerInfo.callerMethod,
      };
    }

    if (record.error != null) {
      map['error'] = record.error.toString();
    }

    if (record.stackTrace != null) {
      map['stackTrace'] = record.stackTrace.toString();
    }

    for (final entry in record.data.entries) {
      map[entry.key] = entry.value;
    }

    buffer.write(_encodeJsonMap(map));
  }
}

String _encodeJsonMap(Map<String, Object?> map) {
  final pairs = <String>[];
  for (final entry in map.entries) {
    final key = _escapeJsonString(entry.key);
    final value = _encodeJsonValue(entry.value);
    pairs.add('"$key":$value');
  }
  return '{${pairs.join(',')}}';
}

String _encodeJsonValue(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value.toString();
  if (value is num) return value.toString();
  if (value is String) return '"${_escapeJsonString(value)}"';
  if (value is Map) {
    final pairs = <String>[];
    for (final entry in value.entries) {
      final key = _escapeJsonString(entry.key.toString());
      final val = _encodeJsonValue(entry.value);
      pairs.add('"$key":$val');
    }
    return '{${pairs.join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_encodeJsonValue).join(',')}]';
  }
  return '"${_escapeJsonString(value.toString())}"';
}

String _escapeJsonString(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
}

/// Backwards-compatible type alias.
@Deprecated('Use JsonLogFormatter instead')
typedef JsonMessageFormatter = JsonLogFormatter;
