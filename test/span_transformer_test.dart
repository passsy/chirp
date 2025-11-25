import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('SpanTransformer', () {
    test('replaces Timestamp with level emoji', () {
      final record = LogRecord(
        message: 'Hello',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.info,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (span, record) => _replaceTimestampWithEmoji(span, record.level),
        ],
      );

      final builder = ConsoleMessageBuilder();
      formatter.format(record, builder);
      final result = builder.build();

      expect(result, '🔍 Hello');
    });

    test('wraps Timestamp with custom span', () {
      final record = LogRecord(
        message: 'Hello',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.info,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (span, record) => _wrapTimestamp(span),
        ],
      );

      final builder = ConsoleMessageBuilder();
      formatter.format(record, builder);
      final result = builder.build();

      // Timestamp wrapped with brackets
      expect(result, contains('[10:23:45.123]'));
    });

    test('removes Timestamp entirely', () {
      final record = LogRecord(
        message: 'Hello',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.info,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (span, record) => _removeTimestamp(span),
        ],
      );

      final builder = ConsoleMessageBuilder();
      formatter.format(record, builder);
      final result = builder.build();

      // No timestamp in output
      expect(result, isNot(contains('10:23:45.123')));
      expect(result, contains('Hello'));
    });
  });
}

/// Recursively replaces Timestamp spans with an emoji based on log level.
LogSpan _replaceTimestampWithEmoji(LogSpan span, ChirpLogLevel level) {
  if (span is Timestamp) {
    return _LevelEmojiSpan(level);
  }
  if (span is Styled) {
    return Styled(
      foreground: span.foreground,
      background: span.background,
      child: _replaceTimestampWithEmoji(span.child, level),
    );
  }
  if (span is Row) {
    return Row(
        span.children.map((s) => _replaceTimestampWithEmoji(s, level)).toList());
  }
  if (span is Prefixed) {
    return Prefixed(
      prefix: _replaceTimestampWithEmoji(span.prefix, level),
      child: span.child != null
          ? _replaceTimestampWithEmoji(span.child!, level)
          : null,
    );
  }
  return span;
}

/// Recursively wraps Timestamp spans with brackets.
LogSpan _wrapTimestamp(LogSpan span) {
  if (span is Timestamp) {
    return _BracketedSpan(child: span);
  }
  if (span is Styled) {
    return Styled(
      foreground: span.foreground,
      background: span.background,
      child: _wrapTimestamp(span.child),
    );
  }
  if (span is Row) {
    return Row(span.children.map(_wrapTimestamp).toList());
  }
  if (span is Prefixed) {
    return Prefixed(
      prefix: _wrapTimestamp(span.prefix),
      child: span.child != null ? _wrapTimestamp(span.child!) : null,
    );
  }
  return span;
}

/// Recursively removes Timestamp spans.
LogSpan _removeTimestamp(LogSpan span) {
  if (span is Timestamp) {
    return const Text('');
  }
  if (span is Styled) {
    final child = _removeTimestamp(span.child);
    // Skip empty styled spans
    if (child is Text && child.value.isEmpty) {
      return const Text('');
    }
    return Styled(
      foreground: span.foreground,
      background: span.background,
      child: child,
    );
  }
  if (span is Row) {
    return Row(span.children.map(_removeTimestamp).toList());
  }
  if (span is Prefixed) {
    return Prefixed(
      prefix: _removeTimestamp(span.prefix),
      child: span.child != null ? _removeTimestamp(span.child!) : null,
    );
  }
  return span;
}

/// Custom span that shows an emoji based on log level.
class _LevelEmojiSpan extends LogSpan {
  final ChirpLogLevel level;

  const _LevelEmojiSpan(this.level);

  @override
  LogSpan build() {
    final emoji = switch (level.severity) {
      >= 500 => '❌',
      >= 400 => '⚠️',
      >= 300 => 'ℹ️',
      _ => '🔍',
    };
    return Text(emoji);
  }
}

/// Custom span that wraps a child with brackets.
class _BracketedSpan extends LogSpan {
  final LogSpan child;

  const _BracketedSpan({required this.child});

  @override
  LogSpan build() => Row([const Text('['), child, const Text(']')]);
}
