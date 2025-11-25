import 'package:chirp/chirp.dart';

/// Single-line compact format using spans.
class CompactChirpMessageFormatter extends ConsoleMessageFormatter {
  final List<SpanTransformer> spanTransformers;

  CompactChirpMessageFormatter({
    List<SpanTransformer>? spanTransformers,
  })  : spanTransformers = spanTransformers ?? [],
        super();

  @override
  void format(LogRecord record, ConsoleMessageBuffer builder) {
    final span = buildSpan(record);

    if (spanTransformers.isEmpty) {
      renderSpan(span, builder);
      return;
    }

    final tree = SpanNode.fromSpan(span);
    for (final transformer in spanTransformers) {
      transformer(tree, record);
    }
    renderSpan(tree.toSpan(), builder);
  }

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
