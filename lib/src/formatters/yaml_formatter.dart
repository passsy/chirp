/// Formats a value as YAML-like lines with proper indentation.
///
/// Returns a list of lines without trailing newlines.
List<String> formatAsYaml(Object? value, int indent) {
  final indentStr = '  ' * indent;

  if (value == null) {
    return ['${indentStr}null'];
  }

  if (value is Map) {
    if (value.isEmpty) {
      return ['$indentStr{}'];
    }
    final lines = <String>[];
    for (final entry in value.entries) {
      final key = entry.key;
      final val = entry.value;

      final formattedKey = formatYamlKey(key);
      if (val is Map || val is List) {
        // Complex value: key on its own line, value indented below
        if ((val is Map && val.isEmpty) || (val is List && val.isEmpty)) {
          // Empty collections inline
          final emptyVal = val is Map ? '{}' : '[]';
          lines.add('$indentStr$formattedKey: $emptyVal');
        } else {
          lines.add('$indentStr$formattedKey:');
          lines.addAll(formatAsYaml(val, indent + 1));
        }
      } else {
        // Simple value: key: value on same line
        final formattedValue = formatYamlValue(val);
        lines.add('$indentStr$formattedKey: $formattedValue');
      }
    }
    return lines;
  }

  if (value is List) {
    if (value.isEmpty) {
      return ['$indentStr[]'];
    }
    final lines = <String>[];
    for (final item in value) {
      if (item is Map || item is List) {
        // Complex item: dash on its own line, value indented below
        if ((item is Map && item.isEmpty) || (item is List && item.isEmpty)) {
          final emptyVal = item is Map ? '{}' : '[]';
          lines.add('$indentStr- $emptyVal');
        } else {
          lines.add('$indentStr-');
          lines.addAll(formatAsYaml(item, indent + 1));
        }
      } else {
        // Simple item: dash and value on same line
        final formattedValue = formatYamlValue(item);
        lines.add('$indentStr- $formattedValue');
      }
    }
    return lines;
  }

  // Scalar value at root level
  return ['$indentStr${formatYamlValue(value)}'];
}

/// Formats a key for YAML output.
///
/// Quotes keys that contain whitespace or special characters.
String formatYamlKey(Object? key) {
  final keyStr = key.toString();

  // Quote keys with whitespace or special characters
  if (keyStr.contains(' ') ||
      keyStr.contains(':') ||
      keyStr.contains('#') ||
      keyStr.contains('\n') ||
      keyStr.contains('\t')) {
    final escaped = keyStr
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    return '"$escaped"';
  }

  return keyStr;
}

/// Formats a scalar value for YAML output.
///
/// Handles strings (with quoting), numbers, booleans, and other objects.
String formatYamlValue(Object? value) {
  if (value == null) {
    return 'null';
  }

  if (value is String) {
    // Always quote strings to distinguish them from other types
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    return '"$escaped"';
  }

  // Numbers, booleans, and other objects - use toString without quotes
  return value.toString();
}
