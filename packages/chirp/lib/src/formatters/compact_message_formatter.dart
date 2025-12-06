import 'package:chirp/chirp.dart';

/// Single-line compact format using spans.
///
/// Example output:
/// ```text
/// 10:23:45.123 [info] user_service:42 UserService Processing user (userId: robin)
/// ```
///
/// With error and stack trace:
/// ```text
/// 10:23:45.123 [error] api_client:87 ApiClient Request failed
/// Exception: Connection timeout
/// #0      ApiClient.fetch (package:my_app/api_client.dart:87:5)
/// ```
class CompactChirpMessageFormatter extends SpanBasedFormatter {
  CompactChirpMessageFormatter({
    super.spanTransformers,
  });

  @override
  bool get requiresCallerInfo => true; // Uses callerLocation for class label

  @override
  LogSpan buildSpan(LogRecord record) {
    return SpanSequence(children: [
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
