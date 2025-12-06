// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpMessageFormatter', () {
    test('CompactChirpMessageFormatter formats basic message', () {
      final entry = LogRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final formatter = CompactChirpMessageFormatter();
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      // CompactChirpMessageFormatter uses callerLocation from stack trace
      // Without a stack trace, callerLocation is null and renders as empty
      expect(result, '10:23:45.123 [info] Test message');
    });

    test('CompactChirpMessageFormatter handles error', () {
      final entry = LogRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Something went wrong'),
      );

      final formatter = CompactChirpMessageFormatter();
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Test message\n'
        'Exception: Something went wrong',
      );
    });

    test('CompactChirpMessageFormatter handles stack trace', () {
      final entry = LogRecord(
        message: 'Test message',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        stackTrace: StackTrace.fromString('#0 main (test.dart:10)'),
      );

      final formatter = CompactChirpMessageFormatter();
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, buffer);
      final result = buffer.toString();

      expect(
        result,
        '10:23:45.123 [info] Test message\n'
        '#0 main (test.dart:10)',
      );
    });
  });
}
