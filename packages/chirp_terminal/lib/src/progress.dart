part of '../chirp_terminal.dart';

/// Presentation is independent of the underlying progress lifecycle.
enum ProgressAppearance { spinner, bar, counter, percentage, staticText }

enum SpinnerAppearance { dots, line, bounce }

extension TerminalProgressApi on ChirpTerminal {
  /// Starts progress. A total is required for bar and percentage appearances.
  /// Multiple handles share the session and are rendered as a task list.
  TerminalProgress progress(
    String message, {
    int? total,
    ProgressAppearance appearance = ProgressAppearance.spinner,
    SpinnerAppearance spinner = SpinnerAppearance.dots,
    Map<String, Object?>? data,
  }) {
    _checkOpen();
    if (total != null && total < 0) {
      throw ArgumentError.value(total, 'total', 'must not be negative');
    }
    if (total == null &&
        (appearance == ProgressAppearance.bar ||
            appearance == ProgressAppearance.percentage)) {
      throw ArgumentError('A total is required for $appearance');
    }
    final progress =
        TerminalProgress._(this, message, total, appearance, spinner, data);
    // Record lifecycle events once; the terminal itself renders its live UI.
    _lifecycle(progress, 'started', message, ChirpLogLevel.info);
    _progress.add(progress);
    if (!_interactive) {
      backend.writeDiagnostic('${_safeText(message)}...\n');
    } else {
      _syncAnimation();
      _redraw();
    }
    return progress;
  }

  void _syncAnimation() {
    if (_closed ||
        !_progress.any((p) => p.appearance != ProgressAppearance.staticText)) {
      _animation?.cancel();
      _animation = null;
      return;
    }
    if (_interactive) {
      _animation ??= Timer.periodic(const Duration(milliseconds: 80), (_) {
        _frame++;
        _redraw();
      });
    }
  }

  void _lifecycle(TerminalProgress progress, String state, String message,
      ChirpLogLevel level,
      {Object? error, StackTrace? stackTrace}) {
    // Suppress only this writer during this synchronous event. Other writers
    // still receive a normal record, including context and interceptors.
    final interceptor = DelegatedChirpInterceptor((_) => null);
    _writer.addInterceptor(interceptor);
    try {
      logger.log(message,
          level: level,
          error: error,
          stackTrace: stackTrace,
          data: {
            ...?progress.data,
            'progress': state,
            'completed': progress.completed,
            if (progress.total != null) 'total': progress.total,
            'durationMs': progress.elapsed.inMilliseconds,
          });
    } finally {
      _writer.removeInterceptor(interceptor);
    }
  }
}

/// A progress handle. Finishing, failing, and cancelling are idempotent.
class TerminalProgress {
  TerminalProgress._(this._terminal, this.message, this.total, this.appearance,
      this.spinner, this.data);
  final ChirpTerminal _terminal;
  String message;
  final int? total;
  final ProgressAppearance appearance;
  final SpinnerAppearance spinner;
  final Map<String, Object?>? data;
  final Stopwatch _watch = Stopwatch()..start();
  int _completed = 0;
  bool _done = false;

  int get completed => _completed;
  bool get isDone => _done;
  Duration get elapsed => _watch.elapsed;

  void advance([int amount = 1]) => update(_completed + amount);

  void update(int completed, {String? message}) {
    if (_done) {
      throw StateError('Progress is already complete');
    }
    if (completed < 0 || (total != null && completed > total!)) {
      throw RangeError.range(completed, 0, total, 'completed');
    }
    _completed = completed;
    if (message != null) {
      this.message = message;
    }
    _terminal._redraw();
  }

  void finish([String? message]) {
    _end('completed', message, ChirpLogLevel.success);
  }

  void cancel([String? message]) {
    _end('cancelled', message, ChirpLogLevel.notice);
  }

  void fail(String message, {Object? error, StackTrace? stackTrace}) {
    _end('failed', message, ChirpLogLevel.error,
        error: error, stackTrace: stackTrace);
  }

  void _end(String state, String? message, ChirpLogLevel level,
      {Object? error, StackTrace? stackTrace}) {
    if (_done) {
      return;
    }
    _done = true;
    _watch.stop();
    if (state == 'completed' && total != null) {
      _completed = total!;
    }
    _terminal._clear();
    _terminal._progress.remove(this);
    _terminal._syncAnimation();
    final label = message ?? this.message;
    _terminal._lifecycle(this, state, label, level,
        error: error, stackTrace: stackTrace);
    _terminal.backend.writeDiagnostic(
        '${_safeText(label)} [$state, ${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s]\n');
    if (error != null) {
      _terminal.backend.writeDiagnostic('${_safeText(error)}\n');
    }
    _terminal._redraw();
  }

  String _line(int frame, int width) {
    final percentage = total == null
        ? 0
        : total == 0
            ? 100
            : (completed * 100 / total!).floor();
    final count = '$completed${total == null ? '' : '/$total'}';
    final elapsedSeconds = elapsed.inMilliseconds / 1000;
    final timing = '${elapsedSeconds.toStringAsFixed(1)}s';
    final eta = total != null && completed > 0
        ? ' ETA ${(elapsedSeconds * (total! - completed) / completed).toStringAsFixed(1)}s'
        : '';
    switch (appearance) {
      case ProgressAppearance.spinner:
        final frames = switch (spinner) {
          SpinnerAppearance.dots => [
              '⠋',
              '⠙',
              '⠹',
              '⠸',
              '⠼',
              '⠴',
              '⠦',
              '⠧',
              '⠇',
              '⠏'
            ],
          SpinnerAppearance.line => ['|', '/', '-', '\\'],
          SpinnerAppearance.bounce => ['.  ', ' . ', '  .', ' . '],
        };
        return '${frames[frame % frames.length]} $message ($timing)';
      case ProgressAppearance.bar:
        final barWidth = math.max(1, math.min(20, width ~/ 4));
        final filled = percentage * barWidth ~/ 100;
        return '[${'=' * filled}${' ' * (barWidth - filled)}] $percentage% $message $count$eta';
      case ProgressAppearance.counter:
        return '$count $message ($timing)';
      case ProgressAppearance.percentage:
        return '$percentage% $message$eta';
      case ProgressAppearance.staticText:
        return '$message...';
    }
  }
}
