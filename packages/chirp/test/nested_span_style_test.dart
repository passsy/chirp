// ignore_for_file: experimental_member_use

import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:test/test.dart';

void main() {
  test('nested styling restores inherited parent colors and removes reverse',
      () {
    final span = AnsiStyled(
        foreground: Ansi16.red,
        child: AnsiStyled(
          bold: true,
          child: SpanSequence(children: [
            AnsiStyled(
                reversed: true,
                foreground: Ansi16.green,
                child: PlainText('inner')),
            PlainText('parent'),
          ]),
        ));
    final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
      colorSupport: TerminalColorSupport.ansi16,
    ));
    renderSpan(span, buffer);
    expect(buffer.toString(),
        contains('\x1b[7m\x1b[32minner\x1b[0m\x1b[31m\x1b[1mparent'));
  });

  test('reverse style is omitted in plain output and reapplied after newlines',
      () {
    for (final support in [
      TerminalColorSupport.none,
      TerminalColorSupport.ansi16
    ]) {
      final buffer = ConsoleMessageBuffer(
          capabilities: TerminalCapabilities(colorSupport: support));
      renderSpan(
          AnsiStyled(reversed: true, child: PlainText('one\ntwo')), buffer);
      expect(stripAnsiCodes(buffer.toString()), 'one\ntwo');
      if (support == TerminalColorSupport.none) {
        expect(buffer.toString(), 'one\ntwo');
      } else {
        expect(buffer.toString(), '\x1b[7mone\n\x1b[7mtwo\x1b[0m');
      }
    }
  });
}
