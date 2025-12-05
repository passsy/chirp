import 'package:chirp/chirp.dart';

/// Single-line compact format using spans.
class CompactChirpMessageFormatter extends SpanBasedFormatter {
  CompactChirpMessageFormatter({
    super.spanTransformers,
  });

  @override
  bool get requiresCallerInfo => true; // Uses callerLocation for class label

  @override
  LogSpan buildSpan(LogRecord record) {
    return SpanSequence([
      Timestamp(record.timestamp),
      Whitespace(),
      BracketedLogLevel(record.level),
      if (record.callerInfo?.callerLocation case final callerLocation?) ...[
        Whitespace(),
        PlainText(callerLocation),
      ],
      Surrounded(prefix: Whitespace(), child: ClassName.fromRecord(record)),
      Whitespace(),
      LogMessage(record.message),
      if (record.data.isNotEmpty) InlineData(record.data),
      if (record.error != null) ...[
        NewLine(),
        ErrorSpan(record.error),
      ],
      if (record.stackTrace case final stackTrace?) ...[
        NewLine(),
        StackTraceSpan(stackTrace),
      ]
    ]);
  }
}
