import 'dart:async';
import 'dart:convert';

import 'package:chirp/src/writers/rotating_file_writer/log_file_reader_stub.dart'
    if (dart.library.io) 'package:chirp/src/writers/rotating_file_writer/log_file_reader_io.dart'
    as impl;

/// Reader API for log files created by [RotatingFileWriter].
class RotatingFileReader {
  const RotatingFileReader({required this.baseFilePath});

  /// Base path of the current log file, e.g. `/var/log/app.log`.
  final String baseFilePath;

  /// Lists log files (rotated + optionally current) sorted oldest → newest.
  Future<List<String>> listFiles({bool includeCurrent = true}) {
    return listLogFiles(
      baseFilePath: baseFilePath,
      includeCurrent: includeCurrent,
    );
  }

  /// Reads logs as a finite stream.
  ///
  /// Use [since] to only include files that were modified on/after that date.
  /// Use [lastLines] to only return the last N lines across all included files.
  Stream<String> read({
    DateTime? since,
    int? lastLines,
    Encoding encoding = utf8,
  }) {
    return impl.readLogs(
      baseFilePath: baseFilePath,
      follow: false,
      encoding: encoding,
      since: since,
      lastLines: lastLines,
    );
  }

  /// Tails the current log file.
  ///
  /// If [since] or [lastLines] are provided, it first emits a finite snapshot
  /// (same semantics as [read]) and then continues streaming new appended lines.
  Stream<String> tail({
    DateTime? since,
    int? lastLines,
    Encoding encoding = utf8,
  }) async* {
    // Snapshot.
    if (since != null || lastLines != null) {
      yield* read(
        since: since,
        lastLines: lastLines,
        encoding: encoding,
      );
    }

    // Follow new content.
    yield* impl.readLogs(
      baseFilePath: baseFilePath,
      follow: true,
      encoding: encoding,
    );
  }
}

/// Lists log files for a [RotatingFileWriter] base path.
///
/// Returns absolute file paths sorted from oldest to newest.
///
/// On web platforms this throws [UnsupportedError].
Future<List<String>> listLogFiles({
  required String baseFilePath,
  bool includeCurrent = true,
}) {
  return impl.listLogFiles(
    baseFilePath: baseFilePath,
    includeCurrent: includeCurrent,
  );
}

/// Reads log files for a [RotatingFileWriter] base path.
///
/// Emits decoded text chunks (typically line-based) starting with the oldest
/// rotated log and ending with the current file.
///
/// When [follow] is `true`, it keeps the stream open and emits new content
/// appended to the current log file (similar to `tail -f`).
///
/// On web platforms this throws [UnsupportedError].
Stream<String> readLogs({
  required String baseFilePath,
  bool follow = false,
  Encoding encoding = utf8,
  DateTime? since,
  int? lastLines,
}) {
  return impl.readLogs(
    baseFilePath: baseFilePath,
    follow: follow,
    encoding: encoding,
    since: since,
    lastLines: lastLines,
  );
}
