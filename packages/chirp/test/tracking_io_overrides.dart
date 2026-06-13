import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Tracks file I/O created through [File] while delegating to the real file
/// system.
final class TrackingIoOverrides extends IOOverrides {
  int _completedFlushes = 0;
  final List<_FlushWaiter> _flushWaiters = [];

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

  void _trackFlush(Future<RandomAccessFile> flush) {
    flush.whenComplete(() {
      _completedFlushes++;
      _completeReadyFlushWaiters();
    });
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

  Future<void> wait({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _overrides
        ._waitForFlushAfter(_completedFlushesAtCreation)
        .timeout(timeout);
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
    return _file.exists();
  }

  @override
  int lengthSync() {
    return _file.lengthSync();
  }

  @override
  Future<int> length() {
    return _file.length();
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
  }) async {
    final file = await _file.open(mode: mode);
    return _TrackingRandomAccessFile(file, _overrides);
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
    return _file.readAsString(encoding: encoding);
  }

  @override
  Uint8List readAsBytesSync() {
    return _file.readAsBytesSync();
  }

  @override
  Future<Uint8List> readAsBytes() {
    return _file.readAsBytes();
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
  }) async {
    await _file.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
    return this;
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
  }) async {
    await _file.writeAsBytes(bytes, mode: mode, flush: flush);
    return this;
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
    return _file.delete(recursive: recursive);
  }

  @override
  File renameSync(String newPath) {
    final file = _file.renameSync(newPath);
    return _TrackingFile(file, _overrides);
  }

  @override
  Future<File> rename(String newPath) async {
    final file = await _file.rename(newPath);
    return _TrackingFile(file, _overrides);
  }

  @override
  FileStat statSync() {
    return _file.statSync();
  }

  @override
  Future<FileStat> stat() {
    return _file.stat();
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
  ]) async {
    await _file.writeFrom(buffer, start, end);
    return this;
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
    final flush = _file.flush().then((_) {
      return this;
    });
    _overrides._trackFlush(flush);
    return flush;
  }

  @override
  void flushSync() {
    _file.flushSync();
  }

  @override
  Future<void> close() {
    return _file.close();
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
