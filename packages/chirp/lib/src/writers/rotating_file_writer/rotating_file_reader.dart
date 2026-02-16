import 'dart:async';
import 'dart:convert';

import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader_stub.dart'
    if (dart.library.io) 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader_io.dart'
    as platform;

/// Reader API for log files created by [RotatingFileWriter].
///
/// The [baseFilePathProvider] must return the same path used by the writer.
///
/// For **persistent logs** (iOS: `Library/Application Support/`,
/// Android: `Context.getFilesDir()`):
///
/// ```dart
/// final reader = RotatingFileReader(
///   baseFilePathProvider: () async {
///     final dir = await getApplicationSupportDirectory();
///     return '${dir.path}/logs/app.log';
///   },
/// );
/// final lines = await reader.read(last: 100).toList();
/// ```
///
/// For **temporary logs** (iOS: `Library/Caches/`,
/// Android: `Context.getCacheDir()`):
///
/// ```dart
/// final reader = RotatingFileReader(
///   baseFilePathProvider: () async {
///     final dir = await getApplicationCacheDirectory();
///     return '${dir.path}/logs/app.log';
///   },
/// );
/// ```
abstract class RotatingFileReader {
  /// Creates a reader for log files written by [RotatingFileWriter].
  ///
  /// The [baseFilePathProvider] must return the same path used by the writer
  /// so the reader can locate all rotated files.
  factory RotatingFileReader({
    required FutureOr<String> Function() baseFilePathProvider,
    Duration? pollInterval,
    String recordSeparator = '\n',
  }) {
    return platform.createRotatingFileReader(
      baseFilePathProvider: baseFilePathProvider,
      pollInterval: pollInterval,
      recordSeparator: recordSeparator,
    );
  }

  /// For example: `/var/log/app.log`.
  String get baseFilePath;

  /// Returns absolute paths of log files sorted oldest → newest.
  ///
  /// Set [includeCurrent] to `false` to exclude the active log file
  /// that is still being written to.
  Future<List<String>> listFiles({bool includeCurrent = true});

  /// Reads all log records from rotated and current files, oldest to newest.
  ///
  /// Returns a finite stream that completes once all files are read.
  /// Set [last] to only return the last N records across all files.
  Stream<String> read({
    int? last,
    Encoding encoding = utf8,
  });

  /// Tails logs (optionally with an initial snapshot).
  ///
  /// If [last] is provided, it first emits the last N records (same semantics
  /// as [read]) and then continues streaming newly appended records.
  ///
  /// The [pollInterval] passed to the factory controls how often the reader
  /// checks for changes when file system events are missing or unreliable.
  Stream<String> tail({
    int? last,
    Encoding encoding = utf8,
  });
}
