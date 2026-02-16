// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('MessageBuffer.toString()', () {
    test('returns console buffer contents', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      buffer.write('hello');
      buffer.write(' world');

      expect(buffer.toString(), 'hello world');
    });

    test('returns file buffer contents', () {
      final buffer = MessageBuffer.file();

      buffer.write('hello');
      buffer.write(' world');

      expect(buffer.toString(), 'hello world');
    });

    test('returns empty string for empty console buffer', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      expect(buffer.toString(), '');
    });

    test('returns empty string for empty file buffer', () {
      final buffer = MessageBuffer.file();

      expect(buffer.toString(), '');
    });

    test('includes newlines from writeln()', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      buffer.writeln('line 1');
      buffer.write('line 2');

      expect(buffer.toString(), 'line 1\nline 2');
    });
  });

  group('MessageBuffer.console()', () {
    test('exposes console buffer', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      expect(buffer.console, isNotNull);
      expect(buffer.file, isNull);
    });
  });

  group('MessageBuffer.file()', () {
    test('exposes file buffer', () {
      final buffer = MessageBuffer.file();

      expect(buffer.file, isNotNull);
      expect(buffer.console, isNull);
    });
  });
}
