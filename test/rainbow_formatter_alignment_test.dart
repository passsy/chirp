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

  group('RainbowMessageFormatter anonymous closure cleaning', () {
    test('removes anonymous closure from instance method', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      DeviceManager._startAutoConnectScanning.<anonymous closure>.<anonymous closure> (package:app/device_manager.dart:809:5)',
        ),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      // Should show cleaned method name without anonymous closures
      expect(cleanResult, contains('_startAutoConnectScanning'));
      expect(cleanResult, isNot(contains('.<anonymous closure>')));
    });

    test('removes anonymous closure from static method', () {
      final formatter = RainbowMessageFormatter();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        caller: StackTrace.fromString(
          '#0      UserService.logStatic.<anonymous closure> (package:app/user_service.dart:100:5)',
        ),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      expect(cleanResult, contains('logStatic'));
      expect(cleanResult, isNot(contains('.<anonymous closure>')));
    });

    test('removes anonymous closure from top-level function', () {
      final formatter = RainbowMessageFormatter();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        caller: StackTrace.fromString(
          '#0      processData.<anonymous closure>.<anonymous closure> (package:app/utils.dart:42:5)',
        ),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      expect(cleanResult, contains('processData'));
      expect(cleanResult, isNot(contains('.<anonymous closure>')));
    });

    test('removes multiple nested anonymous closures', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      MyClass.myMethod.<anonymous closure>.<anonymous closure>.<anonymous closure> (package:app/my_class.dart:50:5)',
        ),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      expect(cleanResult, contains('myMethod'));
      expect(cleanResult, isNot(contains('.<anonymous closure>')));
    });

    test('preserves method name when no anonymous closure present', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      MyClass.normalMethod (package:app/my_class.dart:50:5)',
        ),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      expect(cleanResult, contains('normalMethod'));
    });

    test('handles instance method with matching class name and anonymous closures', () {
      final formatter = RainbowMessageFormatter();
      final instance = _TestClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        caller: StackTrace.fromString(
          '#0      _TestClass.processData.<anonymous closure> (package:app/test_class.dart:100:5)',
        ),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      // Should show cleaned method name
      expect(cleanResult, contains('processData'));
      expect(cleanResult, isNot(contains('.<anonymous closure>')));
      // Should show class with hash
      expect(cleanResult, contains('_TestClass@'));
    });
  });

  group('RainbowMessageFormatter color option', () {
    test('includes ANSI color codes when color is true (default)', () {
      final formatter = RainbowMessageFormatter();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);

      // Should contain ANSI escape codes
      expect(result, contains(RegExp(r'\x1B\[')));
    });

    test('excludes ANSI color codes when color is false', () {
      final formatter = RainbowMessageFormatter(color: false);
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);

      // Should not contain ANSI escape codes
      expect(result, isNot(contains(RegExp(r'\x1B\['))));
      // But should still contain the actual content
      expect(result, contains('Test message'));
      expect(result, contains('│'));
    });

    test('color:false produces plain text output', () {
      final formatter = RainbowMessageFormatter(color: false);
      final instance = _TestClass();
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        instance: instance,
        loggerName: 'TestLogger',
      );

      final result = formatter.format(entry);

      // Result should be the same as stripped version (no ANSI codes)
      expect(result, _stripAnsiCodes(result));
      // And should still have all the content
      expect(result, contains('Test message'));
      expect(result, contains('_TestClass@'));
      expect(result, contains('TestLogger'));
    });
  });
}

class _TestClass {}

/// Finds the position of │ character in a line, stripping ANSI codes first
int _findPipePosition(String line) {
  // Remove ANSI color codes
  final cleanLine = _stripAnsiCodes(line);
  return cleanLine.indexOf('│');
}

/// Strips ANSI color codes from a string
String _stripAnsiCodes(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKH]'), '');
}
