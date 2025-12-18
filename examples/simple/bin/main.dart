// ignore_for_file: avoid_print
/// Advanced example: Span transformers for customizing output.
///
/// Run with: dart run bin/main.dart
///
/// For simpler examples, see:
/// - basic.dart - Zero-config logging
/// - log_levels.dart - All 9 log levels
/// - child_loggers.dart - Context inheritance
/// - instance_tracking.dart - The .chirp extension
/// - multiple_writers.dart - Console + JSON output
/// - interceptors.dart - Filtering and transforming logs
/// - library.dart / app.dart - Library logger adoption
import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

void main() {
  // Configure with span transformers for custom formatting
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: RainbowMessageFormatter(
      spanTransformers: [addEmojiPrefix, boxCriticalMessages],
    ),
  );

  Chirp.info('Application started');
  Chirp.success('Connected to database');
  Chirp.warning('Cache miss, fetching from network');
  Chirp.error('Request failed', error: Exception('timeout'));
  Chirp.critical('System overload detected');
}

/// Adds emoji prefix based on log level.
void addEmojiPrefix(LogSpan tree, LogRecord record) {
  final emoji = switch (record.level.severity) {
    >= 600 => '🔴 ', // critical, wtf
    >= 500 => '❌ ', // error
    >= 400 => '⚠️ ', // warning
    >= 310 => '✅ ', // success
    >= 200 => '📝 ', // info, notice
    _ => '🔍 ', // debug, trace
  };

  tree.findFirst<LogMessage>()?.wrap(
    (child) => SpanSequence(children: [PlainText(emoji), child]),
  );
}

/// Wraps critical messages in a bordered box.
void boxCriticalMessages(LogSpan tree, LogRecord record) {
  if (record.level.severity < 600) return;

  tree.wrap(
    (child) => Bordered(
      child: child,
      style: BoxBorderStyle.rounded,
      borderColor: Ansi256.indianRed_167,
    ),
  );
}

// Output:
// 14:32:05.123 [info] 📝 Application started
// 14:32:05.124 [success] ✅ Connected to database
// 14:32:05.125 [warning] ⚠️ Cache miss, fetching from network
// 14:32:05.126 [error] ❌ Request failed
//   Exception: timeout
// ╭──────────────────────────────────────────────╮
// │ 14:32:05.127 [critical] 🔴 System overload detected │
// ╰──────────────────────────────────────────────╯
