import 'dart:async';
import 'dart:convert';

import 'package:chirp/src/core/chirp_formatter.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer.dart';

RotatingFileWriter createRotatingFileWriter({
  required FutureOr<String> Function() baseFilePathProvider,
  ChirpFormatter? formatter,
  FileRotationConfig? rotationConfig,
  Encoding encoding = utf8,
  FileWriterErrorHandler? onError,
  FlushStrategy? flushStrategy,
  Duration flushInterval = const Duration(seconds: 1),
}) {
  throw UnsupportedError(
    'RotatingFileWriter is not supported on web. '
    'Use ConsoleWriter or a custom writer for web platforms.',
  );
}
