import 'dart:async';

import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader.dart';

RotatingFileReader createRotatingFileReader({
  required FutureOr<String> Function() baseFilePathProvider,
}) {
  throw UnsupportedError(
    'RotatingFileReader is not supported on web. '
    'This platform does not support dart:io.',
  );
}
