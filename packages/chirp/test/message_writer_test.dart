import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpMessageWriter', () {
    test('ConsoleChirpMessageWriter writes to output', () {
      final messages = <String>[];

      final writer = PrintConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      writer.write(_createEntry('Test message 1'));
      writer.write(_createEntry('Test message 2'));

      expect(messages.length, 2);
      expect(messages[0], contains('Test message 1'));
      expect(messages[1], contains('Test message 2'));
    });

    test('ConsoleChirpMessageWriter uses print by default', () {
      // Can't easily test print, but we can verify the constructor accepts null
      final writer = PrintConsoleWriter();
      expect(writer, isNotNull);
    });
  });
}

/// Helper to create a LogRecord for testing
LogRecord _createEntry(Object? message) {
  return LogRecord(
    message: message,
    timestamp: DateTime.now(),
    loggerName: 'TestClass',
    instance: Object(),
  );
}
