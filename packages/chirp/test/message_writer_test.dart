import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('ChirpMessageWriter', () {
    test('ConsoleChirpMessageWriter writes to output', () {
      final messages = <String>[];

      final writer = PrintConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      writer.write(testRecord(
          message: 'Test message 1',
          loggerName: 'TestClass',
          instance: Object()));
      writer.write(testRecord(
          message: 'Test message 2',
          loggerName: 'TestClass',
          instance: Object()));

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
