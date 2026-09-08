part of '../chirp_terminal.dart';

/// A terminal session with a Chirp writer attached to [logger].
///
/// The terminal's verbosity only filters its own writer. Keep the supplied
/// logger unfiltered to retain verbose records in file writers. All child
/// loggers inherit the terminal writer. Call [close] in a finally block.
class ChirpTerminal {
  ChirpTerminal({
    ChirpLogger? logger,
    TerminalBackend? backend,
    bool verbose = false,
    this.mode = TerminalMode.auto,
    TerminalCapabilities? capabilities,
    this.flushLogs,
    ChirpFormatter? formatter,
  })  : formatter = formatter ?? TerminalMessageFormatter(),
        logger = logger ?? ChirpLogger(),
        backend = backend ?? StdioTerminalBackend() {
    final env = this.backend.environment;
    _interactive = switch (mode) {
      TerminalMode.interactive => true,
      TerminalMode.plain || TerminalMode.nonInteractive => false,
      TerminalMode.auto => this.backend.inputIsTerminal &&
          this.backend.diagnosticIsTerminal &&
          this.backend.supportsAnsi &&
          env['TERM'] != 'dumb' &&
          !env.containsKey('CI'),
    };
    _canPrompt = mode != TerminalMode.nonInteractive &&
        (mode == TerminalMode.plain ||
            mode == TerminalMode.interactive ||
            (this.backend.inputIsTerminal &&
                this.backend.diagnosticIsTerminal &&
                !env.containsKey('CI')));
    this.capabilities = capabilities ??
        TerminalCapabilities(
          colorSupport: this.backend.diagnosticIsTerminal &&
                  this.backend.supportsAnsi &&
                  !env.containsKey('NO_COLOR') &&
                  env['TERM'] != 'dumb' &&
                  mode != TerminalMode.plain
              ? TerminalColorSupport.ansi16
              : TerminalColorSupport.none,
        );
    _writer = _TerminalWriter(this)
      ..setMinLogLevel(verbose ? ChirpLogLevel.trace : ChirpLogLevel.info);
    this.logger.addWriter(_writer);
    out = TerminalOutput._(this);
    _keys = _KeyDecoder((event) => _prompt?.key(event));
    if (_interactive) {
      _resize = this.backend.resize.listen((_) => _redraw());
    }
  }

  final ChirpLogger logger;

  /// Span-based by default; custom Chirp formatters are also supported.
  final ChirpFormatter formatter;
  final TerminalBackend backend;
  final TerminalMode mode;
  late final TerminalCapabilities capabilities;
  late final TerminalOutput out;

  /// Optional drain for application-owned buffered Chirp writers. Chirp does
  /// not yet define a common writer flush interface.
  final Future<void> Function()? flushLogs;
  late final _TerminalWriter _writer;
  late final _KeyDecoder _keys;
  late final bool _interactive;
  late final bool _canPrompt;
  bool _closed = false;
  bool _inputEnded = false;
  bool _raw = false;
  int _paintedLines = 0;
  int _cursorRow = 0;
  StreamSubscription<String>? _input;
  StreamSubscription<void>? _resize;
  _Prompt<dynamic>? _prompt;
  final List<TerminalProgress> _progress = [];
  Timer? _animation;
  int _frame = 0;
  String _plainPending = '';
  bool _drainingPlain = false;
  bool _outputPartial = false;
  Completer<void>? _promptDone;
  Future<void>? _closing;

  bool get isVerbose => _writer.minLogLevel == ChirpLogLevel.trace;
  set isVerbose(bool value) {
    _writer.setMinLogLevel(value ? ChirpLogLevel.trace : ChirpLogLevel.info);
  }

  void log(
    Object? message, {
    ChirpLogLevel level = ChirpLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
    List<FormatOptions>? formatOptions,
  }) {
    _checkOpen();
    logger.log(message,
        level: level,
        error: error,
        stackTrace: stackTrace,
        data: data,
        formatOptions: formatOptions);
  }

  void info(Object? message,
      {Map<String, Object?>? data, List<FormatOptions>? formatOptions}) {
    log(message, data: data, formatOptions: formatOptions);
  }

  void success(Object? message,
      {Map<String, Object?>? data, List<FormatOptions>? formatOptions}) {
    log(message,
        level: ChirpLogLevel.success, data: data, formatOptions: formatOptions);
  }

  void warning(Object? message,
      {Map<String, Object?>? data, List<FormatOptions>? formatOptions}) {
    log(message,
        level: ChirpLogLevel.warning, data: data, formatOptions: formatOptions);
  }

  void error(Object? message,
      {Object? error,
      StackTrace? stackTrace,
      Map<String, Object?>? data,
      List<FormatOptions>? formatOptions}) {
    log(message,
        level: ChirpLogLevel.error,
        error: error,
        stackTrace: stackTrace,
        data: data,
        formatOptions: formatOptions);
  }

  void debug(Object? message,
      {Map<String, Object?>? data, List<FormatOptions>? formatOptions}) {
    log(message,
        level: ChirpLogLevel.debug, data: data, formatOptions: formatOptions);
  }

  void trace(Object? message,
      {Map<String, Object?>? data, List<FormatOptions>? formatOptions}) {
    log(message,
        level: ChirpLogLevel.trace, data: data, formatOptions: formatOptions);
  }

  /// Logs a verbose message at Chirp's debug level.
  void verbose(Object? message,
      {Map<String, Object?>? data, List<FormatOptions>? formatOptions}) {
    debug(message, data: data, formatOptions: formatOptions);
  }

  void _checkOpen() {
    if (_closed) {
      throw StateError('The terminal session is closed');
    }
  }

  void _printRecord(LogRecord record) {
    final buffer = MessageBuffer.console(capabilities: capabilities);
    formatter.format(record, buffer);
    _printLine(buffer.toString());
  }

  void _printLine(String message) {
    _clear();
    _finishOutputLine();
    backend.writeDiagnostic('$message\n');
    _redraw();
  }

  void _clear() {
    if (_paintedLines == 0) {
      return;
    }
    backend.writeDiagnostic(
        '\r${_cursorRow > 0 ? '\x1b[${_cursorRow}A' : ''}\x1b[J');
    _paintedLines = 0;
    _cursorRow = 0;
  }

  void _redraw() {
    if (!_interactive || _closed) {
      return;
    }
    _clear();
    _finishOutputLine();
    final width = math.max(1, backend.columns - 1);
    final lines = <String>[];
    final limit = math.max(1, backend.rows - 1);
    final progressLimit =
        _prompt == null ? limit : math.max(0, math.min(2, limit - 3));
    for (final progress in _progress.take(progressLimit)) {
      lines.add(progress._line(_frame, width));
    }
    final prompt = _prompt;
    final promptStart = lines.length;
    var promptOffset = 0;
    if (prompt != null) {
      final height = limit - lines.length;
      final promptLines = prompt.lines(height, width);
      final cursorRow = prompt.cursor?.$1;
      if (cursorRow != null && cursorRow >= height) {
        promptOffset = cursorRow - height + 1;
      }
      lines.addAll(promptLines.skip(promptOffset).take(height));
    }
    if (lines.isEmpty) {
      backend.writeDiagnostic('\x1b[?25h');
      return;
    }
    backend.writeDiagnostic('\x1b[?25l');
    for (final line in lines) {
      backend.writeDiagnostic(
          '${_clip(_safeText(line).replaceAll('\n', ' '), width)}\n');
    }
    _paintedLines = lines.length;
    _cursorRow = lines.length;
    final cursor = prompt?.cursor;
    if (cursor != null) {
      final row = promptStart + cursor.$1 - promptOffset;
      backend.writeDiagnostic('\x1b[${lines.length - row}A\r');
      if (cursor.$2 > 0) {
        backend.writeDiagnostic('\x1b[${cursor.$2}C');
      }
      backend.writeDiagnostic('\x1b[?25h');
      _cursorRow = row;
    }
  }

  Future<T> _ask<T>(_Prompt<T> prompt, PromptCancellation? cancellation) async {
    _checkOpen();
    if (!_canPrompt) {
      throw NonInteractivePrompt(prompt.message);
    }
    if (_prompt != null) {
      throw StateError('Only one prompt can read input at a time');
    }
    if ((_inputEnded && _plainPending.isEmpty) ||
        cancellation?.isCancelled == true) {
      throw const PromptCancelled('input ended or cancelled');
    }
    if (!_interactive && prompt.secret) {
      throw StateError(
          'Password input requires interactive mode to disable echo');
    }
    _prompt = prompt;
    _keys.reset();
    final done = Completer<void>();
    _promptDone = done;
    void cancelPrompt() => prompt.cancel();
    StreamSubscription<void>? interrupt;
    try {
      interrupt = backend.interrupt.listen((_) => prompt.cancel('interrupted'));
      if (_interactive) {
        backend.enterRawMode();
        _raw = true;
        backend.writeDiagnostic('\x1b[?2004h');
      }
      _redraw();
      if (!_interactive) {
        backend.writeDiagnostic('${prompt.plainDescription}\n> ');
      }
      prompt.start();
      cancellation?._listeners.add(cancelPrompt);
      if (_input == null) {
        _input = backend.input.transform(utf8.decoder).listen((chunk) {
          if (_interactive) {
            _keys.add(chunk);
          } else {
            _plainPending += chunk;
            unawaited(_drainPlain());
          }
        }, onDone: () {
          _inputEnded = true;
          if (_interactive) {
            _prompt?.cancel('end of input');
          } else {
            unawaited(_drainPlain());
          }
        }, onError: (Object error, StackTrace stack) {
          _prompt?.fail(error, stack);
        });
      } else {
        _input!.resume();
      }
      if (!_interactive) {
        unawaited(_drainPlain());
      }
      final result = await prompt.result.future;
      _clear();
      backend.writeDiagnostic(
          '${_safeText(prompt.message)}: ${_safeText(prompt.summary(result))}\n');
      return result;
    } finally {
      cancellation?._listeners.remove(cancelPrompt);
      prompt.dispose();
      _input?.pause();
      _keys.reset();
      _clear();
      _prompt = null;
      try {
        if (_raw) {
          _raw = false;
          try {
            backend.leaveRawMode();
          } finally {
            backend.writeDiagnostic('\x1b[?2004l\x1b[?25h');
          }
        }
        _redraw();
      } finally {
        await interrupt?.cancel();
        done.complete();
        _promptDone = null;
      }
    }
  }

  void _finishOutputLine() {
    if (_outputPartial) {
      backend.writeDiagnostic('\n');
      _outputPartial = false;
    }
  }

  Future<void> _drainPlain() async {
    if (_drainingPlain) {
      return;
    }
    _drainingPlain = true;
    try {
      while (_prompt != null && !_prompt!.result.isCompleted) {
        final newline = _plainPending.indexOf('\n');
        if (newline < 0 && !_inputEnded) {
          break;
        }
        if (_plainPending.isEmpty) {
          _prompt!.cancel('end of input');
          break;
        }
        final end = newline < 0 ? _plainPending.length : newline;
        final line = _plainPending.substring(0, end).replaceAll('\r', '');
        _plainPending = _plainPending.substring(newline < 0 ? end : end + 1);
        await _prompt!.line(line);
      }
    } finally {
      _drainingPlain = false;
    }
  }

  /// Drains terminal output and the optional application log drain.
  Future<void> flush() async {
    await backend.flush();
    await flushLogs?.call();
  }

  /// Cancels unfinished UI, restores terminal modes, removes only this session's
  /// writer, and flushes. Does not close the supplied logger or its file writers.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _clear();
    _closed = true;
    _animation?.cancel();
    _prompt?.cancel('terminal closed');
    // Let the prompt's finally restore raw mode before cancelling its stream.
    await _promptDone?.future;
    _keys.reset();
    await _input?.cancel();
    await _resize?.cancel();
    for (final progress in List<TerminalProgress>.of(_progress)) {
      progress.cancel();
    }
    logger.removeWriter(_writer);
    if (_interactive) {
      backend.writeDiagnostic('\x1b[?25h');
    }
    await flush();
  }
}

class _TerminalWriter extends ChirpWriter {
  _TerminalWriter(this.terminal);
  final ChirpTerminal terminal;
  @override
  bool get requiresCallerInfo => terminal.formatter.requiresCallerInfo;

  @override
  void write(LogRecord record) {
    if (!terminal._closed) {
      terminal._printRecord(record);
    }
  }
}

/// Exact command output, independent of logging and verbosity.
class TerminalOutput {
  TerminalOutput._(this._terminal);
  final ChirpTerminal _terminal;
  void write(Object? value) {
    _terminal._checkOpen();
    // A shared tty cannot preserve an active region across partial stdout
    // writes. Clear it; it will be drawn again at the next UI update.
    _terminal._clear();
    final text = value?.toString() ?? '';
    _terminal.backend.writeOutput(text);
    if (text.isNotEmpty &&
        _terminal.backend.outputIsTerminal &&
        _terminal.backend.diagnosticIsTerminal) {
      _terminal._outputPartial = !text.endsWith('\n');
    }
  }

  void writeln([Object? value = '']) {
    write('${value ?? ''}\n');
    _terminal._redraw();
  }

  void writeCharCode(int code) => write(String.fromCharCode(code));
}
