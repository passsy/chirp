// ignore_for_file: avoid_print
/// Example: Multiple writers with different formats.
///
/// Run with: dart run bin/multiple_writers.dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
      // Human-readable for console
      .addConsoleWriter(formatter: RainbowMessageFormatter())
      // JSON for log files or aggregators
      .addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: (msg) => print('[FILE] $msg'),
      );

  Chirp.info('User logged in', data: {'userId': 'abc123'});
}

// Output:
// 14:32:05.123 [info] User logged in (userId: "abc123")
// [FILE] {"timestamp":"2025-01-15T14:32:05.123","level":"info","message":"User logged in","userId":"abc123"}
