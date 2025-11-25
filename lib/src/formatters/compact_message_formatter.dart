import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';

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

    final instanceHash = record.instanceHash;
    final String classLabel;
    if (instanceHash != null) {
      final hash = instanceHash.toRadixString(16).padLeft(4, '0');
      final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);
      classLabel = '$className@$shortHash';
    } else {
      classLabel = className;
    }

    builder.write('$formattedTime $classLabel ${record.message}');

    // Write data inline
    final data = record.data;
    if (data != null && data.isNotEmpty) {
      final dataStr = data.entries
          .map((e) => '${formatYamlKey(e.key)}: ${formatYamlValue(e.value)}')
          .join(', ');
      builder.write(' ($dataStr)');
    }

    if (record.error != null) {
      builder.writeNextLine(record.error);
    }

    if (record.stackTrace != null) {
      builder.writeNextLine(record.stackTrace);
    }
  }
}
