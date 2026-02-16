// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('MessageBuffer.toString()', () {
    test('returns console buffer contents', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      buffer.write('hello');
      buffer.write(' world');

      expect(buffer.toString(), 'hello world');
    });

    test('returns file buffer contents', () {
      final buffer = MessageBuffer.file();

      buffer.write('hello');
      buffer.write(' world');

      expect(buffer.toString(), 'hello world');
    });

    test('returns empty string for empty console buffer', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      expect(buffer.toString(), '');
    });

    test('returns empty string for empty file buffer', () {
      final buffer = MessageBuffer.file();

      expect(buffer.toString(), '');
    });

    test('includes newlines from writeln()', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      buffer.writeln('line 1');
      buffer.write('line 2');

      expect(buffer.toString(), 'line 1\nline 2');
    });
  });

  group('MessageBuffer.console()', () {
    test('exposes console buffer', () {
      final buffer = MessageBuffer.console(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );

      expect(buffer.console, isNotNull);
      expect(buffer.file, isNull);
    });
  });

  group('MessageBuffer.file()', () {
    test('exposes file buffer', () {
      final buffer = MessageBuffer.file();

      expect(buffer.file, isNotNull);
      expect(buffer.console, isNull);
    });
  });

  group('custom MessageBuffer implementation', () {
    test('can be used with ChirpFormatter.format()', () {
      final buffer = _NetworkMessageBuffer();
      final formatter = DelegatedMessageFormatter((record, buffer) {
        buffer.write('[${record.level.name}] ');
        buffer.write(record.message);
      });
      formatter.format(testRecord(message: 'hello'), buffer);

      expect(buffer.toString(), '[info] hello');
      expect(buffer.messages, ['[info] ', 'hello']);
    });

    test('console and file return null', () {
      final buffer = _NetworkMessageBuffer();

      expect(buffer.console, isNull);
      expect(buffer.file, isNull);
    });
  });
}

/// Example custom [MessageBuffer] for network logging.
class _NetworkMessageBuffer implements MessageBuffer {
  final List<String> messages = [];
  final StringBuffer _buffer = StringBuffer();

  @override
  Object get buffer => _buffer;

  @override
  ConsoleMessageBuffer? get console => null;

  @override
  FileMessageBuffer? get file => null;

  @override
  void write(Object? value) {
    final text = value?.toString() ?? 'null';
    _buffer.write(text);
    messages.add(text);
  }

  @override
  void writeln(Object? value) {
    final text = value?.toString() ?? 'null';
    _buffer.writeln(text);
    messages.add(text);
  }

  @override
  String toString() => _buffer.toString();
}
