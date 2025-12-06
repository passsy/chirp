import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpLogLevel', () {
    test('standard log levels have correct severity values', () {
      expect(ChirpLogLevel.trace.severity, 0);
      expect(ChirpLogLevel.debug.severity, 100);
      expect(ChirpLogLevel.info.severity, 200);
      expect(ChirpLogLevel.notice.severity, 300);
      expect(ChirpLogLevel.warning.severity, 400);
      expect(ChirpLogLevel.error.severity, 500);
      expect(ChirpLogLevel.critical.severity, 600);
      expect(ChirpLogLevel.wtf.severity, 1000);
    });

    test('custom log levels can be created', () {
      const verbose = ChirpLogLevel('verbose', 150);
      expect(verbose.name, 'verbose');
      expect(verbose.severity, 150);
    });

    test('log levels support comparison operators', () {
      expect(ChirpLogLevel.debug < ChirpLogLevel.info, isTrue);
      expect(ChirpLogLevel.error > ChirpLogLevel.warning, isTrue);
      expect(ChirpLogLevel.info <= ChirpLogLevel.info, isTrue);
      expect(ChirpLogLevel.info >= ChirpLogLevel.info, isTrue);
    });

    test('log levels support equality', () {
      const level1 = ChirpLogLevel('custom', 300);
      const level2 = ChirpLogLevel('custom', 300);
      const level3 = ChirpLogLevel('custom', 400);

      expect(level1, equals(level2));
      expect(level1, isNot(equals(level3)));
    });
  });

  group('LogRecord', () {
    test('creates a log record with required fields', () {
      final now = DateTime.now();
      final record = LogRecord(
        message: 'Test message',
        timestamp: now,
      );

      expect(record.message, 'Test message');
      expect(record.timestamp, now);
      expect(record.level, ChirpLogLevel.info);
    });

    test('creates a log record with all optional fields', () {
      final now = DateTime.now();
      final stackTrace = StackTrace.current;
      final instance = Object();

      final record = LogRecord(
        message: 'Full message',
        timestamp: now,
        level: ChirpLogLevel.error,
        error: Exception('test error'),
        stackTrace: stackTrace,
        caller: StackTrace.current,
        skipFrames: 2,
        instance: instance,
        loggerName: 'TestLogger',
        data: {'key': 'value'},
        formatOptions: [const FormatOptions()],
      );

      expect(record.message, 'Full message');
      expect(record.level, ChirpLogLevel.error);
      expect(record.error.toString(), contains('test error'));
      expect(record.stackTrace, stackTrace);
      expect(record.instance, instance);
      expect(record.loggerName, 'TestLogger');
      expect(record.data, {'key': 'value'});
      expect(record.formatOptions, isNotEmpty);
    });
  });

  group('ChirpLogger', () {
    test('logs messages at different levels', () {
      final records = <LogRecord>[];
      final logger =
          ChirpLogger(name: 'Test').addWriter(_TestWriter(records.add));

      logger.trace('trace msg');
      logger.debug('debug msg');
      logger.info('info msg');
      logger.notice('notice msg');
      logger.warning('warning msg');
      logger.error('error msg');
      logger.critical('critical msg');
      logger.wtf('wtf msg');

      expect(records.length, 8);
      expect(records[0].level, ChirpLogLevel.trace);
      expect(records[1].level, ChirpLogLevel.debug);
      expect(records[2].level, ChirpLogLevel.info);
      expect(records[3].level, ChirpLogLevel.notice);
      expect(records[4].level, ChirpLogLevel.warning);
      expect(records[5].level, ChirpLogLevel.error);
      expect(records[6].level, ChirpLogLevel.critical);
      expect(records[7].level, ChirpLogLevel.wtf);
    });

    test('child logger inherits parent writers', () {
      final records = <LogRecord>[];
      final parent =
          ChirpLogger(name: 'Parent').addWriter(_TestWriter(records.add));

      final child = parent.child(context: {'requestId': 'REQ-123'});

      child.info('child message');

      expect(records.length, 1);
      expect(records[0].data['requestId'], 'REQ-123');
    });

    test('context is merged into log data', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger(name: 'Test');
      logger.context['app'] = 'myapp';
      logger.addWriter(_TestWriter(records.add));

      logger.info('message', data: {'extra': 'value'});

      expect(records[0].data['app'], 'myapp');
      expect(records[0].data['extra'], 'value');
    });
  });
}

class _TestWriter extends ChirpWriter {
  final void Function(LogRecord) onWrite;

  _TestWriter(this.onWrite);

  @override
  void write(LogRecord record) => onWrite(record);
}
