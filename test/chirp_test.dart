import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Chirp', () {
    test('creates logger with name', () {
      final logger = Chirp(name: 'TestLogger');
      expect(logger.name, 'TestLogger');
    });

    test('creates logger without name', () {
      final logger = Chirp();
      expect(logger.name, isNull);
    });

    test('logs with named logger', () {
      final messages = <String>[];
      final logger = Chirp(
        name: 'HTTP',
        writers: [
          ConsoleChirpMessageWriter(
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

    test('logs with instance', () {
      final messages = <String>[];
      final originalRoot = Chirp.root;

      Chirp.root = Chirp(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: CompactChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      final instance = _TestClass();
      instance.chirp('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('_TestClass'));
      expect(messages[0], contains('Test message'));

      Chirp.root = originalRoot;
    });

    test('logs with error and stack trace', () {
      final messages = <String>[];
      final logger = Chirp(
        name: 'ErrorLogger',
        writers: [
          ConsoleChirpMessageWriter(
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

    test('applies class name transformers', () {
      final messages = <String>[];
      final originalRoot = Chirp.root;

      Chirp.root = Chirp(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: CompactChirpMessageFormatter(
              classNameTransformers: [
                (instance) {
                  if (instance is _TestClass) {
                    return 'TransformedName';
                  }
                  return null;
                },
              ],
            ),
            output: messages.add,
          ),
        ],
      );

      final instance = _TestClass();
      instance.chirp('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('TransformedName'));
      expect(messages[0], isNot(contains('_TestClass')));

      Chirp.root = originalRoot;
    });

    test('transformer precedence (first match wins)', () {
      final messages = <String>[];
      final originalRoot = Chirp.root;

      Chirp.root = Chirp(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: CompactChirpMessageFormatter(
              classNameTransformers: [
                (instance) {
                  if (instance is _TestClass) {
                    return 'FirstTransformer';
                  }
                  return null;
                },
                (instance) {
                  if (instance is _TestClass) {
                    return 'SecondTransformer';
                  }
                  return null;
                },
              ],
            ),
            output: messages.add,
          ),
        ],
      );

      final instance = _TestClass();
      instance.chirp('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('FirstTransformer'));
      expect(messages[0], isNot(contains('SecondTransformer')));

      Chirp.root = originalRoot;
    });

    test('uses runtimeType as fallback when no transformer matches', () {
      final messages = <String>[];
      final originalRoot = Chirp.root;

      Chirp.root = Chirp(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: CompactChirpMessageFormatter(
              classNameTransformers: [
                (instance) => null, // Always returns null
              ],
            ),
            output: messages.add,
          ),
        ],
      );

      final instance = _TestClass();
      instance.chirp('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('_TestClass'));

      Chirp.root = originalRoot;
    });

    test('Chirp.root exists as static', () {
      expect(Chirp.root, isNotNull);
      expect(Chirp.root, isA<Chirp>());
    });

    test('can replace Chirp.root', () {
      final originalRoot = Chirp.root;
      final messages = <String>[];

      // Replace root with custom logger
      Chirp.root = Chirp(
        name: 'CustomRoot',
        writers: [
          ConsoleChirpMessageWriter(
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

class _TestClass {}
