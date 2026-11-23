import 'dart:io';

/// Runs actions right before the reader lists the directory at [path], adds
/// entries to what it gets listed and lets it fail to open files.
final class IoHooks extends IOOverrides {
  final String path;

  /// Actions by the number of the listing they run before, starting at 1.
  final beforeListing = <int, void Function()>{};

  /// Entries that only the next listing holds, like files that are deleted
  /// right after they were listed.
  final listedOnce = <FileSystemEntity>[];

  /// Paths of files whose next open fails although they exist.
  final failOpenOnce = <String>{};

  /// Actions by path, run before each open of the file with the number of
  /// the open, starting at 1.
  final beforeOpen = <String, void Function(int open)>{};
  final _opens = <String, int>{};

  /// Makes every listing fail.
  bool failListing = false;

  int _listings = 0;

  IoHooks(this.path);

  @override
  Directory createDirectory(String path) {
    final directory = super.createDirectory(path);
    if (path != this.path) {
      return directory;
    }
    return _HookedDirectory(directory, this);
  }

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    if (!failOpenOnce.contains(path) && !beforeOpen.containsKey(path)) {
      return file;
    }
    return _HookedFile(file, this);
  }
}

class _HookedDirectory implements Directory {
  final Directory _directory;
  final IoHooks _hooks;

  _HookedDirectory(this._directory, this._hooks);

  @override
  String get path => _directory.path;

  @override
  bool existsSync() => _directory.existsSync();

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (_hooks.failListing) {
      throw FileSystemException('Injected failure', path);
    }
    _hooks._listings++;
    _hooks.beforeListing[_hooks._listings]?.call();
    final entities = [
      ..._directory.listSync(recursive: recursive, followLinks: followLinks),
      ..._hooks.listedOnce,
    ];
    _hooks.listedOnce.clear();
    return entities;
  }

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    return _directory.watch(events: events, recursive: recursive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HookedFile implements File {
  final File _file;
  final IoHooks _hooks;

  _HookedFile(this._file, this._hooks);

  @override
  String get path => _file.path;

  @override
  Uri get uri => _file.uri;

  @override
  Directory get parent => _file.parent;

  @override
  FileStat statSync() => _file.statSync();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    final open = (_hooks._opens[path] ?? 0) + 1;
    _hooks._opens[path] = open;
    _hooks.beforeOpen[path]?.call(open);
    if (_hooks.failOpenOnce.remove(path)) {
      throw FileSystemException('Injected failure', path);
    }
    return await _file.open(mode: mode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
