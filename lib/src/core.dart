import 'package:chirp/src/log_record.dart';

abstract class ChirpAppender {
  void write(LogRecord record);
}
