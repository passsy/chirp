import 'dart:async';
import 'dart:convert';

import 'package:chirp/src/writers/rotating_file_writer/log_file_reader_stub.dart'
    if (dart.library.io) 'package:chirp/src/writers/rotating_file_writer/log_file_reader_io.dart'
    as impl;

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
}) {
  return impl.readLogs(
    baseFilePath: baseFilePath,
    follow: follow,
    encoding: encoding,
  );
}
