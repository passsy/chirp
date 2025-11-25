import 'package:chirp/chirp.dart';

/// Single-line compact format using spans.
class CompactChirpMessageFormatter extends SpanBasedFormatter {
  CompactChirpMessageFormatter({
    super.spanTransformers,
  });

  @override
  LogSpan buildSpan(LogRecord record) {
    final callerInfo = record.callerInfo;

    // Build class label: loggerName OR location OR className
    final className = record.loggerName ??
        callerInfo?.callerLocation ??
        record.instance?.runtimeType.toString() ??
        'Unknown';

    final String classLabel;
    final instanceHash = record.instanceHash;
    if (instanceHash != null) {
      final hash = instanceHash.toRadixString(16).padLeft(4, '0');
      final shortHash = hash.substring(hash.length >= 4 ? hash.length - 4 : 0);
      classLabel = '$className@$shortHash';
    } else {
      classLabel = className;
    }

    final spans = <LogSpan>[
      Timestamp(record.date),
      const Whitespace(),
      PlainText(classLabel),
      const Whitespace(),
      LogMessage(record.message),
    ];

    // Inline data
    final data = record.data;
    if (data != null && data.isNotEmpty) {
      spans.add(InlineData(data));
    }

    // Error
    if (record.error != null) {
      spans.addAll([
        const NewLine(),
        ErrorSpan(record.error),
      ]);
    }

    // Stack trace
    if (record.stackTrace case final stackTrace?) {
      spans.addAll([
        const NewLine(),
        StackTraceSpan(stackTrace),
      ]);
    }

    return SpanSequence(spans);
  }
}
