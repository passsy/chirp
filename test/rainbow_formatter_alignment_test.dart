// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
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
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      );

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
      final formatter = RainbowMessageFormatter(color: false);
      final entry = LogRecord(
        message: 'Line 1\nLine 2\nLine 3',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {'key': 'value'},
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // First line should have the pipe with first message line
      expect(lines[0], contains('│ Line 1'));

      // Find the pipe position in first line
      final mainPipePos = _findPipePosition(lines[0]);
      expect(mainPipePos, isNot(-1));

      // Second and third lines should have pipes at same position with message content
      expect(lines[1], contains('│ Line 2'));
      expect(lines[2], contains('│ Line 3'));

      final line2PipePos = _findPipePosition(lines[1]);
      final line3PipePos = _findPipePosition(lines[2]);

      expect(line2PipePos, mainPipePos,
          reason:
              'Line 2 pipe at position $line2PipePos should align with main pipe at $mainPipePos');
      expect(line3PipePos, mainPipePos,
          reason:
              'Line 3 pipe at position $line3PipePos should align with main pipe at $mainPipePos');

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

    test('multiline message first line is on same line as metadata', () {
      final formatter = RainbowMessageFormatter(color: false);
      final entry = LogRecord(
        message: 'First line\nSecond line',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // Should have exactly 2 lines (no empty line)
      expect(lines.length, 2);

      // First line should contain metadata and first message line
      expect(lines[0], contains('│ First line'));
      expect(lines[0], contains('10:23:45.123'));

      // Second line should be indented with pipe
      expect(lines[1], contains('│ Second line'));
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

    test(
        'handles instance method with matching class name and anonymous closures',
        () {
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

  group('RainbowMessageFormatter format options', () {
    test('writes data on separate lines with multiline option', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(data: DataPresentation.multiline),
      );
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'action': 'login',
        },
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);
      final lines = cleanResult.split('\n');

      // Should have multiple lines
      expect(lines.length, greaterThan(1));
      // Each data property should be on its own line
      expect(cleanResult, contains('│ userId=user_123'));
      expect(cleanResult, contains('│ action=login'));
    });

    test('writes data inline when formatOptions contains dataInline', () {
      final formatter = RainbowMessageFormatter(
          options: const RainbowFormatOptions(data: DataPresentation.inline));
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'action': 'login',
        },
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      // Should be single line
      expect(cleanResult.split('\n').length, 1);
      // Data should be in parentheses and comma-separated
      expect(cleanResult, contains('(userId=user_123, action=login)'));
      // Or reversed order (map order is not guaranteed)
      // So check that both keys are present in inline format
      expect(cleanResult, contains('userId=user_123'));
      expect(cleanResult, contains('action=login'));
      expect(cleanResult, contains('('));
      expect(cleanResult, contains(')'));
    });

    test('inline data appears on same line as message', () {
      final formatter = RainbowMessageFormatter(
          options: const RainbowFormatOptions(data: DataPresentation.inline));
      final entry = LogRecord(
        message: 'User action',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
        },
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      // Everything should be on one line
      expect(cleanResult.contains('\n'), false);
      expect(cleanResult, contains('User action (userId=user_123)'));
    });

    test('inline data works with multiple properties', () {
      final formatter = RainbowMessageFormatter(
          options: const RainbowFormatOptions(data: DataPresentation.inline));
      final entry = LogRecord(
        message: 'Request',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'method': 'POST',
          'endpoint': '/api/users',
          'status': 200,
        },
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      // Single line with all data
      expect(cleanResult.split('\n').length, 1);
      expect(cleanResult, contains('method=POST'));
      expect(cleanResult, contains('endpoint=/api/users'));
      expect(cleanResult, contains('status=200'));
      // Check comma-separated format
      expect(cleanResult, matches(RegExp(r'\([^)]+, [^)]+, [^)]+\)')));
    });

    test('inline data with no data produces no inline annotation', () {
      final formatter = RainbowMessageFormatter(
          options: const RainbowFormatOptions(data: DataPresentation.inline));
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);
      final cleanResult = _stripAnsiCodes(result);

      // No parentheses when no data
      expect(cleanResult, isNot(contains('(')));
      expect(cleanResult, isNot(contains(')')));
      expect(cleanResult, contains('Test message'));
    });
  });

  group('RainbowMessageFormatter exception formatting', () {
    test('exceptions are indented with 2 spaces', () {
      final formatter = RainbowMessageFormatter(color: false);
      final entry = LogRecord(
        message: 'Operation failed',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Something went wrong'),
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // First line is the main message
      expect(lines[0], contains('Operation failed'));
      // Exception line should be indented with 2 spaces
      expect(lines[1], startsWith('  '));
      expect(lines[1], contains('Exception: Something went wrong'));
    });

    test('stack traces are indented with 2 spaces', () {
      final formatter = RainbowMessageFormatter(color: false);
      final entry = LogRecord(
        message: 'Error occurred',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Test error'),
        stackTrace: StackTrace.fromString(
            '#0      main (file.dart:10:5)\n#1      test (file.dart:20:3)'),
      );

      final result = formatter.format(entry);
      final lines = result.split('\n');

      // Exception and stack trace lines should be indented
      expect(
          lines.where((line) => line.startsWith('  #')).length, greaterThan(0));
      // Check specific stack frames are indented
      expect(result, contains('  #0      main'));
      expect(result, contains('  #1      test'));
    });
  });

  group('plain layout', () {
    test('plain layout outputs metadata line then message at left margin', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(layout: LayoutStyle.plain),
      );
      final entry = LogRecord(
        message: 'Simple message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);

      // Should have metadata line with timestamp
      expect(result, contains('10:23:45'));
      // Should have pipe in metadata line
      expect(result, contains('│'));
      // Message should be on next line at left margin
      final lines = result.split('\n');
      expect(lines.length, 2);
      expect(lines[1], 'Simple message');
    });

    test('plain layout with data outputs message and data at left margin', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(layout: LayoutStyle.plain),
      );
      final entry = LogRecord(
        message: 'User action',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'userId': 'user_123',
          'action': 'login',
        },
      );

      final result = formatter.format(entry);

      expect(result, contains('User action'));
      expect(result, contains('userId=user_123'));
      expect(result, contains('action=login'));
      // Should have metadata line
      expect(result, contains('10:23:45'));
      expect(result, contains('│'));

      // Message and data should be on subsequent lines at left margin
      final lines = result.split('\n');
      expect(lines[1], 'User action');
      expect(lines[2], 'userId=user_123');
      expect(lines[3], 'action=login');
    });

    test('plain layout with multiline message', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(layout: LayoutStyle.plain),
      );
      final entry = LogRecord(
        message: 'Line 1\nLine 2\nLine 3',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);

      // Should have metadata line
      expect(result, contains('10:23:45'));
      expect(result, contains('│'));

      // Message lines should follow at left margin
      final lines = result.split('\n');
      expect(lines[1], 'Line 1');
      expect(lines[2], 'Line 2');
      expect(lines[3], 'Line 3');
    });

    test('plain layout with error and stacktrace', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(layout: LayoutStyle.plain),
      );
      final entry = LogRecord(
        message: 'Error occurred',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        error: Exception('Test error'),
        stackTrace: StackTrace.fromString('#0      main\n#1      test'),
      );

      final result = formatter.format(entry);

      expect(result, contains('Error occurred'));
      expect(result, contains('Exception: Test error'));
      expect(result, contains('#0      main'));
      expect(result, contains('#1      test'));
      // Should have metadata
      expect(result, contains('10:23:45'));
    });

    test('plain layout with only data, no message', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(layout: LayoutStyle.plain),
      );
      final entry = LogRecord(
        message: '',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {
          'key1': 'value1',
          'key2': 'value2',
        },
      );

      final result = formatter.format(entry);

      expect(result, contains('key1=value1'));
      expect(result, contains('key2=value2'));

      // Should have metadata line first, then data at left margin
      // When message is empty, data starts right after metadata
      final lines = result.split('\n');
      expect(lines[1], 'key1=value1');
      expect(lines[2], 'key2=value2');
    });

    test('per-message plain layout overrides aligned formatter', () {
      final formatter = RainbowMessageFormatter(
        color: false,
        options: const RainbowFormatOptions(),
      );
      final entry = LogRecord(
        message: 'Test message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        data: {'key': 'value'},
        formatOptions: const [
          RainbowFormatOptions(layout: LayoutStyle.plain),
        ],
      );

      final result = formatter.format(entry);

      // Should use plain layout with metadata line
      expect(result, contains('Test message'));
      expect(result, contains('key=value'));
      expect(result, contains('10:23:45'));
      expect(result, contains('│'));

      // Message and data should be at left margin
      final lines = result.split('\n');
      expect(lines[1], 'Test message');
      expect(lines[2], 'key=value');
    });

    test('plain layout has colored metadata and grey message content', () {
      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(layout: LayoutStyle.plain),
      );
      final entry = LogRecord(
        message: 'Colored message',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final result = formatter.format(entry);

      // Should have ANSI codes for metadata line
      expect(result, contains('\x1B['));

      // Message line should also have color codes (grey for info level)
      final lines = result.split('\n');
      expect(lines[1], contains('\x1B[')); // Has color codes
      expect(lines[1], contains('Colored message'));
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
