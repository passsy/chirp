// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('MessageBuffer.toString()', () {
    test('returns console buffer contents', () {
      final consoleBuffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      final buffer = MessageBuffer(consoleBuffer);

      buffer.write('hello');
      buffer.write(' world');

      expect(buffer.toString(), 'hello world');
    });

    test('returns file buffer contents', () {
      final fileBuffer = FileMessageBuffer();
      final buffer = MessageBuffer(fileBuffer);

      buffer.write('hello');
      buffer.write(' world');

      expect(buffer.toString(), 'hello world');
    });

    test('returns empty string for empty console buffer', () {
      final consoleBuffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      final buffer = MessageBuffer(consoleBuffer);

      expect(buffer.toString(), '');
    });

    test('returns empty string for empty file buffer', () {
      final fileBuffer = FileMessageBuffer();
      final buffer = MessageBuffer(fileBuffer);

      expect(buffer.toString(), '');
    });

    test('includes newlines from writeln()', () {
      final consoleBuffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      final buffer = MessageBuffer(consoleBuffer);

      buffer.writeln('line 1');
      buffer.write('line 2');

      expect(buffer.toString(), 'line 1\nline 2');
    });
  });
}
