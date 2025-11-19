import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpMessageWriter', () {
    test('ConsoleChirpMessageWriter writes to output', () {
      final messages = <String>[];

      final writer = ConsoleAppender(
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
      final writer = ConsoleAppender();
      expect(writer, isNotNull);
    });
  });

  group('BufferedChirpMessageWriter', () {
    test('buffers log entries', () {
      final writer = BufferedAppender();

      final entry1 = _createEntry('Message 1');
      final entry2 = _createEntry('Message 2');
      final entry3 = _createEntry('Message 3');

      writer.write(entry1);
      writer.write(entry2);
      writer.write(entry3);

      expect(writer.buffer.length, 3);
      expect(writer.buffer[0].message, 'Message 1');
      expect(writer.buffer[1].message, 'Message 2');
      expect(writer.buffer[2].message, 'Message 3');
    });

    test('flushes to target writer', () {
      final messages = <String>[];
      final targetWriter = ConsoleAppender(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );
      final bufferedWriter = BufferedAppender();

      bufferedWriter.write(_createEntry('Message 1'));
      bufferedWriter.write(_createEntry('Message 2'));

      expect(messages, isEmpty);

      bufferedWriter.flush(targetWriter);

      expect(messages.length, 2);
      expect(messages[0], contains('Message 1'));
      expect(messages[1], contains('Message 2'));
      expect(bufferedWriter.buffer, isEmpty);
    });
  });

  group('MultiChirpMessageWriter', () {
    test('writes to multiple writers', () {
      final messages1 = <String>[];
      final messages2 = <String>[];
      final messages3 = <String>[];

      final writer = MultiAppender([
        ConsoleAppender(
          formatter: CompactChirpMessageFormatter(),
          output: messages1.add,
        ),
        ConsoleAppender(
          formatter: CompactChirpMessageFormatter(),
          output: messages2.add,
        ),
        ConsoleAppender(
          formatter: CompactChirpMessageFormatter(),
          output: messages3.add,
        ),
      ]);

      writer.write(_createEntry('Test message'));

      expect(messages1.length, 1);
      expect(messages1[0], contains('Test message'));
      expect(messages2.length, 1);
      expect(messages2[0], contains('Test message'));
      expect(messages3.length, 1);
      expect(messages3[0], contains('Test message'));
    });

    test('handles empty writers list', () {
      final writer = MultiAppender([]);
      expect(() => writer.write(_createEntry('Test')), returnsNormally);
    });
  });
}

/// Helper to create a LogRecord for testing
LogRecord _createEntry(Object? message) {
  return LogRecord(
    message: message,
    date: DateTime.now(),
    loggerName: 'TestClass',
    instance: Object(),
  );
}
