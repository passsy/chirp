import 'dart:convert';

import 'package:chirp/src/writers/rotating_file_writer/log_file_reader_stub.dart'
    if (dart.library.io) 'package:chirp/src/writers/rotating_file_writer/log_file_reader_io.dart'
    as platform;

/// Reader API for log files created by [RotatingFileWriter].
abstract class RotatingFileReader {
  factory RotatingFileReader({required String baseFilePath}) {
    return platform.createRotatingFileReader(baseFilePath: baseFilePath);
  }

  /// Base path of the current log file, e.g. `/var/log/app.log`.
  String get baseFilePath;

  /// Lists log files (rotated + optionally current) sorted oldest → newest.
  Future<List<String>> listFiles({bool includeCurrent = true});

  /// Reads logs as a finite stream.
  ///
  /// Use [lastLines] to only return the last N lines across all included files.
  Stream<String> read({
    int? lastLines,
    Encoding encoding = utf8,
  });

  /// Tails logs (optionally with an initial snapshot).
  ///
  /// If [lastLines] is provided, it first emits the last N lines (same semantics
  /// as [read]) and then continues streaming newly appended lines.
  Stream<String> tail({
    int? lastLines,
    Encoding encoding = utf8,
  });
}
