import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Contextual Data', () {
    test('logger with initial context includes it in logs', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API')
          .addContext({'requestId': 'REQ-123', 'userId': 'user_456'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      logger.info('Processing request');

      expect(messages.length, 1);
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));
    });

    test('context is mutable', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API')
          .addContext({'requestId': 'REQ-123'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      logger.info('First log');
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], isNot(contains('"userId"')));

      // Add userId
      logger.context['userId'] = 'user_456';

      logger.info('Second log');
      expect(messages[1], contains('"requestId":"REQ-123"'));
      expect(messages[1], contains('"userId":"user_456"'));
    });

    test('context.addAll adds multiple entries', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API').addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      logger.context.addAll({
        'requestId': 'REQ-123',
        'userId': 'user_456',
        'endpoint': '/api/users',
      });

      logger.info('Request logged');

      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));
      expect(messages[0], contains('"endpoint":"/api/users"'));
    });

    test('log-specific data overrides logger context', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API')
          .addContext({'requestId': 'REQ-123', 'status': 'pending'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      logger.info(
        'Request completed',
        data: {'status': 'completed'}, // Override
      );

      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"status":"completed"'));
      expect(messages[0], isNot(contains('"status":"pending"')));
    });

    test('child() creates new logger with merged context', () {
      final messages = <String>[];
      final baseLogger = ChirpLogger(name: 'API')
          .addContext({'app': 'myapp'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      final requestLogger = baseLogger.child(context: {
        'requestId': 'REQ-123',
        'userId': 'user_456',
      });

      requestLogger.info('Processing request');

      expect(messages[0], contains('"app":"myapp"'));
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));
    });

    test('child() does not mutate original logger', () {
      final messages = <String>[];
      final baseLogger = ChirpLogger(name: 'API')
          .addContext({'app': 'myapp'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      final requestLogger = baseLogger.child(context: {'requestId': 'REQ-123'});

      baseLogger.info('From base logger');
      expect(messages[0], contains('"app":"myapp"'));
      expect(messages[0], isNot(contains('"requestId"')));

      requestLogger.info('From request logger');
      expect(messages[1], contains('"app":"myapp"'));
      expect(messages[1], contains('"requestId":"REQ-123"'));
    });

    test('empty context logger does not include data in log', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API').addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      logger.info('Simple log');

      // Should not have a "data" field in JSON when no context
      expect(messages[0], isNot(contains('"data"')));
    });

    test('context.remove removes a single key', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API')
          .addContext({'requestId': 'REQ-123', 'userId': 'user_456'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      logger.info('Before removal');
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));

      final removed = logger.context.remove('userId');
      expect(removed, 'user_456');

      logger.info('After removal');
      expect(messages[1], contains('"requestId":"REQ-123"'));
      expect(messages[1], isNot(contains('"userId"')));
    });

    test('context.removeWhere removes multiple keys', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API')
          .addContext({
            'requestId': 'REQ-123',
            'userId': 'user_456',
            'sessionId': 'sess_789',
          })
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      logger.info('Before removal');
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));
      expect(messages[0], contains('"sessionId":"sess_789"'));

      logger.context.removeWhere((key, value) => key != 'requestId');

      logger.info('After removal');
      expect(messages[1], contains('"requestId":"REQ-123"'));
      expect(messages[1], isNot(contains('"userId"')));
      expect(messages[1], isNot(contains('"sessionId"')));
    });

    test('context.clear removes all context', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'API')
          .addContext({
            'requestId': 'REQ-123',
            'userId': 'user_456',
            'sessionId': 'sess_789',
          })
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      logger.info('Before clear');
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));

      logger.context.clear();

      logger.info('After clear');
      expect(messages[1], isNot(contains('"requestId"')));
      expect(messages[1], isNot(contains('"userId"')));
      expect(messages[1], isNot(contains('"sessionId"')));
    });

    test('context.remove on non-existent key returns null', () {
      final logger = ChirpLogger(name: 'API').addContext({'requestId': 'REQ-123'});

      final removed = logger.context.remove('nonExistent');
      expect(removed, isNull);

      // Original context should still be there
      expect(logger.context, {'requestId': 'REQ-123'});
    });
  });
}
