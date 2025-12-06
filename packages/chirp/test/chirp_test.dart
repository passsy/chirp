import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Chirp', () {
    test('creates logger with name', () {
      final logger = ChirpLogger(name: 'TestLogger');
      expect(logger.name, 'TestLogger');
    });

    test('creates logger without name', () {
      final logger = ChirpLogger();
      expect(logger.name, isNull);
    });

    test('logs with named logger', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'HTTP').addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      logger.log('Test message');

      expect(messages.length, 1);
      // CompactChirpMessageFormatter shows caller location, not logger name
      expect(messages[0], contains('Test message'));
    });

    test('logs with top-level chirp', () {
      addTearDown(() => Chirp.root = null);
      final messages = <String>[];

      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      Chirp.log('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('Test message'));
    });

    test('logs with error and stack trace', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'ErrorLogger').addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      logger.log(
        'Error occurred',
        error: Exception('Test error'),
        stackTrace: StackTrace.current,
      );

      expect(messages.length, 1);
      expect(messages[0], contains('Error occurred'));
      expect(messages[0], contains('Test error'));
    });

    test('Chirp.root throws StateError when not set', () {
      Chirp.root = null;
      expect(
        () => Chirp.root,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Chirp.root has not been set'),
          ),
        ),
      );
    });

    test('can replace Chirp.root', () {
      addTearDown(() => Chirp.root = null);
      final messages = <String>[];

      // Replace root with custom logger
      Chirp.root = ChirpLogger(name: 'CustomRoot').addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      Chirp.root.log('Test message');

      expect(messages.length, 1);
      // CompactChirpMessageFormatter shows caller location, not logger name
      expect(messages[0], contains('Test message'));
    });
  });
}
