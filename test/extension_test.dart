import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpObjectExt', () {
    late List<String> messages;
    late Chirp originalRoot;

    setUp(() {
      messages = [];
      originalRoot = Chirp.root;

      // Replace root with test logger
      Chirp.root = Chirp(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: CompactChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );
    });

    tearDown(() {
      // Restore original root
      Chirp.root = originalRoot;
    });

    test('chirp() logs from instance', () {
      final instance = _TestService();
      instance.chirp('Test message');

      expect(messages.length, 1);
      expect(messages[0], contains('_TestService'));
      expect(messages[0], contains('Test message'));
    });

    test('chirp() logs with error', () {
      final instance = _TestService();
      instance.chirp('Error message', Exception('Test error'));

      expect(messages.length, 1);
      expect(messages[0], contains('Error message'));
      expect(messages[0], contains('Test error'));
    });

    test('chirp() logs with error and stack trace', () {
      final instance = _TestService();
      instance.chirp(
        'Error message',
        Exception('Test error'),
        StackTrace.current,
      );

      expect(messages.length, 1);
      expect(messages[0], contains('Error message'));
      expect(messages[0], contains('Test error'));
    });

    test('chirpError() is alias for chirp()', () {
      final instance = _TestService();
      instance.chirpError('Error message', Exception('Test error'));

      expect(messages.length, 1);
      expect(messages[0], contains('Error message'));
      expect(messages[0], contains('Test error'));
    });

    test('multiple instances have different hashes', () {
      final instance1 = _TestService();
      final instance2 = _TestService();

      instance1.chirp('From instance 1');
      instance2.chirp('From instance 2');

      expect(messages.length, 2);

      // Both messages contain class name
      expect(messages[0], contains('_TestService'));
      expect(messages[1], contains('_TestService'));

      // But they should have different hashes (extracted after ":")
      final hash1 = _extractHash(messages[0]);
      final hash2 = _extractHash(messages[1]);

      expect(hash1, isNot(equals(hash2)));
    });

    test('extension works with any object type', () {
      const string = 'test string';
      string.chirp('Logging from String');

      expect(messages.length, 1);
      expect(messages[0], contains('String'));
      expect(messages[0], contains('Logging from String'));
    });

    test('extension works with built-in types', () {
      final list = [1, 2, 3];
      list.chirp('Logging from List');

      expect(messages.length, 1);
      expect(messages[0], contains('List'));
      expect(messages[0], contains('Logging from List'));
    });
  });
}

class _TestService {}

/// Extract hash from formatted message like "10:23:45.123 ClassName:abcd message"
String _extractHash(String message) {
  final match = RegExp(r':([0-9a-f]{4})\s').firstMatch(message);
  return match?.group(1) ?? '';
}
