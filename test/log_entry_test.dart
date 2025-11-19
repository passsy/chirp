import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    test('standard log levels have correct severity values', () {
      expect(ChirpLogLevel.debug.severity, 100);
      expect(ChirpLogLevel.info.severity, 200);
      expect(ChirpLogLevel.warning.severity, 400);
      expect(ChirpLogLevel.error.severity, 500);
      expect(ChirpLogLevel.critical.severity, 600);
    });

    test('standard log levels have correct names', () {
      expect(ChirpLogLevel.debug.name, 'debug');
      expect(ChirpLogLevel.info.name, 'info');
      expect(ChirpLogLevel.warning.name, 'warning');
      expect(ChirpLogLevel.error.name, 'error');
      expect(ChirpLogLevel.critical.name, 'critical');
    });

    test('custom log levels can be created', () {
      const trace = ChirpLogLevel('trace', 50);
      const verbose = ChirpLogLevel('verbose', 150);
      const fatal = ChirpLogLevel('fatal', 700);

      expect(trace.name, 'trace');
      expect(trace.severity, 50);
      expect(verbose.name, 'verbose');
      expect(verbose.severity, 150);
      expect(fatal.name, 'fatal');
      expect(fatal.severity, 700);
    });

    test('log levels can be compared by severity', () {
      const trace = ChirpLogLevel('trace', 50);
      const fatal = ChirpLogLevel('fatal', 700);

      expect(trace.severity < ChirpLogLevel.debug.severity, isTrue);
      expect(
          ChirpLogLevel.debug.severity < ChirpLogLevel.info.severity, isTrue);
      expect(
          ChirpLogLevel.info.severity < ChirpLogLevel.warning.severity, isTrue);
      expect(ChirpLogLevel.warning.severity < ChirpLogLevel.error.severity,
          isTrue);
      expect(ChirpLogLevel.error.severity < ChirpLogLevel.critical.severity,
          isTrue);
      expect(ChirpLogLevel.critical.severity < fatal.severity, isTrue);
    });

    test('log levels support equality', () {
      const level1 = ChirpLogLevel('custom', 300);
      const level2 = ChirpLogLevel('custom', 300);
      const level3 = ChirpLogLevel('custom', 400);
      const level4 = ChirpLogLevel('other', 300);

      expect(level1, equals(level2));
      expect(level1, isNot(equals(level3))); // Different severity
      expect(level1, isNot(equals(level4))); // Different name
    });

    test('log level toString returns name', () {
      const custom = ChirpLogLevel('my_level', 350);
      expect(custom.toString(), 'my_level');
      expect(ChirpLogLevel.debug.toString(), 'debug');
    });

    test('custom log levels work in LogRecord', () {
      const trace = ChirpLogLevel('trace', 50);
      final entry = LogRecord(
        message: 'Trace message',
        date: DateTime.now(),
        level: trace,
      );

      expect(entry.level, trace);
      expect(entry.level.name, 'trace');
      expect(entry.level.severity, 50);
    });
  });

  group('GCP Severity Mapping', () {
    String formatWithGcp(GcpChirpMessageFormatter formatter, LogRecord entry) {
      final builder = ConsoleMessageBuilder();
      formatter.format(entry, builder);
      return builder.build();
    }

    test('GcpChirpMessageFormatter maps standard levels correctly', () {
      final formatter = GcpChirpMessageFormatter();
      final now = DateTime.now();

      // Test standard levels
      final debugEntry = LogRecord(
        message: 'Debug',
        date: now,
        level: ChirpLogLevel.debug,
      );
      expect(formatWithGcp(formatter, debugEntry), contains('"severity":"DEBUG"'));

      final infoEntry = LogRecord(
        message: 'Info',
        date: now,
      );
      expect(formatWithGcp(formatter, infoEntry), contains('"severity":"INFO"'));

      final warningEntry = LogRecord(
        message: 'Warning',
        date: now,
        level: ChirpLogLevel.warning,
      );
      expect(formatWithGcp(formatter, warningEntry), contains('"severity":"WARNING"'));

      final errorEntry = LogRecord(
        message: 'Error',
        date: now,
        level: ChirpLogLevel.error,
      );
      expect(formatWithGcp(formatter, errorEntry), contains('"severity":"ERROR"'));

      final criticalEntry = LogRecord(
        message: 'Critical',
        date: now,
        level: ChirpLogLevel.critical,
      );
      expect(
          formatWithGcp(formatter, criticalEntry), contains('"severity":"CRITICAL"'));
    });

    test('GcpChirpMessageFormatter maps custom levels by severity', () {
      final formatter = GcpChirpMessageFormatter();
      final now = DateTime.now();

      // Trace (< 100) -> DEFAULT
      final traceEntry = LogRecord(
        message: 'Trace',
        date: now,
        level: const ChirpLogLevel('trace', 50),
      );
      expect(formatWithGcp(formatter, traceEntry), contains('"severity":"DEFAULT"'));

      // Verbose (150) -> DEBUG
      final verboseEntry = LogRecord(
        message: 'Verbose',
        date: now,
        level: const ChirpLogLevel('verbose', 150),
      );
      expect(formatWithGcp(formatter, verboseEntry), contains('"severity":"DEBUG"'));

      // Notice (300) -> NOTICE
      final noticeEntry = LogRecord(
        message: 'Notice',
        date: now,
        level: ChirpLogLevel.notice,
      );
      expect(formatWithGcp(formatter, noticeEntry), contains('"severity":"NOTICE"'));

      // Alert (700) -> ALERT
      final alertEntry = LogRecord(
        message: 'Alert',
        date: now,
        level: const ChirpLogLevel('alert', 700),
      );
      expect(formatWithGcp(formatter, alertEntry), contains('"severity":"ALERT"'));

      // Emergency (800+) -> EMERGENCY
      final emergencyEntry = LogRecord(
        message: 'Emergency',
        date: now,
        level: const ChirpLogLevel('emergency', 900),
      );
      expect(
        formatWithGcp(formatter, emergencyEntry),
        contains('"severity":"EMERGENCY"'),
      );
    });
  });

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
        loggerName: 'TestClass',
        instance: instance,
      );

      expect(entry.message, 'Test message');
      expect(entry.date, now);
      expect(entry.error.toString(), contains('Test error'));
      expect(entry.stackTrace, stackTrace);
      expect(entry.loggerName, 'TestClass');
      expect(entry.instance, instance);
    });

    test('creates a log entry with minimal fields', () {
      final now = DateTime.now();
      final instance = Object();

      final entry = LogRecord(
        message: 'Simple message',
        date: now,
        loggerName: 'SimpleClass',
        instance: instance,
      );

      expect(entry.message, 'Simple message');
      expect(entry.date, now);
      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
      expect(entry.loggerName, 'SimpleClass');
      expect(entry.instance, instance);
    });

    test('allows null message', () {
      final entry = LogRecord(
        message: null,
        date: DateTime.now(),
        loggerName: 'NullMessageClass',
        instance: Object(),
      );

      expect(entry.message, isNull);
    });
  });
}
