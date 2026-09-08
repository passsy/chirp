part of '../chirp_terminal.dart';

/// Injectable terminal I/O. Tests can supply a stream of UTF-8 key bytes and
/// capture output without replacing process-global stdin/stdout.
abstract class TerminalBackend {
  Stream<List<int>> get input;
  bool get inputIsTerminal;
  bool get outputIsTerminal;
  bool get diagnosticIsTerminal;
  bool get supportsAnsi;
  int get columns;
  int get rows;
  Map<String, String> get environment;
  Stream<void> get resize => const Stream.empty();
  Stream<void> get interrupt => const Stream.empty();

  void writeOutput(String text);
  void writeDiagnostic(String text);
  void enterRawMode();
  void leaveRawMode();
  Future<void> flush();
}

/// Uses the process terminal. Prompts and diagnostics use stderr; command
/// results use stdout. Cancelling the input subscription on session close
/// closes Dart's stdin descriptor. Stdout and stderr remain open.
class StdioTerminalBackend extends TerminalBackend {
  bool? _lineMode;
  bool? _echoMode;

  @override
  Stream<List<int>> get input => io.stdin;
  @override
  bool get inputIsTerminal => io.stdin.hasTerminal;
  @override
  bool get outputIsTerminal => io.stdout.hasTerminal;
  @override
  bool get diagnosticIsTerminal => io.stderr.hasTerminal;
  @override
  bool get supportsAnsi => io.stderr.supportsAnsiEscapes;
  @override
  Map<String, String> get environment => io.Platform.environment;
  @override
  int get columns => diagnosticIsTerminal ? io.stderr.terminalColumns : 80;
  @override
  int get rows => diagnosticIsTerminal ? io.stderr.terminalLines : 24;
  @override
  Stream<void> get resize {
    return io.Platform.isWindows
        ? const Stream.empty()
        : io.ProcessSignal.sigwinch.watch().map((_) {});
  }

  @override
  Stream<void> get interrupt => io.ProcessSignal.sigint.watch().map((_) {});

  @override
  void writeOutput(String text) => io.stdout.write(text);
  @override
  void writeDiagnostic(String text) => io.stderr.write(text);

  @override
  void enterRawMode() {
    _lineMode = io.stdin.lineMode;
    _echoMode = io.stdin.echoMode;
    try {
      io.stdin.lineMode = false;
      io.stdin.echoMode = false;
    } catch (_) {
      leaveRawMode();
      rethrow;
    }
  }

  @override
  void leaveRawMode() {
    final lineMode = _lineMode;
    final echoMode = _echoMode;
    _lineMode = null;
    _echoMode = null;
    if (lineMode != null) {
      io.stdin.lineMode = lineMode;
    }
    if (echoMode != null) {
      io.stdin.echoMode = echoMode;
    }
  }

  @override
  Future<void> flush() async {
    await io.stdout.flush();
    await io.stderr.flush();
  }
}

/// Automatic mode uses rich prompts on terminals and refuses to ask for input
/// in unattended processes. Plain mode uses line input without screen redraws.
enum TerminalMode { auto, interactive, plain, nonInteractive }

/// Cooperative cancellation for prompts and async search providers.
class PromptCancellation {
  final Completer<void> _cancelled = Completer<void>();
  final Set<void Function()> _listeners = {};
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) {
      _cancelled.complete();
      for (final listener in List<void Function()>.of(_listeners)) {
        listener();
      }
      _listeners.clear();
    }
  }
}

/// Cancellation is distinct from an empty answer, false, or a default value.
class PromptCancelled implements Exception {
  const PromptCancelled([this.reason = 'cancelled']);
  final String reason;
  @override
  String toString() => 'PromptCancelled: $reason';
}

class NonInteractivePrompt implements Exception {
  const NonInteractivePrompt(this.message);
  final String message;
  @override
  String toString() {
    return 'Cannot prompt without an interactive terminal: $message';
  }
}
