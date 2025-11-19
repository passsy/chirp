import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:chirp/chirp.dart';
import 'package:chirp/src/xterm_colors.g.dart';

/// Writes to console using print()
class ConsoleAppender implements ChirpAppender {
  final ConsoleMessageFormatter formatter;
  final void Function(String)? output;

  ConsoleAppender({ConsoleMessageFormatter? formatter, this.output})
      : formatter = formatter ?? RainbowMessageFormatter();

  @override
  void write(LogRecord record) {
    bool supportColors = true;
    if (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME')) {
      // colors are not supported on the iOS Simulator
      // https://github.com/flutter/flutter/issues/20663
      supportColors = false;
    }

    final builder = ConsoleMessageBuilder(useColors: supportColors);
    formatter.format(record, builder);
    final text = builder.build();

    if (output != null) {
      output!(text);
    } else {
      // ignore: avoid_print
      print(text);
    }
  }
}

abstract class ConsoleMessageFormatter {
  void format(LogRecord record, ConsoleMessageBuilder builder);
}

class ConsoleMessageBuilder {
  final bool useColors;

  ConsoleMessageBuilder({
    this.useColors = false,
  });

  final StringBuffer _buffer = StringBuffer();

  void write(Object? value, {XtermColor? foreground, XtermColor? background}) {
    if (useColors && (foreground != null || background != null)) {
      ansiColorDisabled = false;
      final pen = AnsiPen();
      if (foreground != null) {
        pen.rgb(
            r: foreground.r / 255,
            g: foreground.g / 255,
            b: foreground.b / 255);
      }
      if (background != null) {
        pen.rgb(
            r: background.r / 255,
            g: background.g / 255,
            b: background.b / 255,
            bg: true);
      }
      _buffer.write(pen(value ?? 'null'));
    } else {
      _buffer.write(value);
    }
  }

  String build() {
    return _buffer.toString();
  }
}

extension ConsoleMessageBuilderExt on ConsoleMessageBuilder {
  void writeNextLine(Object? text) {
    write('\n');
    write(text);
  }

  void writeWithIndent(Object? text, int spaces) {
    if (spaces > 0) {
      write(''.padLeft(spaces));
    }
    write(text);
  }
}

/// Buffers log records for later processing
class BufferedAppender implements ChirpAppender {
  final List<LogRecord> buffer = [];

  @override
  void write(LogRecord record) {
    buffer.add(record);
  }

  /// Flush buffered records to another appender
  void flush(ChirpAppender target) {
    for (final record in buffer) {
      target.write(record);
    }
    buffer.clear();
  }
}

/// Writes to multiple appenders
class MultiAppender implements ChirpAppender {
  final List<ChirpAppender> appenders;

  MultiAppender(this.appenders);

  @override
  void write(LogRecord record) {
    for (final appender in appenders) {
      appender.write(record);
    }
  }
}
