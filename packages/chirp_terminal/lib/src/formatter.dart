// ignore_for_file: experimental_member_use
part of '../chirp_terminal.dart';

/// Formats terminal messages through Chirp's standard span pipeline.
///
/// Both formatter-level transformers and per-record [SpanFormatOptions] apply.
/// Pass [requiresCallerInfo] when a custom span or transformer needs caller data.
class TerminalMessageFormatter extends SpanBasedFormatter {
  TerminalMessageFormatter({
    super.spanTransformers,
    this.requiresCallerInfo = false,
  });

  @override
  final bool requiresCallerInfo;

  @override
  LogSpan buildSpan(LogRecord record) {
    final message = record.message;
    return SpanSequence(children: [
      if (message is Text) message.toSpan() else PlainText(_safeText(message)),
      if (record.error != null) ...[
        NewLine(),
        PlainText(_safeText(record.error)),
      ],
      if (record.stackTrace != null) ...[
        NewLine(),
        PlainText(_safeText(record.stackTrace)),
      ],
    ]);
  }
}
