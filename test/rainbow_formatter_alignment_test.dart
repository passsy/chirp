import 'package:chirp/src/log_entry.dart';
import 'package:chirp/src/rainbow_message_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('RainbowMessageFormatter alignment', () {
    test('data lines align pipe │ with main line pipe', () {
      final formatter = RainbowMessageFormatter();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'endpoint': '/api/profile',
        },
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // Find the position of │ in the first line (main line)
      final mainLine = lines[0];
      final mainPipePos = _findPipePosition(mainLine);

      expect(mainPipePos, isNot(-1), reason: 'Main line should contain │');

      // Check all data lines have │ at the same position
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].contains('│')) {
          final dataPipePos = _findPipePosition(lines[i]);
          expect(
            dataPipePos,
            mainPipePos,
            reason:
                'Data line $i pipe at position $dataPipePos should match main line pipe at position $mainPipePos\n'
                'Main line: "$mainLine"\n'
                'Data line: "${lines[i]}"',
          );
        }
      }
    });

    test('pipe alignment with different label lengths', () {
      final formatter = RainbowMessageFormatter();

      // Test with short label
      final shortEntry = LogRecord(
        message: 'Short',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'API',
        data: {'key': 'value'},
      );

      final shortResult = formatter.format(shortEntry);
      final shortLines = shortResult.split('\n');
      final shortMainPipe = _findPipePosition(shortLines[0]);
      final shortDataPipe = _findPipePosition(shortLines[1]);

      expect(shortDataPipe, shortMainPipe,
          reason: 'Short label: pipes should align');

      // Test with long label
      final longEntry = LogRecord(
        message: 'Long',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'VeryLongLoggerNameThatTakesMoreSpace',
        data: {'key': 'value'},
      );

      final longResult = formatter.format(longEntry);
      final longLines = longResult.split('\n');
      final longMainPipe = _findPipePosition(longLines[0]);
      final longDataPipe = _findPipePosition(longLines[1]);

      expect(longDataPipe, longMainPipe,
          reason: 'Long label: pipes should align');
    });

    test('pipe alignment with multiline message', () {
      final formatter = RainbowMessageFormatter();
      final entry = LogRecord(
        message: 'Line 1\nLine 2\nLine 3',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {'key': 'value'},
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // First line should have the pipe
      final mainPipePos = _findPipePosition(lines[0]);
      expect(mainPipePos, isNot(-1));

      // Find data lines (they contain '=')
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('=') && lines[i].contains('│')) {
          final dataPipePos = _findPipePosition(lines[i]);
          expect(
            dataPipePos,
            mainPipePos,
            reason: 'Multiline: data line $i pipe should align with main pipe',
          );
        }
      }
    });

    test('pipe alignment when label is very long (exceeds metaWidth)', () {
      final formatter = RainbowMessageFormatter();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        loggerName: 'VeryLongLoggerNameThatExceedsTheDefaultMetaWidth',
        caller: StackTrace.fromString(
          '#0      longMethodName (package:app/file.dart:100:5)',
        ),
        data: {'key': 'value'},
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // Find the main line with the message
      final mainLine = lines[0];
      final mainPipePos = _findPipePosition(mainLine);

      expect(mainPipePos, isNot(-1),
          reason: 'Main line should contain │: "$mainLine"');

      // Find data line
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].contains('=') && lines[i].contains('│')) {
          final dataPipePos = _findPipePosition(lines[i]);
          expect(
            dataPipePos,
            mainPipePos,
            reason:
                'Long label: data line $i pipe at $dataPipePos should align with main pipe at $mainPipePos\n'
                'Main line: "$mainLine"\n'
                'Data line: "${lines[i]}"',
          );
        }
      }
    });
  });
}

/// Finds the position of │ character in a line, stripping ANSI codes first
int _findPipePosition(String line) {
  // Remove ANSI color codes
  final cleanLine = line.replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKH]'), '');
  return cleanLine.indexOf('│');
}
