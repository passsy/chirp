import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('DelegatedChirpInterceptor', () {
    test('calls the provided function with the record', () {
      LogRecord? receivedRecord;
      final interceptor = DelegatedChirpInterceptor((record) {
        receivedRecord = record;
        return record;
      });

      final record = testRecord();
      interceptor.intercept(record);

      expect(receivedRecord, same(record));
    });

    test('returns the function result', () {
      final interceptor = DelegatedChirpInterceptor((record) => null);
      final record = testRecord();

      expect(interceptor.intercept(record), isNull);
    });

    test('requiresCallerInfo defaults to false', () {
      final interceptor = DelegatedChirpInterceptor((record) => record);
      expect(interceptor.requiresCallerInfo, isFalse);
    });

    test('requiresCallerInfo can be set to true', () {
      final interceptor = DelegatedChirpInterceptor(
        (record) => record,
        requiresCallerInfo: true,
      );
      expect(interceptor.requiresCallerInfo, isTrue);
    });

    test('toString includes creation site in debug mode', () {
      final interceptor = DelegatedChirpInterceptor((record) => record);
      expect(interceptor.toString(), contains('delegated_interceptor_test'));
    });
  });
}
