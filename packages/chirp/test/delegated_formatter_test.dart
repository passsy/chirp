import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('DelegatedConsoleMessageFormatter', () {
    test('calls the provided function with record and buffer', () {
      LogRecord? receivedRecord;
      ConsoleMessageBuffer? receivedBuffer;

      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {
        receivedRecord = record;
        receivedBuffer = buffer;
      });

      final record = LogRecord(message: 'Test', timestamp: DateTime.now());
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(),
      );

      formatter.format(record, buffer);

      expect(receivedRecord, same(record));
      expect(receivedBuffer, same(buffer));
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

    test('toString includes creation site in debug mode', () {
      final formatter = DelegatedConsoleMessageFormatter((record, buffer) {});
      expect(formatter.toString(), contains('delegated_formatter_test'));
    });
  });
}
