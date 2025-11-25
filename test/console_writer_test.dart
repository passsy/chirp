import 'package:chirp/chirp.dart';
import 'package:chirp/src/xterm_colors.g.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleMessageBuffer.stripAnsiCodes', () {
    test('returns plain text unchanged', () {
      expect(ConsoleMessageBuffer.stripAnsiCodes('hello world'), 'hello world');
    });

    test('returns empty string unchanged', () {
      expect(ConsoleMessageBuffer.stripAnsiCodes(''), '');
    });

    group('SGR (colors/styles)', () {
      test('strips simple color code', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[31mred text\x1B[0m'),
          'red text',
        );
      });

      test('strips 256-color foreground', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[38;5;196mred\x1B[0m'),
          'red',
        );
      });

      test('strips 256-color background', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[48;5;21mblue bg\x1B[0m'),
          'blue bg',
        );
      });

      test('strips bold', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[1mbold\x1B[0m'),
          'bold',
        );
      });

      test('strips combined styles', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[1;4;31mbold underline red\x1B[0m'),
          'bold underline red',
        );
      });

      test('strips nested colors', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes(
            '\x1B[31mred \x1B[32mgreen\x1B[31m red again\x1B[0m',
          ),
          'red green red again',
        );
      });

      test('strips reset code', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[0m'),
          '',
        );
      });
    });

    group('CSI (cursor/erase)', () {
      test('strips cursor up', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[2Aafter'),
          'beforeafter',
        );
      });

      test('strips cursor down', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[3Bafter'),
          'beforeafter',
        );
      });

      test('strips cursor forward', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[5Cafter'),
          'beforeafter',
        );
      });

      test('strips cursor back', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[1Dafter'),
          'beforeafter',
        );
      });

      test('strips cursor position', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[10;20Hafter'),
          'beforeafter',
        );
      });

      test('strips clear screen', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[2Jafter'),
          'beforeafter',
        );
      });

      test('strips clear line', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[Kafter'),
          'beforeafter',
        );
      });

      test('strips clear line to end', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B[0Kafter'),
          'beforeafter',
        );
      });

      test('strips private mode set (e.g., hide cursor)', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B[?25lhidden cursor\x1B[?25h'),
          'hidden cursor',
        );
      });
    });

    group('OSC (operating system commands)', () {
      test('strips window title (BEL terminated)', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B]0;Window Title\x07text'),
          'text',
        );
      });

      test('strips window title (ST terminated)', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('\x1B]0;Window Title\x1B\\text'),
          'text',
        );
      });

      test('strips hyperlink', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes(
            '\x1B]8;;https://example.com\x07link text\x1B]8;;\x07',
          ),
          'link text',
        );
      });
    });

    group('single-character escapes', () {
      test('strips save cursor', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B7after'),
          'beforeafter',
        );
      });

      test('strips restore cursor', () {
        expect(
          ConsoleMessageBuffer.stripAnsiCodes('before\x1B8after'),
          'beforeafter',
        );
      });
    });

    group('mixed sequences', () {
      test('strips multiple different sequences', () {
        final input = '\x1B[31m'        // red
            'Hello '
            '\x1B[1m'                   // bold
            'World'
            '\x1B[0m'                   // reset
            '\x1B[2A'                   // cursor up
            '!';
        expect(ConsoleMessageBuffer.stripAnsiCodes(input), 'Hello World!');
      });

      test('handles real log line with colors', () {
        // Simulates: "10:23:45 [info] Hello"
        final input = '\x1B[38;5;8m10:23:45\x1B[0m '
            '\x1B[38;5;37m[info]\x1B[0m '
            '\x1B[38;5;8mHello\x1B[0m';
        expect(
          ConsoleMessageBuffer.stripAnsiCodes(input),
          '10:23:45 [info] Hello',
        );
      });
    });
  });

  group('ConsoleMessageBuffer.visibleLengthOf', () {
    test('returns length of plain text', () {
      expect(ConsoleMessageBuffer.visibleLengthOf('hello'), 5);
    });

    test('returns 0 for empty string', () {
      expect(ConsoleMessageBuffer.visibleLengthOf(''), 0);
    });

    test('excludes ANSI codes from length', () {
      expect(
        ConsoleMessageBuffer.visibleLengthOf('\x1B[31mhello\x1B[0m'),
        5,
      );
    });

    test('calculates correct length with nested colors', () {
      final input = '\x1B[31mred \x1B[32mgreen\x1B[0m';
      expect(ConsoleMessageBuffer.visibleLengthOf(input), 9); // "red green"
    });
  });

  group('ConsoleMessageBuffer.visibleLength', () {
    test('returns visible length of buffer contents', () {
      final buffer = ConsoleMessageBuffer(useColors: true);
      buffer.pushColor(foreground: XtermColor.color196);
      buffer.write('hello');
      buffer.popColor();

      expect(buffer.visibleLength, 5);
    });

    test('returns 0 for empty buffer', () {
      final buffer = ConsoleMessageBuffer();
      expect(buffer.visibleLength, 0);
    });
  });
}
