import 'package:chirp/src/log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LogRecord', () {
    test('creates a log entry with all fields', () {
      final now = DateTime.now();
      final instance = Object();
      final stackTrace = StackTrace.current;

      final entry = LogRecord(
        message: 'Test message',
        date: now,
        error: Exception('Test error'),
        stackTrace: stackTrace,
        className: 'TestClass',
        instance: instance,
      );

      expect(entry.message, 'Test message');
      expect(entry.date, now);
      expect(entry.error.toString(), contains('Test error'));
      expect(entry.stackTrace, stackTrace);
      expect(entry.className, 'TestClass');
      expect(entry.instance, instance);
    });

    test('creates a log entry with minimal fields', () {
      final now = DateTime.now();
      final instance = Object();

      final entry = LogRecord(
        message: 'Simple message',
        date: now,
        className: 'SimpleClass',
        instance: instance,
      );

      expect(entry.message, 'Simple message');
      expect(entry.date, now);
      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
      expect(entry.className, 'SimpleClass');
      expect(entry.instance, instance);
    });

    test('allows null message', () {
      final entry = LogRecord(
        message: null,
        date: DateTime.now(),
        className: 'NullMessageClass',
        instance: Object(),
      );

      expect(entry.message, isNull);
    });
  });
}
