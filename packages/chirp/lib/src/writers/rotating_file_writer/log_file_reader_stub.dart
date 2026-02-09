import 'dart:async';
import 'dart:convert';

Future<List<String>> listLogFiles({
  required String baseFilePath,
  bool includeCurrent = true,
}) {
  throw UnsupportedError(
    'Log file reading is not supported on web. '
    'This platform does not support dart:io.',
  );
}

Stream<String> readLogs({
  required String baseFilePath,
  bool follow = false,
  Encoding encoding = utf8,
  DateTime? since,
  int? lastLines,
}) {
  throw UnsupportedError(
    'Log file reading is not supported on web. '
    'This platform does not support dart:io.',
  );
}
