import 'dart:async';

import 'package:fake_async/fake_async.dart';

import 'tracking_io_overrides.dart';

/// Controls fake time and tracked file I/O inside [fakeAsyncWithDrain].
final class AsyncIoContext {
  AsyncIoContext._(this._fake, this._io);

  final FakeAsync _fake;
  final TrackingIoOverrides _io;
  final List<Completer<void>> _drainCompleters = [];

  /// Advances fake time and fires timers due within [duration].
  void elapse(Duration duration) => _fake.elapse(duration);

  /// Runs all microtasks queued in the fake async zone.
  void flushMicrotasks() => _fake.flushMicrotasks();

  /// Completes after the next tracked file flush finishes.
  TrackingIoTrap trapFlush() => _io.trapFlush();

  /// Completes after tracked file I/O and its fake-zone continuations settle.
  Future<void> drain() {
    final completer = Completer<void>();
    _drainCompleters.add(completer);
    return completer.future;
  }

  void _completeDrainRequests() {
    while (_drainCompleters.isNotEmpty) {
      _drainCompleters.removeAt(0).complete();
    }
  }
}

/// Runs [callback] inside fakeAsync with support for real I/O draining.
///
/// Inside the callback, call `await async.drain()` after triggering async
/// file I/O (e.g. via `async.elapse()` that fires a buffered flush timer)
/// to wait for all tracked file operations to complete. The outer loop then
/// flushes fakeAsync microtasks so guards like `_pendingFlush` are cleared
/// before the next batch.
///
/// Modelled after Flutter's `runAsync` pattern from
/// `AutomatedTestWidgetsFlutterBinding`.
Future<void> fakeAsyncWithDrain(
  Future<void> Function(AsyncIoContext async) callback,
) async {
  final fake = FakeAsync();
  final io = TrackingIoOverrides();
  final async = AsyncIoContext._(fake, io);
  var done = false;
  Object? caughtError;
  StackTrace? caughtStack;

  await io.run(() async {
    fake.run((_) {
      callback(async).then((_) {
        done = true;
      }, onError: (Object e, StackTrace s) {
        caughtError = e;
        caughtStack = s;
        done = true;
      });
    });

    while (!done) {
      // Settle pending I/O, including chains where completing one operation
      // starts another from a fake-zone continuation.
      await fake.settleIo(io);

      async._completeDrainRequests();

      // Process test continuations and any I/O they start.
      fake.run((_) => fake.flushMicrotasks());
    }
  });

  if (caughtError != null) {
    Error.throwWithStackTrace(caughtError!, caughtStack!);
  }
}

extension on FakeAsync {
  /// Waits until tracked file I/O and the fake-zone continuations it schedules
  /// reach quiescence. Fake timers are not advanced.
  Future<void> settleIo(TrackingIoOverrides io) async {
    while (true) {
      run((_) => flushMicrotasks());

      if (!io.hasPendingOperations) {
        return;
      }

      // dart:io futures contain continuations registered in FakeAsync's zone.
      // Give the real event loop a turn for native I/O, then process those
      // continuations above. Keep going until the tracked operation count,
      // rather than an arbitrary number of turns, reaches zero.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
