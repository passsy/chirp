import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/message_formatter.dart';

/// Writes log entries to output
abstract class ChirpMessageWriter {
  void write(LogRecord entry);
}

/// Writes to console using print()
class ConsoleChirpMessageWriter implements ChirpMessageWriter {
  final ChirpMessageFormatter formatter;
  final void Function(String) output;

  ConsoleChirpMessageWriter({
    ChirpMessageFormatter? formatter,
    void Function(String)? output,
  })  : formatter = formatter ?? RainbowMessageFormatter(),
        output = output ?? print;

  @override
  void write(LogRecord entry) {
    final formatted = formatter.format(entry);
    output(formatted);
  }
}

/// Buffers log entries in memory
class BufferedChirpMessageWriter implements ChirpMessageWriter {
  final List<LogRecord> buffer = [];

  @override
  void write(LogRecord entry) => buffer.add(entry);

  void flush(ChirpMessageWriter target) {
    for (final entry in buffer) {
      target.write(entry);
    }
    buffer.clear();
  }
}

/// Forwards to multiple writers
class MultiChirpMessageWriter implements ChirpMessageWriter {
  final List<ChirpMessageWriter> writers;

  MultiChirpMessageWriter(this.writers);

  @override
  void write(LogRecord entry) {
    for (final writer in writers) {
      writer.write(entry);
    }
  }
}
