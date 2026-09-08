// The terminal deliberately integrates Chirp's experimental span API.
// ignore_for_file: experimental_member_use
part of '../chirp_terminal.dart';

/// Immutable message that builds a fresh Chirp span tree for each render.
/// [toString] returns plain text for file and JSON writers.
class Text {
  Text(String value)
      : _build = (() => PlainText(_safeText(value))),
        _plainText = value;

  /// Adapts any Chirp span, including custom spans and layout spans.
  /// [build] must return a fresh, unparented tree on each call because Chirp's
  /// transformers mutate span trees. [plainText] is the persisted message.
  Text.fromSpan(LogSpan Function() build, {required String plainText})
      : _build = build,
        _plainText = plainText;

  final LogSpan Function() _build;
  final String _plainText;

  /// Builds a new mutable tree; mutating it does not change this message.
  LogSpan toSpan() => _build();

  Text operator +(Text other) {
    return Text.fromSpan(
      () => SpanSequence(children: [toSpan(), other.toSpan()]),
      plainText: '$_plainText${other._plainText}',
    );
  }

  Text foreground(ConsoleColor color) => _styled(foreground: color);
  Text background(ConsoleColor color) => _styled(background: color);
  Text red() => foreground(Ansi16.red);
  Text green() => foreground(Ansi16.green);
  Text yellow() => foreground(Ansi16.yellow);
  Text blue() => foreground(Ansi16.blue);
  Text cyan() => foreground(Ansi16.cyan);
  Text magenta() => foreground(Ansi16.magenta);
  Text bold() => _styled(bold: true);
  Text dim() => _styled(dim: true);
  Text italic() => _styled(italic: true);
  Text underline() => _styled(underline: true);
  Text strikethrough() => _styled(strikethrough: true);
  Text reversed() => _styled(reversed: true);

  Text _styled({
    ConsoleColor? foreground,
    ConsoleColor? background,
    bool? bold,
    bool? dim,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? reversed,
  }) {
    return Text.fromSpan(() {
      final span = toSpan();
      final style = span is AnsiStyled ? span : null;
      return AnsiStyled(
        child: style == null ? span : style.child,
        foreground: foreground ?? style?.foreground,
        background: background ?? style?.background,
        bold: bold ?? style?.bold ?? false,
        dim: dim ?? style?.dim ?? false,
        italic: italic ?? style?.italic ?? false,
        underline: underline ?? style?.underline ?? false,
        strikethrough: strikethrough ?? style?.strikethrough ?? false,
        reversed: reversed ?? style?.reversed ?? false,
      );
    }, plainText: _plainText);
  }

  String render(TerminalCapabilities capabilities) {
    final buffer = ConsoleMessageBuffer(capabilities: capabilities);
    renderSpan(toSpan(), buffer);
    return buffer.toString();
  }

  @override
  String toString() => _plainText;
}

// User content must not move the cursor or inject terminal control sequences.
String _safeText(Object? value) {
  return stripAnsiCodes(value?.toString() ?? '')
      .replaceAll(RegExp(r'[\x00-\x08\x0b-\x1f\x7f]'), '')
      .replaceAll('\t', '    ');
}

int _cellWidth(String grapheme) {
  final rune = grapheme.runes.first;
  if (rune >= 0x1100 &&
      (rune <= 0x115f ||
          rune == 0x2329 ||
          rune == 0x232a ||
          (rune >= 0x2e80 && rune <= 0xa4cf) ||
          (rune >= 0xac00 && rune <= 0xd7a3) ||
          (rune >= 0xf900 && rune <= 0xfaff) ||
          (rune >= 0xfe10 && rune <= 0xfe6f) ||
          (rune >= 0xff01 && rune <= 0xff60) ||
          (rune >= 0xffe0 && rune <= 0xffe6) ||
          rune >= 0x1f000)) {
    return 2;
  }
  if (grapheme.contains('\ufe0f')) {
    return 2;
  }
  return 1;
}

int _width(String text) => text.characters.fold(0, (n, c) => n + _cellWidth(c));

String _clip(String text, int width) {
  final buffer = StringBuffer();
  var used = 0;
  for (final c in text.characters) {
    used += _cellWidth(c);
    if (used > width) {
      break;
    }
    buffer.write(c);
  }
  return buffer.toString();
}
