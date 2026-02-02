import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('DelegatedChirpWriter', () {
    test('calls the provided function with the record', () {
      LogRecord? receivedRecord;
      final writer = DelegatedChirpWriter((record) {
        receivedRecord = record;
      });

      final record = testRecord();
      writer.write(record);

      expect(receivedRecord, same(record));
    });

    test('requiresCallerInfo defaults to false', () {
      final writer = DelegatedChirpWriter((record) {});
      expect(writer.requiresCallerInfo, isFalse);
    });

    test('requiresCallerInfo can be set to true', () {
      final writer = DelegatedChirpWriter(
        (record) {},
        requiresCallerInfo: true,
      );
      expect(writer.requiresCallerInfo, isTrue);
    });

    test('toString includes creation site in debug mode', () {
      final writer = DelegatedChirpWriter((record) {});
      expect(writer.toString(), contains('delegated_writer_test'));
    });
  });
}
