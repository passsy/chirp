// ignore_for_file: avoid_print
/// Example: TimeDisplay options for controlling timestamp output.
///
/// Run with: dart run bin/time_display.dart
import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';

void main() {
  print('=== TimeDisplay Options ===\n');

  // Simulate a mocked clock (like in tests with fakeAsync)
  final mockedClock = Clock.fixed(DateTime(2024, 1, 15, 10, 30, 45, 123));

  withClock(mockedClock, () {
    print('With a mocked clock, wall-clock and clock time differ:');
    print('  - clock.now() = ${clock.now()}');
    print('  - DateTime.now() = ${DateTime.now()}\n');

    _demonstrateTimeDisplay(TimeDisplay.auto, 'auto (default)');
    _demonstrateTimeDisplay(TimeDisplay.clock, 'clock');
    _demonstrateTimeDisplay(TimeDisplay.wallClock, 'wallClock');
    _demonstrateTimeDisplay(TimeDisplay.both, 'both');
    _demonstrateTimeDisplay(TimeDisplay.off, 'off');
  });

  print('\n=== JSON Formatters ===\n');

  withClock(mockedClock, () {
    _demonstrateJsonTimeDisplay(TimeDisplay.auto, 'auto (default)');
    _demonstrateJsonTimeDisplay(TimeDisplay.clock, 'clock');
    _demonstrateJsonTimeDisplay(TimeDisplay.wallClock, 'wallClock');
    _demonstrateJsonTimeDisplay(TimeDisplay.both, 'both');
    _demonstrateJsonTimeDisplay(TimeDisplay.off, 'off');
  });
}

void _demonstrateTimeDisplay(TimeDisplay mode, String label) {
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: SimpleConsoleMessageFormatter(
      timeDisplay: mode,
      showLoggerName: false,
      showCaller: false,
      showInstance: false,
      showData: false,
    ),
  );

  print('TimeDisplay.$label:');
  Chirp.info('Hello world');
  print('');
}

void _demonstrateJsonTimeDisplay(TimeDisplay mode, String label) {
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: JsonMessageFormatter(timeDisplay: mode),
  );

  print('TimeDisplay.$label:');
  Chirp.info('Hello world');
  print('');
}

// Expected output (wall-clock timestamps will vary based on current time):
//
// === TimeDisplay Options ===
//
// With a mocked clock, wall-clock and clock time differ:
//   - clock.now() = 2024-01-15 10:30:45.123
//   - DateTime.now() = 2025-01-20 15:42:33.456
//
// TimeDisplay.auto (default):
// 15:42:33.456 [10:30:45.123] [info] - Hello world
//
// TimeDisplay.clock:
// 10:30:45.123 [info] - Hello world
//
// TimeDisplay.wallClock:
// 15:42:33.456 [info] - Hello world
//
// TimeDisplay.both:
// 15:42:33.456 [10:30:45.123] [info] - Hello world
//
// TimeDisplay.off:
// [info] - Hello world
