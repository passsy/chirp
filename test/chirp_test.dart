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
      final logger = ChirpLogger(
        name: 'HTTP',
        writers: [
          ConsoleAppender(
            formatter: CompactChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      logger.log('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('HTTP'));
      expect(messages[0], contains('Test message'));
    });

    test('logs with top-level chirp', () {
      final messages = <String>[];
      final originalRoot = Chirp.root;

      Chirp.root = ChirpLogger(
        writers: [
          ConsoleAppender(
            formatter: CompactChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.log('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('chirp_test'));
      expect(messages[0], contains('Test message'));

      Chirp.root = originalRoot;
    });

    test('logs with error and stack trace', () {
      final messages = <String>[];
      final logger = ChirpLogger(
        name: 'ErrorLogger',
        writers: [
          ConsoleAppender(
            formatter: CompactChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
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

    test('Chirp.root exists as static', () {
      expect(Chirp.root, isNotNull);
      expect(Chirp.root, isA<ChirpLogger>());
    });

    test('can replace Chirp.root', () {
      final originalRoot = Chirp.root;
      final messages = <String>[];

      // Replace root with custom logger
      Chirp.root = ChirpLogger(
        name: 'CustomRoot',
        writers: [
          ConsoleAppender(
            formatter: CompactChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.root.log('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('CustomRoot'));

      // Restore original
      Chirp.root = originalRoot;
    });
  });
}
