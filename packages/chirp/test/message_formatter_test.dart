// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('ChirpMessageFormatter', () {
    test('CompactChirpMessageFormatter formats basic message', () {
      final entry = testRecord(message: 'Test message');

      final formatter = CompactChirpMessageFormatter();
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      // CompactChirpMessageFormatter uses callerLocation from stack trace
      // Without a stack trace, callerLocation is null and renders as empty
      expect(result, '10:30:45.123 [info] Test message');
    });

    test('CompactChirpMessageFormatter handles error', () {
      final entry = testRecord(
        message: 'Test message',
        error: Exception('Something went wrong'),
      );

      final formatter = CompactChirpMessageFormatter();
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:30:45.123 [info] Test message\n'
        'Exception: Something went wrong',
      );
    });

    test('CompactChirpMessageFormatter handles stack trace', () {
      final entry = testRecord(
        message: 'Test message',
        stackTrace: StackTrace.fromString('#0 main (test.dart:10)'),
      );

      final formatter = CompactChirpMessageFormatter();
      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(entry, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '10:30:45.123 [info] Test message\n'
        '#0 main (test.dart:10)',
      );
    });
  });
}
