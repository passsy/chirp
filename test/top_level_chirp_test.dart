import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Static Chirp methods', () {
    setUp(() {
      // Reset to default logger before each test
      Chirp.root = ChirpLogger();
    });

    test('Chirp.log() captures caller information from stack trace', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: RainbowMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.log('Test message from top-level');

      expect(messages.length, 1);
      // Should contain the test file name
      expect(messages[0], contains('top_level_chirp_test'));
    });

    test('Chirp with different log levels', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: JsonChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.log('Debug test', level: ChirpLogLevel.debug);
      Chirp.log('Info test', level: ChirpLogLevel.info);
      Chirp.log('Warning test', level: ChirpLogLevel.warning);
      Chirp.log('Error test', level: ChirpLogLevel.error);

      expect(messages.length, 4);
      expect(messages[0], contains('"level":"debug"'));
      expect(messages[1], contains('"level":"info"'));
      expect(messages[2], contains('"level":"warning"'));
      expect(messages[3], contains('"level":"error"'));
    });

    test('Chirp.debug() convenience function', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: JsonChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.debug('Debug message');

      expect(messages.length, 1);
      expect(messages[0], contains('"level":"debug"'));
      expect(messages[0], contains('Debug message'));
    });

    test('Chirp.info() convenience function', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: JsonChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.info('Info message');

      expect(messages.length, 1);
      expect(messages[0], contains('"level":"info"'));
      expect(messages[0], contains('Info message'));
    });

    test('Chirp.warning() convenience function', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: JsonChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.warning('Warning message');

      expect(messages.length, 1);
      expect(messages[0], contains('"level":"warning"'));
      expect(messages[0], contains('Warning message'));
    });

    test('Chirp.error() convenience function', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: JsonChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.error('Error message');

      expect(messages.length, 1);
      expect(messages[0], contains('"level":"error"'));
      expect(messages[0], contains('Error message'));
    });

    test('Chirp with error and stack trace', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: RainbowMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      Chirp.error('Something failed', error: error, stackTrace: stackTrace);

      expect(messages.length, 1);
      expect(messages[0], contains('Something failed'));
      expect(messages[0], contains('Test error'));
    });

    test('Chirp with structured data', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: JsonChirpMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.log('User action', data: {
        'userId': 123,
        'action': 'login',
        'ip': '192.168.1.1',
      });

      expect(messages.length, 1);
      expect(messages[0], contains('"userId":123'));
      expect(messages[0], contains('"action":"login"'));
      expect(messages[0], contains('"ip":"192.168.1.1"'));
    });

    test('Chirp captures line numbers', () {
      final messages = <String>[];
      Chirp.root = ChirpLogger(
        writers: [
          ConsoleChirpMessageWriter(
            formatter: RainbowMessageFormatter(),
            output: messages.add,
          ),
        ],
      );

      Chirp.log('Message with line number');

      expect(messages.length, 1);
      // Should contain line number (format: filename:linenumber)
      expect(messages[0], matches(RegExp(r':\d+')));
    });
  });
}
