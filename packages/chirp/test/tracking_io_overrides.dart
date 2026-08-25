import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Tracks file I/O created through [File] while delegating to the real file
/// system.
final class TrackingIoOverrides extends IOOverrides {
  final Zone _trackingZone = Zone.current;

  int _completedFlushes = 0;
  final List<_FlushWaiter> _flushWaiters = [];
  int _pendingOperations = 0;

  bool get hasPendingOperations => _pendingOperations > 0;

  Future<T> run<T>(Future<T> Function() body) {
    return IOOverrides.runWithIOOverrides(body, this);
  }

  TrackingIoTrap trapFlush() {
    return TrackingIoTrap._(
      overrides: this,
      completedFlushesAtCreation: _completedFlushes,
    );
  }

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return _TrackingFile(file, this);
  }

  Future<T> _trackOperation<T>(
    Future<T> operation, {
    bool isFlush = false,
  }) {
    _pendingOperations++;

    // Register the tracking callback outside FakeAsync's zone. Otherwise the
    // callback that marks the operation complete would itself be held in the
    // fake microtask queue while the test waits for the operation to settle.
    _trackingZone.run(() {
      operation.then<void>(
        (_) => _completeOperation(isFlush: isFlush),
        onError: (Object _, StackTrace __) {
          _completeOperation(isFlush: isFlush);
        },
      );
    });

    return operation;
  }

  void _completeOperation({required bool isFlush}) {
    if (isFlush) {
      _completedFlushes++;
      _completeReadyFlushWaiters();
    }

    _pendingOperations--;
  }

  Future<void> _waitForFlushAfter(int completedFlushes) {
    if (_completedFlushes > completedFlushes) {
      return Future<void>.value();
    }

    final waiter = _FlushWaiter(completedFlushes);
    _flushWaiters.add(waiter);
    return waiter.future;
  }

  void _completeReadyFlushWaiters() {
    final ready = _flushWaiters.where((it) {
      return _completedFlushes > it.completedFlushesAtCreation;
    }).toList();

    _flushWaiters.removeWhere(ready.contains);

    for (final waiter in ready) {
      waiter.complete();
    }
  }
}

final class TrackingIoTrap {
  TrackingIoTrap._({
    required TrackingIoOverrides overrides,
    required int completedFlushesAtCreation,
  })  : _overrides = overrides,
        _completedFlushesAtCreation = completedFlushesAtCreation;

  final TrackingIoOverrides _overrides;
  final int _completedFlushesAtCreation;

  Future<void> wait() {
    return _overrides._waitForFlushAfter(_completedFlushesAtCreation);
  }
}

final class _FlushWaiter {
  _FlushWaiter(this.completedFlushesAtCreation);

  final int completedFlushesAtCreation;
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void complete() {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete();
  }
}

final class _TrackingFile implements File {
  _TrackingFile(this._file, this._overrides);

  final File _file;
  final TrackingIoOverrides _overrides;

  @override
  String get path => _file.path;

  @override
  Directory get parent => _file.parent;

  @override
  Uri get uri => _file.uri;

  @override
  File get absolute => _TrackingFile(_file.absolute, _overrides);

  @override
  bool existsSync() {
    return _file.existsSync();
  }

  @override
  Future<bool> exists() {
    return _overrides._trackOperation(_file.exists());
  }

  @override
  int lengthSync() {
    return _file.lengthSync();
  }

  @override
  Future<int> length() {
    return _overrides._trackOperation(_file.length());
  }

  @override
  RandomAccessFile openSync({
    FileMode mode = FileMode.read,
  }) {
    final file = _file.openSync(mode: mode);
    return _TrackingRandomAccessFile(file, _overrides);
  }

  @override
  Future<RandomAccessFile> open({
    FileMode mode = FileMode.read,
  }) {
    final open = _overrides._trackOperation(_file.open(mode: mode));
    return open.then((file) => _TrackingRandomAccessFile(file, _overrides));
  }

  @override
  String readAsStringSync({
    Encoding encoding = utf8,
  }) {
    return _file.readAsStringSync(encoding: encoding);
  }

  @override
  Future<String> readAsString({
    Encoding encoding = utf8,
  }) {
    return _overrides._trackOperation(
      _file.readAsString(encoding: encoding),
    );
  }

  @override
  Uint8List readAsBytesSync() {
    return _file.readAsBytesSync();
  }

  @override
  Future<Uint8List> readAsBytes() {
    return _overrides._trackOperation(_file.readAsBytes());
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    _file.writeAsStringSync(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    final write = _overrides._trackOperation(
      _file.writeAsString(
        contents,
        mode: mode,
        encoding: encoding,
        flush: flush,
      ),
    );
    return write.then((_) => this);
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    _file.writeAsBytesSync(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    final write = _overrides._trackOperation(
      _file.writeAsBytes(bytes, mode: mode, flush: flush),
    );
    return write.then((_) => this);
  }

  @override
  void deleteSync({
    bool recursive = false,
  }) {
    _file.deleteSync(recursive: recursive);
  }

  @override
  Future<FileSystemEntity> delete({
    bool recursive = false,
  }) {
    return _overrides._trackOperation(
      _file.delete(recursive: recursive),
    );
  }

  @override
  File renameSync(String newPath) {
    final file = _file.renameSync(newPath);
    return _TrackingFile(file, _overrides);
  }

  @override
  Future<File> rename(String newPath) {
    final rename = _overrides._trackOperation(_file.rename(newPath));
    return rename.then((file) => _TrackingFile(file, _overrides));
  }

  @override
  FileStat statSync() {
    return _file.statSync();
  }

  @override
  Future<FileStat> stat() {
    return _overrides._trackOperation(_file.stat());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

final class _TrackingRandomAccessFile implements RandomAccessFile {
  _TrackingRandomAccessFile(this._file, this._overrides);

  final RandomAccessFile _file;
  final TrackingIoOverrides _overrides;

  @override
  String get path => _file.path;

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) {
    final write = _overrides._trackOperation(
      _file.writeFrom(buffer, start, end),
    );
    return write.then((_) => this);
  }

  @override
  void writeFromSync(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) {
    _file.writeFromSync(buffer, start, end);
  }

  @override
  Future<RandomAccessFile> flush() {
    final flush = _overrides._trackOperation(
      _file.flush(),
      isFlush: true,
    );
    return flush.then((_) => this);
  }

  @override
  void flushSync() {
    _file.flushSync();
  }

  @override
  Future<void> close() {
    return _overrides._trackOperation(_file.close());
  }

  @override
  void closeSync() {
    _file.closeSync();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
