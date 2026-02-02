// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  // Common timestamps for testing
  final clockTime = DateTime(2024, 1, 15, 10, 30, 45, 123);
  final wallClockTime = DateTime(2024, 1, 15, 10, 30, 47, 891);
  final sameTime = DateTime(2024, 1, 15, 10, 30, 45, 123);

  ConsoleMessageBuffer createBuffer() {
    return ConsoleMessageBuffer(
      capabilities:
          const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
    );
  }

  group('SimpleConsoleMessageFormatter timeDisplay', () {
    test('clock - shows only clock timestamp', () {
      final formatter = SimpleConsoleMessageFormatter(
        timeDisplay: TimeDisplay.clock,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:45.123'));
      expect(result, isNot(contains('10:30:47.891')));
      expect(result, isNot(contains('[10:')));
    });

    test('wallClock - shows only wall-clock timestamp', () {
      final formatter = SimpleConsoleMessageFormatter(
        timeDisplay: TimeDisplay.wallClock,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:47.891'));
      expect(result, isNot(contains('10:30:45.123')));
    });

    test('both - shows wall-clock with clock in brackets', () {
      final formatter = SimpleConsoleMessageFormatter(
        timeDisplay: TimeDisplay.both,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:47.891 [10:30:45.123]'));
    });

    test('auto - shows only wall-clock when times are same', () {
      final formatter = SimpleConsoleMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: sameTime,
        wallClock: sameTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:45.123'));
      expect(result, isNot(contains('[10:')));
    });

    test('auto - shows both when times differ by more than 1ms', () {
      final formatter = SimpleConsoleMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:47.891 [10:30:45.123]'));
    });

    test('off - shows no timestamp', () {
      final formatter = SimpleConsoleMessageFormatter(
        timeDisplay: TimeDisplay.off,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, isNot(contains('10:30')));
      expect(result, startsWith('[info]'));
    });
  });

  group('CompactChirpMessageFormatter timeDisplay', () {
    test('clock - shows only clock timestamp', () {
      final formatter = CompactChirpMessageFormatter(
        timeDisplay: TimeDisplay.clock,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:45.123'));
      expect(result, isNot(contains('10:30:47.891')));
    });

    test('wallClock - shows only wall-clock timestamp', () {
      final formatter = CompactChirpMessageFormatter(
        timeDisplay: TimeDisplay.wallClock,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:47.891'));
      expect(result, isNot(contains('10:30:45.123')));
    });

    test('both - shows wall-clock with clock in brackets', () {
      final formatter = CompactChirpMessageFormatter(
        timeDisplay: TimeDisplay.both,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:47.891 [10:30:45.123]'));
    });

    test('auto - shows only wall-clock when times are same', () {
      final formatter = CompactChirpMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: sameTime,
        wallClock: sameTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:45.123'));
      expect(result, isNot(contains('[10:')));
    });

    test('auto - shows both when times differ by more than 1ms', () {
      final formatter = CompactChirpMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, startsWith('10:30:47.891 [10:30:45.123]'));
    });

    test('off - shows no timestamp', () {
      final formatter = CompactChirpMessageFormatter(
        timeDisplay: TimeDisplay.off,
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, isNot(contains('10:30')));
      expect(result, startsWith('[info]'));
    });
  });

  group('RainbowMessageFormatter timeDisplay', () {
    test('clock - shows only clock timestamp', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.clock,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:45.123'));
      expect(result, isNot(contains('10:30:47.891')));
    });

    test('wallClock - shows only wall-clock timestamp', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.wallClock,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:47.891'));
      expect(result, isNot(contains('10:30:45.123')));
    });

    test('both - shows wall-clock with clock in brackets', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.both,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:47.891'));
      expect(result, contains('[10:30:45.123]'));
    });

    test('auto - shows only wall-clock when times are same', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.auto,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: sameTime,
        wallClock: sameTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:45.123'));
      expect(result, isNot(contains('[10:')));
    });

    test('auto - shows both when times differ by more than 1 second', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.auto,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:47.891'));
      expect(result, contains('[10:30:45.123]'));
    });

    test('auto - shows only wall-clock when difference is less than 1 second',
        () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.auto,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      // Difference of 500ms (less than 1 second threshold)
      final record = testRecord(
        timestamp: clockTime,
        wallClock: clockTime.add(const Duration(milliseconds: 500)),
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:45.623'));
      expect(result, isNot(contains('[10:')));
    });

    test('off - shows no timestamp', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          timeDisplay: TimeDisplay.off,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, isNot(contains('10:30')));
    });

    test('deprecated showTime: true maps to TimeDisplay.clock', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          // ignore: deprecated_member_use_from_same_package
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, contains('10:30:45.123'));
      expect(result, isNot(contains('10:30:47.891')));
    });

    test('deprecated showTime: false maps to TimeDisplay.off', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          // ignore: deprecated_member_use_from_same_package
          showTime: false,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, isNot(contains('10:30')));
    });
  });

  group('JsonMessageFormatter timeDisplay', () {
    final clockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
    final wallClockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 47, 891);

    test('clock - includes only timestamp from clock', () {
      final formatter = JsonMessageFormatter(
        timeDisplay: TimeDisplay.clock,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('wallClock - includes only timestamp from wall-clock', () {
      final formatter = JsonMessageFormatter(
        timeDisplay: TimeDisplay.wallClock,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('both - includes timestamp (wall-clock) and clockTime', () {
      final formatter = JsonMessageFormatter(
        timeDisplay: TimeDisplay.both,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded['clockTime'], '2024-01-15T10:30:45.123Z');
    });

    test('auto - includes timestamp (wall-clock) and clockTime', () {
      final formatter = JsonMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // JSON formatters treat 'auto' same as 'both'
      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded['clockTime'], '2024-01-15T10:30:45.123Z');
    });

    test('off - includes no timestamp fields', () {
      final formatter = JsonMessageFormatter(
        timeDisplay: TimeDisplay.off,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('timestamp'), isFalse);
      expect(decoded.containsKey('clockTime'), isFalse);
    });
  });

  group('AwsMessageFormatter timeDisplay', () {
    final clockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
    final wallClockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 47, 891);

    test('clock - includes only timestamp from clock', () {
      final formatter = AwsMessageFormatter(
        timeDisplay: TimeDisplay.clock,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('wallClock - includes only timestamp from wall-clock', () {
      final formatter = AwsMessageFormatter(
        timeDisplay: TimeDisplay.wallClock,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('both - includes timestamp (wall-clock) and clockTime', () {
      final formatter = AwsMessageFormatter(
        timeDisplay: TimeDisplay.both,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded['clockTime'], '2024-01-15T10:30:45.123Z');
    });

    test('auto - includes timestamp (wall-clock) and clockTime', () {
      final formatter = AwsMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // JSON formatters treat 'auto' same as 'both'
      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded['clockTime'], '2024-01-15T10:30:45.123Z');
    });

    test('off - includes no timestamp fields', () {
      final formatter = AwsMessageFormatter(
        timeDisplay: TimeDisplay.off,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('timestamp'), isFalse);
      expect(decoded.containsKey('clockTime'), isFalse);
    });
  });

  group('GcpMessageFormatter timeDisplay', () {
    final clockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
    final wallClockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 47, 891);

    test('clock - includes only timestamp from clock', () {
      final formatter = GcpMessageFormatter(
        timeDisplay: TimeDisplay.clock,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('wallClock - includes only timestamp from wall-clock', () {
      final formatter = GcpMessageFormatter(
        timeDisplay: TimeDisplay.wallClock,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('both - includes timestamp (wall-clock) and clockTime', () {
      final formatter = GcpMessageFormatter(
        timeDisplay: TimeDisplay.both,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded['clockTime'], '2024-01-15T10:30:45.123Z');
    });

    test('auto - includes timestamp (wall-clock) and clockTime', () {
      final formatter = GcpMessageFormatter(
        timeDisplay: TimeDisplay.auto,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // JSON formatters treat 'auto' same as 'both'
      expect(decoded['timestamp'], '2024-01-15T10:30:47.891Z');
      expect(decoded['clockTime'], '2024-01-15T10:30:45.123Z');
    });

    test('off - includes no timestamp fields', () {
      final formatter = GcpMessageFormatter(
        timeDisplay: TimeDisplay.off,
      );
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      expect(decoded.containsKey('timestamp'), isFalse);
      expect(decoded.containsKey('clockTime'), isFalse);
    });
  });

  group('TimeDisplay default values', () {
    test('SimpleConsoleMessageFormatter defaults to TimeDisplay.clock', () {
      final formatter = SimpleConsoleMessageFormatter();
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      // Should show clock time (the default)
      expect(result, startsWith('10:30:45.123'));
    });

    test('CompactChirpMessageFormatter defaults to TimeDisplay.clock', () {
      final formatter = CompactChirpMessageFormatter();
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      // Should show clock time (the default)
      expect(result, startsWith('10:30:45.123'));
    });

    test('RainbowMessageFormatter defaults to TimeDisplay.auto', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );
      final record = testRecord(
        timestamp: clockTime,
        wallClock: wallClockTime,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      // Should show wall-clock with clock in brackets (auto mode, times differ)
      expect(result, contains('10:30:47.891'));
      expect(result, contains('[10:30:45.123]'));
    });

    test('JsonMessageFormatter defaults to TimeDisplay.clock', () {
      final formatter = JsonMessageFormatter();
      final clockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
      final wallClockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 47, 891);
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // Should show clock time (the default)
      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('AwsMessageFormatter defaults to TimeDisplay.clock', () {
      final formatter = AwsMessageFormatter();
      final clockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
      final wallClockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 47, 891);
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // Should show clock time (the default)
      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });

    test('GcpMessageFormatter defaults to TimeDisplay.clock', () {
      final formatter = GcpMessageFormatter();
      final clockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
      final wallClockTimeUtc = DateTime.utc(2024, 1, 15, 10, 30, 47, 891);
      final record = testRecord(
        timestamp: clockTimeUtc,
        wallClock: wallClockTimeUtc,
      );

      final buffer = createBuffer();
      formatter.format(record, buffer);
      final decoded = jsonDecode(buffer.toString()) as Map<String, dynamic>;

      // Should show clock time (the default)
      expect(decoded['timestamp'], '2024-01-15T10:30:45.123Z');
      expect(decoded.containsKey('clockTime'), isFalse);
    });
  });
}
