import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('DelegatedConsoleMessageFormatter', () {
    test('can be created with a function', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {});
      expect(formatter, isA<ConsoleMessageFormatter>());
    });

    test('format delegates to the provided function', () {
      var called = false;
      LogRecord? receivedRecord;
      ConsoleMessageBuffer? receivedBuffer;

      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        called = true;
        receivedRecord = record;
        receivedBuffer = buffer;
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      expect(called, isTrue);
      expect(receivedRecord, same(record));
      expect(receivedBuffer, same(buffer));
    });

    test('can write simple formatted output', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write('[${record.level.name.toUpperCase()}] ${record.message}');
      });

      final record = LogRecord(
        message: 'Test message',
        timestamp: DateTime.now(),
        level: ChirpLogLevel.warning,
      );
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      expect(buffer.toString(), '[WARNING] Test message');
    });

    test('can format with timestamp', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        final time = record.timestamp;
        final timeStr =
            '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}:'
            '${time.second.toString().padLeft(2, '0')}';
        buffer.write('$timeStr ${record.message}');
      });

      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime(2024, 1, 15, 10, 30, 45),
      );
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      expect(buffer.toString(), '10:30:45 Test');
    });

    test('can format with structured data', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write(record.message.toString());
        if (record.data.isNotEmpty) {
          buffer.write(' | ');
          buffer.write(
            record.data.entries.map((e) => '${e.key}=${e.value}').join(', '),
          );
        }
      });

      final record = LogRecord(
        message: 'Request',
        timestamp: DateTime.now(),
        data: {'method': 'GET', 'path': '/api'},
      );
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      expect(buffer.toString(), 'Request | method=GET, path=/api');
    });

    test('requiresCallerInfo defaults to false', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {});
      expect(formatter.requiresCallerInfo, isFalse);
    });

    test('requiresCallerInfo can be set to true', () {
      final formatter = DelegatedConsoleMessageFormatter(
        (record, buffer) {},
        requiresCallerInfo: true,
      );
      expect(formatter.requiresCallerInfo, isTrue);
    });

    test('can use buffer style methods', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.pushStyle(bold: true);
        buffer.write('[BOLD]');
        buffer.popStyle();
        buffer.write(' ');
        buffer.pushStyle(italic: true);
        buffer.write('[ITALIC]');
        buffer.popStyle();
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );

      formatter.format(record, buffer);

      final result = buffer.toString();
      // Should contain ANSI codes for bold and italic
      expect(result, contains('\x1B[1m')); // bold
      expect(result, contains('\x1B[3m')); // italic
      expect(result, contains('[BOLD]'));
      expect(result, contains('[ITALIC]'));
    });

    test('can use inline colors with write', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write('prefix ', foreground: Ansi16.red);
        buffer.write(record.message.toString());
        buffer.write(' suffix', foreground: Ansi16.green);
      });

      final record = LogRecord(message: 'middle', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );

      formatter.format(record, buffer);

      final result = buffer.toString();
      expect(result, contains('prefix'));
      expect(result, contains('middle'));
      expect(result, contains('suffix'));
    });

    test('handles colors disabled gracefully', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.pushStyle(foreground: Ansi16.red, bold: true);
        buffer.write('colored');
        buffer.popStyle();
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      // Should not contain ANSI codes when colors are disabled
      expect(buffer.toString(), 'colored');
      expect(buffer.toString(), isNot(contains('\x1B[')));
    });

    test('can access terminal capabilities', () {
      TerminalColorSupport? capturedSupport;

      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        capturedSupport = buffer.capabilities.colorSupport;
        if (buffer.capabilities.supportsColors) {
          buffer.write('COLORS');
        } else {
          buffer.write('NO_COLORS');
        }
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());

      // Test with colors
      final colorBuffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );
      formatter.format(record, colorBuffer);
      expect(capturedSupport, TerminalColorSupport.ansi256);
      expect(colorBuffer.toString(), 'COLORS');

      // Test without colors
      final noColorBuffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      formatter.format(record, noColorBuffer);
      expect(capturedSupport, TerminalColorSupport.none);
      expect(noColorBuffer.toString(), 'NO_COLORS');
    });

    test('can be used with PrintConsoleWriter', () {
      final outputLines = <String>[];

      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write('[${record.level.name}] ${record.message}');
      });

      final writer = PrintConsoleWriter(
        formatter: formatter,
        output: outputLines.add,
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      final logger = ChirpLogger(name: 'Test').addWriter(writer);

      logger.info('Hello World');

      expect(outputLines, hasLength(1));
      expect(outputLines.first, '[info] Hello World');
    });

    test('can format error and stack trace', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write(record.message.toString());
        if (record.error != null) {
          buffer.write('\nError: ${record.error}');
        }
        if (record.stackTrace != null) {
          buffer.write('\n${record.stackTrace}');
        }
      });

      final record = LogRecord(
        message: 'Operation failed',
        timestamp: DateTime.now(),
        error: Exception('Something went wrong'),
        stackTrace: StackTrace.fromString('#0 main (test.dart:10)'),
      );
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      final result = buffer.toString();
      expect(result, contains('Operation failed'));
      expect(result, contains('Error: Exception: Something went wrong'));
      expect(result, contains('#0 main (test.dart:10)'));
    });

    test('handles null message', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write(record.message ?? 'NULL');
      });

      final record = LogRecord(message: null, timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      expect(buffer.toString(), 'NULL');
    });

    test('handles all log levels', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write('[${record.level.name}]');
      });

      final allLevels = [
        ChirpLogLevel.trace,
        ChirpLogLevel.debug,
        ChirpLogLevel.info,
        ChirpLogLevel.notice,
        ChirpLogLevel.warning,
        ChirpLogLevel.error,
        ChirpLogLevel.critical,
        ChirpLogLevel.wtf,
      ];

      for (final level in allLevels) {
        final record = LogRecord(
          message: 'Test',
          timestamp: DateTime.now(),
          level: level,
        );
        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
            colorSupport: TerminalColorSupport.none,
          ),
        );

        formatter.format(record, buffer);

        expect(buffer.toString(), '[${level.name}]');
      }
    });

    test('can format logger name', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        if (record.loggerName != null) {
          buffer.write('[${record.loggerName}] ');
        }
        buffer.write(record.message.toString());
      });

      final recordWithName = LogRecord(
        message: 'Message',
        timestamp: DateTime.now(),
        loggerName: 'MyLogger',
      );
      final recordWithoutName = LogRecord(
        message: 'Message',
        timestamp: DateTime.now(),
      );

      final buffer1 = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      final buffer2 = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(recordWithName, buffer1);
      formatter.format(recordWithoutName, buffer2);

      expect(buffer1.toString(), '[MyLogger] Message');
      expect(buffer2.toString(), 'Message');
    });

    test('is const constructible', () {
      const formatter = DelegatedConsoleMessageFormatter(_simpleFormat);
      expect(formatter, isA<ConsoleMessageFormatter>());
    });

    test('can create multiline output', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.write('Line 1: ${record.message}');
        buffer.write('\n');
        buffer.write('Line 2: ${record.level.name}');
        buffer.write('\n');
        buffer.write('Line 3: ${record.timestamp.toIso8601String()}');
      });

      final record = LogRecord(
        message: 'Test',
        timestamp: DateTime(2024, 1, 15, 10, 30, 45),
        level: ChirpLogLevel.warning,
      );
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      formatter.format(record, buffer);

      final lines = buffer.toString().split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], 'Line 1: Test');
      expect(lines[1], 'Line 2: warning');
      expect(lines[2], 'Line 3: 2024-01-15T10:30:45.000');
    });

    test('can use nested styles', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.pushStyle(foreground: Ansi16.red);
        buffer.write('outer ');
        buffer.pushStyle(foreground: Ansi16.blue, bold: true);
        buffer.write('inner');
        buffer.popStyle();
        buffer.write(' outer');
        buffer.popStyle();
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );

      formatter.format(record, buffer);

      final result = buffer.toString();
      expect(result, contains('outer'));
      expect(result, contains('inner'));
      // Verify ANSI codes are present (colors enabled)
      expect(result, contains('\x1B['));
    });

    test('visibleLength excludes ANSI codes', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        buffer.pushStyle(foreground: Ansi16.red, bold: true);
        buffer.write('Hello');
        buffer.popStyle();
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );

      formatter.format(record, buffer);

      // visibleLength should only count 'Hello' (5 chars)
      expect(buffer.visibleLength, 5);
      // toString includes ANSI codes so should be longer
      expect(buffer.toString().length, greaterThan(5));
    });
  });
}

/// A simple format function for const constructor test.
void _simpleFormat(LogRecord record, ConsoleMessageBuffer buffer) {
  buffer.write(record.message);
}
