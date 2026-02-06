import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('DelegatedMessageFormatter', () {
    test('calls the provided function with record and buffer', () {
      LogRecord? receivedRecord;
      MessageBuffer? receivedBuffer;

      final formatter = DelegatedMessageFormatter((record, buffer) {
        receivedRecord = record;
        receivedBuffer = buffer;
      });

      final record = testRecord();
      final buffer = MessageBuffer(
        ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(),
        ),
      );

      formatter.format(record, buffer);

      expect(receivedRecord, same(record));
      expect(receivedBuffer, same(buffer));
    });

    test('requiresCallerInfo defaults to false', () {
      final formatter = DelegatedMessageFormatter((record, buffer) {});
      expect(formatter.requiresCallerInfo, isFalse);
    });

    test('requiresCallerInfo can be set to true', () {
      final formatter = DelegatedMessageFormatter(
        (record, buffer) {},
        requiresCallerInfo: true,
      );
      expect(formatter.requiresCallerInfo, isTrue);
    });

    test('toString includes creation site in debug mode', () {
      final formatter = DelegatedMessageFormatter((record, buffer) {});
      expect(formatter.toString(), contains('delegated_formatter_test'));
    });
  });
}
