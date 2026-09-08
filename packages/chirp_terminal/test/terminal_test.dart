import 'dart:async';
import 'dart:convert';
import 'dart:io' as fs;
import 'package:chirp_terminal/chirp_terminal.dart';
import 'package:test/test.dart';

class FakeTerminal extends TerminalBackend {
  final keys = StreamController<List<int>>();
  final sizeChanges = StreamController<void>.broadcast();
  final output = StringBuffer();
  final diagnostic = StringBuffer();
  bool raw = false;
  int leaveCount = 0;
  int flushCount = 0;
  @override
  bool inputIsTerminal = true;
  @override
  bool outputIsTerminal = true;
  @override
  bool diagnosticIsTerminal = true;
  @override
  bool supportsAnsi = true;
  @override
  int columns = 80;
  @override
  int rows = 24;
  @override
  Map<String, String> environment = {'TERM': 'xterm-256color'};
  @override
  Stream<List<int>> get input => keys.stream;
  @override
  Stream<void> get resize => sizeChanges.stream;
  @override
  void writeOutput(String text) => output.write(text);
  @override
  void writeDiagnostic(String text) => diagnostic.write(text);
  @override
  void enterRawMode() {
    raw = true;
  }

  @override
  void leaveRawMode() {
    raw = false;
    leaveCount++;
  }

  @override
  Future<void> flush() async {
    flushCount++;
  }

  void send(String text) => keys.add(utf8.encode(text));
}

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 5));
const choices = [Choice(10, label: 'Alpha'), Choice(20, label: 'Beta')];

void main() {
  late FakeTerminal io;
  late ChirpLogger logger;
  late List<LogRecord> records;
  late ChirpTerminal terminal;
  setUp(() {
    io = FakeTerminal();
    records = [];
    logger = ChirpLogger().addWriter(DelegatedChirpWriter(records.add));
    terminal = ChirpTerminal(logger: logger, backend: io);
  });
  tearDown(() async {
    await terminal.close();
    unawaited(io.keys.close());
    await io.sizeChanges.close();
  });
  test('verbose styled spans are hidden on terminal but retained as plain JSON',
      () {
    final text = Text('Cache ') + Text('HIT').green().bold();
    terminal.verbose(text, data: {'count': 42});
    expect(io.diagnostic.toString(), isEmpty);
    expect(records.single.message, same(text));
    final buffer = MessageBuffer.file();
    const JsonLogFormatter().format(records.single, buffer);
    final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
    expect(json['message'], 'Cache HIT');
    expect(buffer.toString(), isNot(contains('\\u001b')));
    terminal.isVerbose = true;
    terminal.verbose(text);
    expect(io.diagnostic.toString(), contains('\x1b[32m'));
    expect(stripAnsiCodes(io.diagnostic.toString()), 'Cache HIT\n');
  });
  test('style composition is immutable', () {
    final plain = Text('hello');
    final styled = plain.red().underline().reversed();
    expect(plain.toString(), 'hello');
    expect(styled.render(const TerminalCapabilities()), 'hello');
    expect(
        styled.render(const TerminalCapabilities(
            colorSupport: TerminalColorSupport.ansi16)),
        contains('\x1b[7m'));
  });
  test('errors are stderr and command output stays exact', () {
    terminal.error('failed', error: StateError('bad'));
    terminal.out.write('{');
    terminal.out.writeCharCode(125);
    terminal.out.writeln();
    expect(io.output.toString(), '{}\n');
    expect(io.diagnostic.toString(), contains('failed\nBad state: bad'));
  });
  test('child loggers share rendering and context', () {
    logger.child(context: {'id': 7}).info(Text('child').cyan());
    expect(records.single.data['id'], 7);
    expect(io.diagnostic.toString(), contains('\x1b[36m'));
  });
  test('redirected stderr ignores TERM color hints', () async {
    await terminal.close();
    io.diagnosticIsTerminal = false;
    terminal = ChirpTerminal(logger: logger, backend: io);
    terminal.info(Text('plain').green());
    expect(terminal.capabilities.supportsColors, isFalse);
    await expectLater(
        terminal.text('Name'), throwsA(isA<NonInteractivePrompt>()));
  });
  test('NO_COLOR preserves interactive input', () async {
    await terminal.close();
    io.environment['NO_COLOR'] = '1';
    terminal = ChirpTerminal(logger: logger, backend: io);
    expect(terminal.capabilities.supportsColors, isFalse);
    final answer = terminal.confirm('Continue');
    io.send('y\r');
    expect(await answer, isTrue);
  });
  test('editing survives intervening log output', () async {
    final answer = terminal.text('Name', initialValue: 'ac');
    io.send('\x1b[Db');
    await pump();
    terminal.info('Background log');
    io.send('\r');
    expect(await answer, 'abc');
    expect(io.diagnostic.toString(), contains('Background log'));
    expect(io.raw, isFalse);
    expect(io.leaveCount, 1);
  });
  test('fragmented UTF8 and escape sequences edit whole graphemes', () async {
    final answer = terminal.text('Name');
    final bytes = utf8.encode('👩‍💻');
    io.keys.add(bytes.sublist(0, 2));
    io.keys.add(bytes.sublist(2));
    await pump();
    io.send('\x1b[');
    await pump();
    io.send('D');
    io.send('a\x1b[F\x7f\r');
    expect(await answer, 'a');
  });
  test('bracketed paste cannot submit a prompt', () async {
    final answer = terminal.text('Name');
    io.send('\x1b[200~hello\nworld\x1b[20');
    await pump();
    io.send('1~');
    await pump();
    expect(io.raw, isTrue);
    io.send('\r');
    expect(await answer, 'hello world');
  });
  test('asynchronous validation permits retry', () async {
    final answer = terminal.text('Name', validate: (value) async {
      await pump();
      return value.length < 2 ? 'Too short' : null;
    });
    io.send('a\r');
    await pump();
    await pump();
    expect(io.diagnostic.toString(), contains('Too short'));
    io.send('b\r');
    expect(await answer, 'ab');
  });
  test('validator exception restores terminal state', () async {
    final assertion = expectLater(
        terminal.text('Name', validate: (_) => throw StateError('validator')),
        throwsStateError);
    io.send('\r');
    await assertion;
    expect(io.raw, isFalse);
  });
  test('password never appears in output or records', () async {
    final answer = terminal.password('Token');
    io.send('supersecret');
    await pump();
    terminal.info('Background');
    io.send('\r');
    expect(await answer, 'supersecret');
    expect(io.diagnostic.toString(), isNot(contains('supersecret')));
    expect(io.diagnostic.toString(), contains('[hidden]'));
    expect(records.map((r) => r.message.toString()), ['Background']);
  });
  test('single select skips disabled choices and returns typed values',
      () async {
    final answer = terminal.select<int>('Pick',
        choices: [
          const Choice(10, label: 'One'),
          const Choice(20, label: 'Two', disabled: true),
          const Choice(30, label: 'Three'),
        ],
        appearance: SelectAppearance.radio);
    io.send('\x1b[B\r');
    expect(await answer, 30);
  });
  test('filtering selects the matching item', () async {
    final answer =
        terminal.select<int>('Pick', searchable: true, choices: choices);
    io.send('bet\r');
    expect(await answer, 20);
  });
  test('multiselect preserves selections across filters', () async {
    final answer = terminal.multiselect<int>('Pick',
        searchable: true, min: 2, choices: choices);
    io.send(' bet \r');
    expect(await answer, [10, 20]);
  });
  test('multiselect enforces minimum and maximum', () async {
    final answer =
        terminal.multiselect<int>('Pick', min: 1, max: 1, choices: choices);
    io.send('\r');
    await pump();
    expect(io.diagnostic.toString(), contains('at least 1'));
    io.send(' \x1b[B \r');
    expect(await answer, [10]);
  });
  test('confirm supports defaults and toggling', () async {
    final answer = terminal.confirm('Continue?', defaultValue: true);
    io.send('\x1b[D\r');
    expect(await answer, isFalse);
  });
  test('Ctrl+C cancels and permits the next prompt', () async {
    final assertion = expectLater(
        terminal.confirm('Continue?'), throwsA(isA<PromptCancelled>()));
    io.send('\x03');
    await assertion;
    expect(io.raw, isFalse);
    final next = terminal.text('Name');
    io.send('ok\r');
    expect(await next, 'ok');
  });
  test('standalone Escape cancels', () async {
    final assertion =
        expectLater(terminal.text('Name'), throwsA(isA<PromptCancelled>()));
    io.send('\x1b');
    await assertion;
    expect(io.raw, isFalse);
  });
  test('EOF does not accept a default', () async {
    final assertion = expectLater(
        terminal.confirm('Continue?', defaultValue: true),
        throwsA(isA<PromptCancelled>()));
    await io.keys.close();
    await assertion;
    expect(io.raw, isFalse);
  });
  test('cancellation and close settle active prompts', () async {
    final cancellation = PromptCancellation();
    final assertion = expectLater(
        terminal.text('Name', cancellation: cancellation),
        throwsA(isA<PromptCancelled>()));
    cancellation.cancel();
    await assertion;
    final closing = expectLater(
        terminal.confirm('Again?'), throwsA(isA<PromptCancelled>()));
    await terminal.close();
    await closing;
    expect(io.raw, isFalse);
    expect(logger.writers, hasLength(1));
    expect(io.flushCount, 1);
  });
  test('concurrent prompt fails without breaking the first', () async {
    final answer = terminal.text('First');
    await expectLater(terminal.text('Second'), throwsStateError);
    io.send('ok\r');
    expect(await answer, 'ok');
  });
  test('progress emits lifecycle records, no animation records', () async {
    final progress = terminal.progress('Upload',
        total: 2, appearance: ProgressAppearance.bar);
    progress.advance();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(records, hasLength(1));
    terminal.info('Intervening log');
    progress.finish('Uploaded');
    progress.finish();
    expect(
        records.map((r) => r.data['progress']), ['started', null, 'completed']);
    expect(records.last.data['completed'], 2);
    expect(records.last.data['durationMs'], isA<int>());
  });
  test('multiple progress styles coexist with a prompt', () async {
    final handles = [
      for (final appearance in ProgressAppearance.values)
        terminal.progress('Work', total: 10, appearance: appearance)
    ];
    final answer = terminal.text('Name');
    io.send('ok');
    handles.first.advance();
    io.send('\r');
    expect(await answer, 'ok');
    for (final handle in handles) {
      handle.cancel();
    }
    expect(
        records.where((r) => r.data['progress'] == 'cancelled'), hasLength(5));
  });
  test('plain progress is static and flush drains application logs', () async {
    await terminal.close();
    var drained = false;
    terminal = ChirpTerminal(
        logger: logger,
        backend: io,
        mode: TerminalMode.nonInteractive,
        flushLogs: () async {
          drained = true;
        });
    final before = io.diagnostic.length;
    final progress = terminal.progress('Upload', total: 2);
    progress.advance();
    progress.finish();
    final output = io.diagnostic.toString().substring(before);
    expect(output, isNot(contains('\x1b')));
    expect(output.split('\n').where((s) => s.isNotEmpty), hasLength(2));
    await terminal.flush();
    expect(drained, isTrue);
  });
  test('plain prompts consume supplied lines and retry invalid answers',
      () async {
    await terminal.close();
    terminal =
        ChirpTerminal(logger: logger, backend: io, mode: TerminalMode.plain);
    final answer = terminal.confirm('Continue?');
    io.send('maybe\nyes\nAlice\n');
    expect(await answer, isTrue);
    expect(await terminal.text('Name'), 'Alice');
    expect(io.raw, isFalse);
  });
  test('number validates bounded integers', () async {
    final answer = terminal.number('Count', min: 1, max: 10, integer: true);
    io.send('NaN\r');
    await pump();
    io.send('\x7f\x7f\x7f5\r');
    expect(await answer, 5);
  });
  test('message content cannot inject terminal controls', () {
    terminal.info(Text('safe\x1b[2J\x07end').red());
    expect(stripAnsiCodes(io.diagnostic.toString()), 'safeend\n');
    expect(io.diagnostic.toString(), isNot(contains('\x1b[2J')));
  });
  test('async search ignores stale responses', () async {
    final requests = <String, Completer<List<Choice<int>>>>{};
    final tokens = <String, PromptCancellation>{};
    final answer = terminal.search<int>('Repo', source: (query, token) {
      tokens[query] = token;
      return (requests[query] = Completer<List<Choice<int>>>()).future;
    });
    await Future<void>.delayed(const Duration(milliseconds: 170));
    io.send('a');
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(tokens['']!.isCancelled, isTrue);
    requests['a']!.complete([const Choice(2, label: 'New')]);
    await pump();
    requests['']!.complete([const Choice(1, label: 'Old')]);
    await pump();
    io.send('\r');
    expect(await answer, 2);
  });
  test('combining marks arriving separately remain one editable grapheme',
      () async {
    final answer = terminal.text('Name');
    io.send('e');
    await pump();
    io.send('\u0301');
    await pump();
    io.send('\x7fX\r');
    expect(await answer, 'X');
  });

  test('resize keeps narrow input usable and bounds the live region', () async {
    io.columns = 12;
    io.rows = 4;
    terminal.progress('Background task');
    final answer = terminal.text('A long title', initialValue: '界界界界界');
    io.columns = 8;
    io.rows = 2;
    io.sizeChanges.add(null);
    await pump();
    io.send('x\r');
    expect(await answer, '界界界界界x');
    expect(io.diagnostic.toString(), isNot(contains('\x1b[-')));
    expect(io.raw, isFalse);
  });

  test('actual file writer persists styled verbose messages as plain JSON',
      () async {
    final directory = fs.Directory.systemTemp.createTempSync('chirp-terminal-');
    final path = '${directory.path}/records.jsonl';
    final writer = RotatingFileWriter(
        baseFilePathProvider: () => path, formatter: const JsonLogFormatter());
    logger.addWriter(writer);
    try {
      terminal
          .verbose(Text('Cache ') + Text('HIT').green(), data: {'count': 42});
      await writer.flush();
      final content = fs.File(path).readAsStringSync();
      final json = jsonDecode(content.trim()) as Map<String, dynamic>;
      expect(json['message'], 'Cache HIT');
      expect(content, isNot(contains('\u001b')));
      expect(io.diagnostic.toString(), isEmpty);
    } finally {
      logger.removeWriter(writer);
      await writer.close();
      directory.deleteSync(recursive: true);
    }
  });

  test('plain async search waits before consuming its selection', () async {
    await terminal.close();
    terminal =
        ChirpTerminal(logger: logger, backend: io, mode: TerminalMode.plain);
    final answer = terminal.search<int>('Repo', source: (query, token) async {
      await pump();
      return [Choice(1, label: query)];
    });
    io.send('repo\n1\n');
    expect(await answer, 1);
  });

  test('noninteractive search never invokes the provider', () async {
    await terminal.close();
    terminal = ChirpTerminal(
        logger: logger, backend: io, mode: TerminalMode.nonInteractive);
    var calls = 0;
    await expectLater(
        terminal.search<int>('Repo', source: (query, token) {
          calls++;
          return Future.value(choices);
        }),
        throwsA(isA<NonInteractivePrompt>()));
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(calls, 0);
  });

  test('progress rejects invalid totals and preserves error records', () {
    expect(() => terminal.progress('Work', total: -1), throwsArgumentError);
    expect(() => terminal.progress('Work', appearance: ProgressAppearance.bar),
        throwsArgumentError);
    final progress = terminal.progress('Work', total: 1);
    expect(() => progress.advance(2), throwsRangeError);
    final error = StateError('network');
    final stack = StackTrace.current;
    progress.fail('Failed', error: error, stackTrace: stack);
    expect(records.last.error, same(error));
    expect(records.last.stackTrace, same(stack));
    expect(() => progress.advance(), throwsStateError);
  });
  test('static progress does not continuously redraw the terminal', () async {
    final progress =
        terminal.progress('Waiting', appearance: ProgressAppearance.staticText);
    final length = io.diagnostic.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(io.diagnostic.length, length);
    progress.finish();
  });
}
