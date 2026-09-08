// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:chirp_terminal/chirp_terminal.dart';
import 'package:test/test.dart';

import 'terminal_test.dart' show FakeTerminal;

class Badge extends LeafSpan {
  Badge(this.label);
  final String label;

  @override
  LogSpan build() {
    return AnsiStyled(
      foreground: Ansi16.cyan,
      child: PlainText('[$label]'),
    );
  }
}

void main() {
  const colors =
      TerminalCapabilities(colorSupport: TerminalColorSupport.ansi16);

  test('Text builds original Chirp spans and fresh trees on every call', () {
    final text = Text('Cache ') + Text('HIT').green().bold();
    final first = text.toSpan();
    final second = text.toSpan();
    expect(first, isA<SpanSequence>());
    expect(first.findAll<PlainText>().map((s) => s.value), ['Cache ', 'HIT']);
    expect(first.findFirst<AnsiStyled>()!.foreground, Ansi16.green);
    expect(first.findFirst<AnsiStyled>()!.bold, isTrue);
    expect(identical(first, second), isFalse);
    first.findFirst<PlainText>()!.replaceWith(PlainText('Changed '));
    expect(text.toString(), 'Cache HIT');
    expect(stripAnsiCodes(text.render(colors)), 'Cache HIT');
    expect(second.findFirst<PlainText>()!.value, 'Cache ');
  });

  test('fluent styles merge into AnsiStyled and preserve last-color wins', () {
    final text = Text('hello').red().blue().bold().strikethrough();
    final span = text.toSpan() as AnsiStyled;
    expect(span.foreground, Ansi16.blue);
    expect(span.bold, isTrue);
    expect(span.strikethrough, isTrue);
    expect(span.child, isA<PlainText>());
    expect(text.render(colors), contains('\x1b[9m'));
  });

  test('custom Chirp spans render while JSON uses the explicit plain message',
      () async {
    final backend = FakeTerminal();
    final records = <LogRecord>[];
    final terminal = ChirpTerminal(
      backend: backend,
      logger: ChirpLogger().addWriter(DelegatedChirpWriter(records.add)),
    );
    try {
      final text = Text.fromSpan(() => Badge('OK'), plainText: 'OK');
      terminal.info(text);
      expect(stripAnsiCodes(backend.diagnostic.toString()), '[OK]\n');
      expect(backend.diagnostic.toString(), contains('\x1b[36m'));
      final buffer = MessageBuffer.file();
      const JsonLogFormatter().format(records.single, buffer);
      expect((jsonDecode(buffer.toString()) as Map)['message'], 'OK');
    } finally {
      await terminal.close();
      await backend.sizeChanges.close();
    }
  });

  test('formatter and per-record transformers share the Chirp pipeline',
      () async {
    final backend = FakeTerminal();
    final records = <LogRecord>[];
    final terminal = ChirpTerminal(
      backend: backend,
      verbose: true,
      logger: ChirpLogger().addWriter(DelegatedChirpWriter(records.add)),
      formatter: TerminalMessageFormatter(spanTransformers: [
        (span, record) {
          span.findFirst<PlainText>()!.replaceWith(PlainText('GLOBAL'));
        },
      ]),
    );
    try {
      final text = Text('original').green();
      terminal.verbose(text, formatOptions: [
        SpanFormatOptions(spanTransformers: [
          (span, record) {
            expect(span.findFirst<PlainText>()!.value, 'GLOBAL');
            span.findFirst<PlainText>()!.replaceWith(PlainText('LOCAL'));
            span.wrap((child) => Bordered(child: child));
          },
        ]),
      ]);
      expect(stripAnsiCodes(backend.diagnostic.toString()), contains('LOCAL'));
      expect(stripAnsiCodes(backend.diagnostic.toString()), contains('│'));
      backend.diagnostic.clear();
      terminal.info(text);
      expect(stripAnsiCodes(backend.diagnostic.toString()), 'GLOBAL\n');
      expect(
          records.map((r) => r.message.toString()), ['original', 'original']);
      expect(stripAnsiCodes(text.render(colors)), 'original');
    } finally {
      await terminal.close();
      await backend.sizeChanges.close();
    }
  });

  test('child loggers forward per-record span options and caller requirements',
      () async {
    final backend = FakeTerminal();
    final terminal = ChirpTerminal(
      backend: backend,
      formatter: TerminalMessageFormatter(
        requiresCallerInfo: true,
        spanTransformers: [
          (span, record) {
            expect(record.caller, isNotNull);
          }
        ],
      ),
    );
    try {
      terminal.logger.child().info(Text('child'), formatOptions: [
        SpanFormatOptions(spanTransformers: [
          (span, record) {
            span.findFirst<PlainText>()!.replaceWith(PlainText('transformed'));
          },
        ]),
      ]);
      expect(stripAnsiCodes(backend.diagnostic.toString()), 'transformed\n');
    } finally {
      await terminal.close();
      await backend.sizeChanges.close();
    }
  });

  test('reused messages in different terminal writers never share mutations',
      () async {
    final first = FakeTerminal();
    final second = FakeTerminal();
    final logger = ChirpLogger();
    final a = ChirpTerminal(
      backend: first,
      logger: logger,
      formatter: TerminalMessageFormatter(spanTransformers: [
        (span, record) {
          span.findFirst<PlainText>()!.replaceWith(PlainText('first'));
        },
      ]),
    );
    final b = ChirpTerminal(backend: second, logger: logger);
    try {
      logger.info(Text('original'));
      expect(stripAnsiCodes(first.diagnostic.toString()), 'first\n');
      expect(stripAnsiCodes(second.diagnostic.toString()), 'original\n');
    } finally {
      await a.close();
      await b.close();
      await first.sizeChanges.close();
      await second.sizeChanges.close();
    }
  });
}
