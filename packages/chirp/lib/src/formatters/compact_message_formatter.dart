import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

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
  /// Controls which timestamp(s) to display.
  ///
  /// - [TimeDisplay.clock]: Show only the clock timestamp (mockable in tests)
  /// - [TimeDisplay.wallClock]: Show only the wall-clock (real system time)
  /// - [TimeDisplay.both]: Always show both timestamps
  /// - [TimeDisplay.auto]: Show clock timestamp, and wall-clock in brackets
  ///   if they differ by more than 1 second
  /// - [TimeDisplay.off]: Don't show any timestamp
  final TimeDisplay timeDisplay;

  /// Creates a compact message formatter.
  ///
  /// Use [spanTransformers] to customize the output structure.
  CompactChirpMessageFormatter({
    this.timeDisplay = TimeDisplay.clock,
    super.spanTransformers,
  });

  @override
  bool get requiresCallerInfo => true; // Uses callerLocation for class label

  @override
  LogSpan buildSpan(LogRecord record) {
    final timestampSpans = switch (timeDisplay) {
      TimeDisplay.clock => [Timestamp(record.timestamp)],
      TimeDisplay.wallClock => [Timestamp(record.wallClock)],
      TimeDisplay.both => [
          Timestamp(record.wallClock),
          Whitespace(),
          BracketedTimestamp(record.timestamp),
        ],
      TimeDisplay.auto => [
          Timestamp(record.wallClock),
          if (record.wallClock.difference(record.timestamp).abs() >
              const Duration(milliseconds: 1)) ...[
            Whitespace(),
            BracketedTimestamp(record.timestamp),
          ],
        ],
      TimeDisplay.off => <LogSpan>[],
    };

    return SpanSequence(children: [
      ...timestampSpans,
      if (timestampSpans.isNotEmpty) Whitespace(),
      BracketedLogLevel(record.level),
      if (record.callerInfo?.callerLocation case final callerLocation?) ...[
        Whitespace(),
        PlainText(callerLocation),
      ],
      Surrounded(prefix: Whitespace(), child: ClassName.fromRecord(record)),
      Whitespace(),
      LogMessage(record.message),
      if (record.data.isNotEmpty)
        Surrounded(
          prefix: PlainText(' ('),
          child: InlineData(record.data),
          suffix: PlainText(')'),
        ),
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
