import 'dart:async';

import 'package:fake_async/fake_async.dart';

/// Pending drain completers, managed by [fakeAsyncWithDrain].
List<Completer<void>>? _drainCompleters;

/// Runs [callback] inside fakeAsync with support for real I/O draining.
///
/// Inside the callback, call `await drainEvent()` after triggering async
/// file I/O (e.g. via `async.elapse()` that fires a buffered flush timer)
/// to let the real event loop deliver I/O completion callbacks. The outer
/// loop then flushes fakeAsync microtasks so guards like `_pendingFlush`
/// are cleared before the next batch.
///
/// Modelled after Flutter's `runAsync` pattern from
/// `AutomatedTestWidgetsFlutterBinding`.
Future<void> fakeAsyncWithDrain(
  Future<void> Function(FakeAsync async) callback,
) async {
  final fake = FakeAsync();
  var done = false;
  Object? caughtError;
  StackTrace? caughtStack;
  final completers = <Completer<void>>[];
  _drainCompleters = completers;

  fake.run((_) {
    callback(fake).then((_) {
      done = true;
    }, onError: (Object e, StackTrace s) {
      caughtError = e;
      caughtStack = s;
      done = true;
    });
  });

  while (!done) {
    // Settle pending I/O: yield to the real event loop so that
    // RawReceivePort callbacks (from writeFrom / flush / close) are
    // delivered, then flush fake-zone microtasks to run continuations.
    // Multiple rounds handle chained I/O (writeFrom completes → code
    // continues → file.flush starts → file.flush completes → …).
    await fake.settleIo();
    // Complete pending drainEvent() calls.
    while (completers.isNotEmpty) {
      completers.removeAt(0).complete();
    }
    // Process test continuations and settle any new I/O they start.
    fake.run((_) => fake.flushMicrotasks());
    await fake.settleIo();
  }

  _drainCompleters = null;

  if (caughtError != null) {
    Error.throwWithStackTrace(caughtError!, caughtStack!);
  }
}

/// Yields control from a [fakeAsyncWithDrain] callback to let the real
/// event loop process pending I/O completion callbacks.
///
/// Returns a [Future] that completes when the [fakeAsyncWithDrain] outer
/// loop has drained real events and flushed fake microtasks. This ensures
/// async I/O guards like `_pendingFlush` are cleared between batches.
Future<void> drainEvent() {
  final completers = _drainCompleters;
  assert(completers != null,
      'drainEvent() must be called inside fakeAsyncWithDrain');
  final completer = Completer<void>();
  completers!.add(completer);
  return completer.future;
}

extension on FakeAsync {
  /// Yields to the real event loop multiple times and flushes fake-zone
  /// microtasks after each yield. This lets chained async I/O operations
  /// complete (e.g. writeFrom → flush → close, where each completion
  /// triggers the next operation).
  Future<void> settleIo() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      run((_) => flushMicrotasks());
    }
  }
}
