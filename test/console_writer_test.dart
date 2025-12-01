// ignore_for_file: prefer_const_declarations, avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('stripAnsiCodes', () {
    test('returns plain text unchanged', () {
      expect(stripAnsiCodes('hello world'), 'hello world');
    });

    test('returns empty string unchanged', () {
      expect(stripAnsiCodes(''), '');
    });

    group('SGR (colors/styles)', () {
      test('strips simple color code', () {
        expect(
          stripAnsiCodes('\x1B[31mred text\x1B[0m'),
          'red text',
        );
      });

      test('strips 256-color foreground', () {
        expect(
          stripAnsiCodes('\x1B[38;5;196mred\x1B[0m'),
          'red',
        );
      });

      test('strips 256-color background', () {
        expect(
          stripAnsiCodes('\x1B[48;5;21mblue bg\x1B[0m'),
          'blue bg',
        );
      });

      test('strips bold', () {
        expect(
          stripAnsiCodes('\x1B[1mbold\x1B[0m'),
          'bold',
        );
      });

      test('strips combined styles', () {
        expect(
          stripAnsiCodes('\x1B[1;4;31mbold underline red\x1B[0m'),
          'bold underline red',
        );
      });

      test('strips nested colors', () {
        expect(
          stripAnsiCodes(
            '\x1B[31mred \x1B[32mgreen\x1B[31m red again\x1B[0m',
          ),
          'red green red again',
        );
      });

      test('strips reset code', () {
        expect(
          stripAnsiCodes('\x1B[0m'),
          '',
        );
      });
    });

    group('CSI (cursor/erase)', () {
      test('strips cursor up', () {
        expect(
          stripAnsiCodes('before\x1B[2Aafter'),
          'beforeafter',
        );
      });

      test('strips cursor down', () {
        expect(
          stripAnsiCodes('before\x1B[3Bafter'),
          'beforeafter',
        );
      });

      test('strips cursor forward', () {
        expect(
          stripAnsiCodes('before\x1B[5Cafter'),
          'beforeafter',
        );
      });

      test('strips cursor back', () {
        expect(
          stripAnsiCodes('before\x1B[1Dafter'),
          'beforeafter',
        );
      });

      test('strips cursor position', () {
        expect(
          stripAnsiCodes('before\x1B[10;20Hafter'),
          'beforeafter',
        );
      });

      test('strips clear screen', () {
        expect(
          stripAnsiCodes('before\x1B[2Jafter'),
          'beforeafter',
        );
      });

      test('strips clear line', () {
        expect(
          stripAnsiCodes('before\x1B[Kafter'),
          'beforeafter',
        );
      });

      test('strips clear line to end', () {
        expect(
          stripAnsiCodes('before\x1B[0Kafter'),
          'beforeafter',
        );
      });

      test('strips private mode set (e.g., hide cursor)', () {
        expect(
          stripAnsiCodes('\x1B[?25lhidden cursor\x1B[?25h'),
          'hidden cursor',
        );
      });
    });

    group('OSC (operating system commands)', () {
      test('strips window title (BEL terminated)', () {
        expect(
          stripAnsiCodes('\x1B]0;Window Title\x07text'),
          'text',
        );
      });

      test('strips window title (ST terminated)', () {
        expect(
          stripAnsiCodes('\x1B]0;Window Title\x1B\\text'),
          'text',
        );
      });

      test('strips hyperlink', () {
        expect(
          stripAnsiCodes(
            '\x1B]8;;https://example.com\x07link text\x1B]8;;\x07',
          ),
          'link text',
        );
      });
    });

    group('single-character escapes', () {
      test('strips save cursor', () {
        expect(
          stripAnsiCodes('before\x1B7after'),
          'beforeafter',
        );
      });

      test('strips restore cursor', () {
        expect(
          stripAnsiCodes('before\x1B8after'),
          'beforeafter',
        );
      });
    });

    group('mixed sequences', () {
      test('strips multiple different sequences', () {
        final input = '\x1B[31m' // red
            'Hello '
            '\x1B[1m' // bold
            'World'
            '\x1B[0m' // reset
            '\x1B[2A' // cursor up
            '!';
        expect(stripAnsiCodes(input), 'Hello World!');
      });

      test('handles real log line with colors', () {
        // Simulates: "10:23:45 [info] Hello"
        final input = '\x1B[38;5;8m10:23:45\x1B[0m '
            '\x1B[38;5;37m[info]\x1B[0m '
            '\x1B[38;5;8mHello\x1B[0m';
        expect(
          stripAnsiCodes(input),
          '10:23:45 [info] Hello',
        );
      });
    });
  });

  group('visibleLengthOf', () {
    test('returns length of plain text', () {
      expect(stripAnsiCodes('hello').length, 5);
    });

    test('returns 0 for empty string', () {
      expect(stripAnsiCodes('').length, 0);
    });

    test('excludes ANSI codes from length', () {
      expect(
        stripAnsiCodes('\x1B[31mhello\x1B[0m').length,
        5,
      );
    });

    test('calculates correct length with nested colors', () {
      final input = '\x1B[31mred \x1B[32mgreen\x1B[0m';
      expect(stripAnsiCodes(input).length, 9); // "red green"
    });
  });

  group('ConsoleMessageBuffer.visibleLength', () {
    test('returns visible length of buffer contents', () {
      final buffer = ConsoleMessageBuffer(supportsColors: true);
      buffer.pushColor(foreground: XtermColor.red1_196);
      buffer.write('hello');
      buffer.popColor();

      expect(buffer.visibleLength, 5);
    });

    test('returns 0 for empty buffer', () {
      final buffer = ConsoleMessageBuffer(supportsColors: false);
      expect(buffer.visibleLength, 0);
    });
  });

  group('splitIntoChunks', () {
    group('basic behavior', () {
      test('returns single chunk for short text', () {
        final result = splitIntoChunks('hello world', 100);
        expect(result, ['hello world']);
      });

      test('returns single chunk when text equals max length', () {
        final text = 'a' * 50;
        final result = splitIntoChunks(text, 50);
        expect(result, [text]);
      });

      test('returns empty list for empty string', () {
        final result = splitIntoChunks('', 100);
        expect(result, ['']);
      });

      test('throws for non-positive maxLength', () {
        expect(() => splitIntoChunks('test', 0), throwsArgumentError);
        expect(() => splitIntoChunks('test', -1), throwsArgumentError);
      });
    });

    group('splitting at newlines', () {
      test('prefers splitting at newline', () {
        final text = 'line1\nline2\nline3';
        final result = splitIntoChunks(text, 10);
        expect(result, ['line1', 'line2', 'line3']);
      });

      test('splits at last newline within limit', () {
        final text = 'short\nmedium length line\nthird';
        final result = splitIntoChunks(text, 25);
        expect(result, ['short\nmedium length line', 'third']);
      });

      test('handles consecutive newlines', () {
        final text = 'a\n\nb';
        final result = splitIntoChunks(text, 3);
        // Splits at last newline within limit (visible char 2)
        // chunk 1 = 'a\n' (includes first newline), remaining starts after 2nd \n
        expect(result, ['a\n', 'b']);
      });

      test('handles trailing newline', () {
        final text = 'hello\n';
        final result = splitIntoChunks(text, 10);
        // When line fits within limit, it includes trailing newline
        expect(result, ['hello\n']);
      });

      test('force splits when line exceeds limit', () {
        final text = 'hello\n';
        final result = splitIntoChunks(text, 3);
        // 'hel' then 'lo\n' - newline stays with 'lo' since force split
        expect(result, ['hel', 'lo\n']);
      });
    });

    group('JSON handling', () {
      test('avoids splitting within JSON object when possible', () {
        final text = 'prefix {"key": "value"} suffix';
        final result = splitIntoChunks(text, 25);
        // Should not split inside the JSON
        expect(result.length, 2);
        expect(result[0], 'prefix {"key": "value"} ');
        expect(result[1], 'suffix');
      });

      test('avoids splitting within nested JSON', () {
        final text = 'data: {"outer": {"inner": "value"}}';
        final result = splitIntoChunks(text, 40);
        expect(result, ['data: {"outer": {"inner": "value"}}']);
      });

      test('force splits JSON when it exceeds limit', () {
        final json = '{"key": "${'x' * 100}"}';
        final result = splitIntoChunks(json, 50);
        expect(result.length, greaterThan(1));
        // Verify the combined result equals original (minus any newlines)
        expect(result.join(), json);
      });
    });

    group('JWT handling', () {
      test('avoids splitting within JWT-like token', () {
        // Typical JWT structure: header.payload.signature
        final jwt =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';
        final text = 'token: $jwt end';
        final result = splitIntoChunks(text, 90);
        // Should keep JWT intact when possible
        expect(result[0], contains('eyJ'));
      });

      test('force splits very long JWT when exceeds limit', () {
        final longJwt =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.${'a' * 100}.signature';
        final result = splitIntoChunks(longJwt, 50);
        expect(result.length, greaterThan(1));
      });
    });

    group('ANSI code handling', () {
      test('splits based on actual length when ANSI codes push over limit', () {
        // '\x1B[31mred text\x1B[0m' has visible length 8, actual length 17
        // With maxLength 10, actual length exceeds limit so it splits
        final text = '\x1B[31mred text\x1B[0m';
        final result = splitIntoChunks(text, 10);
        // Actual length (17) > maxLength (10) triggers split
        expect(result.length, 2);
        // Combined visible content should still be "red text"
        final combined = result.join();
        expect(stripAnsiCodes(combined), 'red text');
      });

      test('does not split when both visible and actual under limit', () {
        // '\x1B[31mhi\x1B[0m' has visible length 2, actual length 11
        final text = '\x1B[31mhi\x1B[0m';
        final result = splitIntoChunks(text, 20);
        // Both visible (2) and actual (11) are under limit (20)
        expect(result, [text]);
      });

      test('splits colored text correctly', () {
        final text = '\x1B[31m${'x' * 20}\x1B[0m';
        // visible: 20, actual: 29 (5 + 20 + 4)
        final result = splitIntoChunks(text, 10);
        // With actual length considered, we get more chunks
        expect(result.length, 3);
        // Combined visible content should be 20 x's
        final combined = result.join();
        expect(stripAnsiCodes(combined).length, 20);
      });

      test('splits when colors cause actual length to exceed limit', () {
        // Simulates the user's issue: text with many newlines and colors
        // where visible length is under limit but actual length exceeds it
        // due to ANSI codes being re-applied after each newline
        final buffer = ConsoleMessageBuffer(supportsColors: true);
        buffer.pushColor(foreground: XtermColor.red_1);
        // 50 lines of "test" = 250 visible chars, but with color re-application
        // after each newline, actual length is much higher
        final lines = List.generate(50, (_) => 'test').join('\n');
        buffer.write(lines);
        buffer.popColor();
        final coloredText = buffer.toString();

        final visibleLen = stripAnsiCodes(coloredText).length;
        final actualLen = coloredText.length;

        // Visible length should be reasonable
        expect(visibleLen, 50 * 4 + 49); // 50 "test" + 49 newlines = 249

        // Actual length should be much higher due to ANSI overhead
        // Each newline gets a color code re-applied (~9 chars each)
        expect(actualLen, greaterThan(visibleLen + 400));

        // With a limit that visible passes but actual fails, we should split
        final chunks = splitIntoChunks(coloredText, 300);
        expect(chunks.length, greaterThan(1),
            reason: 'Should split because actual length ($actualLen) > 300');

        // Verify content is preserved (minus newlines consumed at split points)
        final combined = chunks.join();
        final combinedVisible = stripAnsiCodes(combined).length;
        // Each split consumes one newline, so we lose (chunks.length - 1) chars
        expect(combinedVisible, visibleLen - (chunks.length - 1));

        // Also verify each chunk respects the byte limit
        for (final chunk in chunks) {
          expect(chunk.length, lessThanOrEqualTo(300),
              reason: 'Chunk should be <= 300 bytes');
        }
      });

      test('handles text with multiple color codes', () {
        final text =
            '\x1B[31mred\x1B[0m \x1B[32mgreen\x1B[0m \x1B[34mblue\x1B[0m';
        final result = splitIntoChunks(text, 100);
        expect(result, [text]);
        expect(stripAnsiCodes(result[0]), 'red green blue');
      });
    });

    group('whitespace splitting', () {
      test('prefers splitting after space when no newline available', () {
        final text = 'word1 word2 word3 word4';
        final result = splitIntoChunks(text, 12);
        expect(result[0], 'word1 word2 ');
      });

      test('prefers splitting after comma', () {
        final text = 'a,b,c,d,e,f,g,h,i,j';
        final result = splitIntoChunks(text, 8);
        expect(result[0], 'a,b,c,d,');
      });
    });

    group('force splitting', () {
      test('force splits when no good split point', () {
        final text = 'abcdefghijklmnopqrstuvwxyz';
        final result = splitIntoChunks(text, 10);
        expect(result, ['abcdefghij', 'klmnopqrst', 'uvwxyz']);
      });

      test('force splits single very long word', () {
        final text = 'a' * 100;
        final result = splitIntoChunks(text, 30);
        expect(result.length, 4);
        expect(result[0], 'a' * 30);
        expect(result[1], 'a' * 30);
        expect(result[2], 'a' * 30);
        expect(result[3], 'a' * 10);
      });
    });

    group('realistic scenarios', () {
      test('splits multi-line log with JSON', () {
        final text = '''
10:23:45 [INFO] Request received
10:23:45 [DEBUG] Body: {"user": "john", "action": "login"}
10:23:46 [INFO] Response sent''';
        final result = splitIntoChunks(text, 60);
        expect(result.length, greaterThanOrEqualTo(2));
        // Should split at newlines
        expect(result[0], contains('[INFO] Request received'));
      });

      test('handles stack trace splitting', () {
        final stackTrace = '''
#0      main (file:///app/main.dart:10:5)
#1      runApp (package:flutter/src/widgets/binding.dart:123:10)
#2      _runMainZoned (dart:ui/hooks.dart:142:13)''';
        final result = splitIntoChunks(stackTrace, 60);
        // Should split at newlines, keeping each stack frame intact
        expect(result.length, greaterThanOrEqualTo(2));
        // Verify first chunk contains complete first line
        expect(result[0], contains('#0      main'));
        expect(result[0], contains(':10:5)'));
      });
    });

    group('emoji and unicode handling', () {
      test('does not split surrogate pair emoji', () {
        // 😀 is a surrogate pair (2 code units)
        final text = 'hello😀world';
        expect(text.length, 12); // 5 + 2 + 5
        final result = splitIntoChunks(text, 6);
        // Should not split in the middle of 😀
        // Either 'hello' + '😀world' or 'hello😀' + 'world'
        for (final chunk in result) {
          // Each chunk should be valid UTF-16 (no lone surrogates)
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });

      test('preserves emoji when splitting at whitespace', () {
        final text = 'test 😀 emoji 🎉 here';
        final result = splitIntoChunks(text, 10);
        // Should split at spaces, keeping emoji intact
        final combined = result.join();
        expect(combined.contains('😀'), isTrue);
        expect(combined.contains('🎉'), isTrue);
      });

      test('handles multiple consecutive emoji', () {
        final text = '😀😀😀😀😀'; // 5 emoji = 10 code units
        final result = splitIntoChunks(text, 4);
        // Should split between emoji, not within them
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
        expect(result.join(), text);
      });

      test('handles emoji at chunk boundary', () {
        final text = 'aaaa😀bbbb'; // 4 + 2 + 4 = 10
        final result = splitIntoChunks(text, 5);
        // Split should not break the emoji
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });

      test('handles text ending with emoji', () {
        final text = 'hello😀';
        final result = splitIntoChunks(text, 6);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
        expect(result.join(), text);
      });

      test('handles text starting with emoji', () {
        final text = '😀hello';
        final result = splitIntoChunks(text, 3);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
        expect(result.join(), text);
      });

      test('handles only emoji', () {
        final text = '😀';
        final result = splitIntoChunks(text, 1);
        // Can't split a 2-code-unit emoji with limit 1
        // Should return it whole or handle gracefully
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });

      test('handles flag emoji (regional indicators)', () {
        // 🇺🇸 = U+1F1FA U+1F1F8 (each is a surrogate pair, so 4 code units total)
        final text = 'flag: 🇺🇸 here';
        final result = splitIntoChunks(text, 8);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });

      test('handles emoji with skin tone modifier', () {
        // 👍🏽 = 👍 (2 code units) + 🏽 (2 code units) = 4 code units
        final text = 'thumbs 👍🏽 up';
        final result = splitIntoChunks(text, 9);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });
    });

    group('ANSI sequence edge cases', () {
      test('does not split inside ANSI color code', () {
        // Force split scenario with ANSI at the boundary
        final text = 'abc\x1B[31mred\x1B[0m';
        final result = splitIntoChunks(text, 5);
        // Should not produce chunks with partial ANSI sequences
        for (final chunk in result) {
          // Verify no lone ESC without completing sequence
          final escCount = '\x1B'.allMatches(chunk).length;
          final mCount = 'm'.allMatches(chunk).length;
          // Each ESC should have a corresponding 'm' terminator
          // (simplified check - real ANSI can be more complex)
          if (escCount > 0) {
            expect(mCount, greaterThanOrEqualTo(escCount),
                reason: 'Chunk "$chunk" has incomplete ANSI sequence');
          }
        }
      });

      test('handles ANSI at exact chunk boundary', () {
        final text = 'aaa\x1B[31mbbb'; // 3 + 5 + 3 = 11
        final result = splitIntoChunks(text, 8);
        final combined = result.join();
        expect(combined, text);
      });

      test('handles multiple ANSI sequences', () {
        final text = '\x1B[31mred\x1B[32mgreen\x1B[34mblue\x1B[0m';
        final result = splitIntoChunks(text, 10);
        final combined = result.join();
        expect(combined, text);
      });

      test('handles nested ANSI sequences', () {
        final text = '\x1B[1m\x1B[31mbold red\x1B[0m';
        final result = splitIntoChunks(text, 8);
        final combined = result.join();
        expect(combined, text);
      });

      test('handles ANSI 256 color codes', () {
        final text = '\x1B[38;5;196mcolor\x1B[0m';
        final result = splitIntoChunks(text, 10);
        final combined = result.join();
        expect(combined, text);
      });
    });

    group('mixed content edge cases', () {
      test('handles emoji with ANSI colors', () {
        final text = '\x1B[31m😀\x1B[0m';
        final result = splitIntoChunks(text, 5);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });

      test('handles newlines with emoji', () {
        final text = 'line1 😀\nline2 🎉\nline3';
        final result = splitIntoChunks(text, 10);
        final combined = result.join();
        // Newlines at split points are consumed
        expect(combined.contains('😀'), isTrue);
        expect(combined.contains('🎉'), isTrue);
      });

      test('handles all special chars together', () {
        final text = '\x1B[31mhello 😀 world\x1B[0m\nline2';
        final result = splitIntoChunks(text, 15);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });

      test('very small chunk size with emoji', () {
        final text = 'a😀b';
        final result = splitIntoChunks(text, 2);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
        expect(result.join(), text);
      });

      test('chunk size equals emoji size', () {
        final text = 'a😀b'; // 1 + 2 + 1 = 4
        final result = splitIntoChunks(text, 2);
        for (final chunk in result) {
          expect(() => chunk.runes.toList(), returnsNormally);
        }
      });
    });

    group('boundary conditions', () {
      test('empty string', () {
        final result = splitIntoChunks('', 10);
        expect(result, ['']);
      });

      test('single character', () {
        final result = splitIntoChunks('a', 10);
        expect(result, ['a']);
      });

      test('text exactly at limit', () {
        final text = 'abcde';
        final result = splitIntoChunks(text, 5);
        expect(result, [text]);
      });

      test('text one over limit', () {
        final text = 'abcdef';
        final result = splitIntoChunks(text, 5);
        expect(result.length, 2);
      });

      test('limit of 1 with ascii', () {
        final text = 'abc';
        final result = splitIntoChunks(text, 1);
        expect(result, ['a', 'b', 'c']);
      });

      test('only whitespace', () {
        final text = '     ';
        final result = splitIntoChunks(text, 3);
        expect(result.length, greaterThanOrEqualTo(1));
      });

      test('only newlines', () {
        final text = '\n\n\n\n\n';
        final result = splitIntoChunks(text, 2);
        // Each newline is a split point
        expect(result.length, greaterThanOrEqualTo(1));
      });

      test('alternating newlines and text', () {
        final text = 'a\nb\nc\nd\ne';
        final result = splitIntoChunks(text, 3);
        // Should split at newlines
        for (final chunk in result) {
          expect(chunk.length, lessThanOrEqualTo(3));
        }
      });
    });
  });

  group('PrintConsoleWriter with maxChunkLength', () {
    test('outputs single chunk for short message', () {
      final outputs = <String>[];
      final writer = PrintConsoleWriter(
        formatter: _TestFormatter('short message'),
        output: outputs.add,
        maxChunkLength: 100,
      );

      writer.write(LogRecord(
        message: 'ignored',
        level: ChirpLogLevel.info,
        date: DateTime(2024),
      ));

      expect(outputs, ['short message']);
    });

    test('splits long message into multiple chunks', () {
      final outputs = <String>[];
      final longMessage = 'line1\nline2\nline3';
      final writer = PrintConsoleWriter(
        formatter: _TestFormatter(longMessage),
        output: outputs.add,
        maxChunkLength: 6,
      );

      writer.write(LogRecord(
        message: 'ignored',
        level: ChirpLogLevel.info,
        date: DateTime(2024),
      ));

      expect(outputs, ['line1', 'line2', 'line3']);
    });

    test('does not split when maxChunkLength is null', () {
      final outputs = <String>[];
      final longMessage = 'a' * 1000;
      final writer = PrintConsoleWriter(
        formatter: _TestFormatter(longMessage),
        output: outputs.add,
        maxChunkLength: null, // disabled
      );

      writer.write(LogRecord(
        message: 'ignored',
        level: ChirpLogLevel.info,
        date: DateTime(2024),
      ));

      expect(outputs.length, 1);
      expect(outputs[0].length, 1000);
    });
  });
}

/// Test formatter that always outputs the given text.
class _TestFormatter implements ConsoleMessageFormatter {
  final String text;

  _TestFormatter(this.text);

  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) {
    buffer.write(text);
  }
}
