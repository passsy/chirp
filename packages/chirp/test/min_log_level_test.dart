import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Logger minLogLevel', () {
    test('default minLogLevel is null (accepts all)', () {
      final logger = ChirpLogger(name: 'test');
      expect(logger.minLogLevel, isNull);
    });

    test('null minLogLevel accepts custom levels with negative severity', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test').addWriter(writer);

      // Custom level with negative severity
      const superVerbose = ChirpLogLevel('superVerbose', -100);
      logger.log('very detailed', level: superVerbose);

      expect(records.length, 1);
      expect(records[0].level, superVerbose);
    });

    test('logs below minLogLevel are rejected', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .setMinLogLevel(ChirpLogLevel.warning);

      logger.trace('trace');
      logger.debug('debug');
      logger.info('info');
      logger.notice('notice');
      logger.warning('warning');
      logger.error('error');

      expect(records.length, 2);
      expect(records[0].level, ChirpLogLevel.warning);
      expect(records[1].level, ChirpLogLevel.error);
    });

    test('setMinLogLevel returns this for chaining', () {
      final logger = ChirpLogger(name: 'test');
      final result = logger.setMinLogLevel(ChirpLogLevel.info);
      expect(result, same(logger));
      expect(logger.minLogLevel, ChirpLogLevel.info);
    });

    test('setMinLogLevel(null) resets to accept all levels', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .setMinLogLevel(ChirpLogLevel.warning);

      // Only warnings and above pass
      logger.debug('debug 1');
      logger.warning('warning 1');
      expect(records.length, 1);

      // Reset to null - accept all
      logger.setMinLogLevel(null);
      expect(logger.minLogLevel, isNull);

      logger.debug('debug 2');
      logger.warning('warning 2');
      expect(records.length, 3);
      expect(records[1].message, 'debug 2');
      expect(records[2].message, 'warning 2');
    });

    test('minLogLevel prevents LogRecord creation (no stacktrace capture)', () {
      var callerCaptured = false;
      final writer = _CallerTrackingWriter(() => callerCaptured = true);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .setMinLogLevel(ChirpLogLevel.warning);

      // This should be rejected before LogRecord creation
      logger.debug('rejected');
      expect(callerCaptured, isFalse);

      // This should pass and capture caller
      logger.warning('accepted');
      expect(callerCaptured, isTrue);
    });

    test('each log level method respects minLogLevel', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .setMinLogLevel(ChirpLogLevel.error);

      logger.trace('trace');
      logger.debug('debug');
      logger.info('info');
      logger.notice('notice');
      logger.warning('warning');
      logger.error('error');
      logger.critical('critical');
      logger.wtf('wtf');

      expect(records.length, 3);
      expect(records.map((r) => r.level.name), ['error', 'critical', 'wtf']);
    });

    test('log() method respects minLogLevel', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .setMinLogLevel(ChirpLogLevel.warning);

      logger.log('info level');
      logger.log('warning level', level: ChirpLogLevel.warning);

      expect(records.length, 1);
      expect(records[0].message, 'warning level');
    });
  });

  group('Writer minLogLevel', () {
    test('default minLogLevel is null (accepts all)', () {
      final writer = _TestWriter((_) {});
      expect(writer.minLogLevel, isNull);
    });

    test('writer filters records below its minLogLevel', () {
      final allRecords = <LogRecord>[];
      final warningRecords = <LogRecord>[];

      final allWriter = _TestWriter(allRecords.add);
      final warningWriter =
          _TestWriter(warningRecords.add).setMinLogLevel(ChirpLogLevel.warning);

      final logger = ChirpLogger(name: 'test')
          .addWriter(allWriter)
          .addWriter(warningWriter);

      logger.debug('debug');
      logger.info('info');
      logger.warning('warning');
      logger.error('error');

      // allWriter receives everything
      expect(allRecords.length, 4);

      // warningWriter only receives warning and above
      expect(warningRecords.length, 2);
      expect(warningRecords.map((r) => r.level.name), ['warning', 'error']);
    });

    test('setMinLogLevel returns this for chaining', () {
      final writer = _TestWriter((_) {});
      final result = writer.setMinLogLevel(ChirpLogLevel.info);
      expect(result, same(writer));
      expect(writer.minLogLevel, ChirpLogLevel.info);
    });

    test('multiple writers with different minLogLevels', () {
      final debugRecords = <LogRecord>[];
      final infoRecords = <LogRecord>[];
      final errorRecords = <LogRecord>[];

      final logger = ChirpLogger(name: 'test')
          .addWriter(
            _TestWriter(debugRecords.add).setMinLogLevel(ChirpLogLevel.debug),
          )
          .addWriter(
            _TestWriter(infoRecords.add).setMinLogLevel(ChirpLogLevel.info),
          )
          .addWriter(
            _TestWriter(errorRecords.add).setMinLogLevel(ChirpLogLevel.error),
          );

      logger.trace('trace');
      logger.debug('debug');
      logger.info('info');
      logger.warning('warning');
      logger.error('error');

      expect(debugRecords.length, 4); // debug, info, warning, error
      expect(infoRecords.length, 3); // info, warning, error
      expect(errorRecords.length, 1); // error only
    });

    test('logger minLogLevel and writer minLogLevel work together', () {
      final records = <LogRecord>[];
      final writer =
          _TestWriter(records.add).setMinLogLevel(ChirpLogLevel.error);

      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .setMinLogLevel(ChirpLogLevel.info); // Logger allows info+

      logger.debug('debug'); // Rejected by logger
      logger.info('info'); // Passed by logger, rejected by writer
      logger.warning('warning'); // Passed by logger, rejected by writer
      logger.error('error'); // Passed by both

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.error);
    });
  });

  group('Logger interceptors', () {
    test('logger interceptors are applied to all records', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .addInterceptor(_PrefixInterceptor('PREFIX: '));

      logger.info('test message');

      expect(records.length, 1);
      expect(records[0].message, 'PREFIX: test message');
    });

    test('logger interceptors can reject records', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .addInterceptor(_RejectInterceptor());

      logger.info('should be rejected');

      expect(records, isEmpty);
    });

    test('multiple interceptors are applied in order', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .addInterceptor(_PrefixInterceptor('A: '))
          .addInterceptor(_PrefixInterceptor('B: '));

      logger.info('msg');

      expect(records.length, 1);
      expect(records[0].message, 'B: A: msg');
    });

    test('addInterceptor returns this for chaining', () {
      final logger = ChirpLogger(name: 'test');
      final result = logger.addInterceptor(_PrefixInterceptor('test'));
      expect(result, same(logger));
    });

    test('removeInterceptor removes interceptor', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final interceptor = _PrefixInterceptor('PREFIX: ');
      final logger = ChirpLogger(name: 'test')
          .addWriter(writer)
          .addInterceptor(interceptor);

      logger.info('first');
      expect(records[0].message, 'PREFIX: first');

      final removed = logger.removeInterceptor(interceptor);
      expect(removed, isTrue);

      logger.info('second');
      expect(records[1].message, 'second');
    });

    test('interceptors getter returns read-only list', () {
      final logger = ChirpLogger(name: 'test');
      final interceptor = _PrefixInterceptor('test');
      logger.addInterceptor(interceptor);

      expect(logger.interceptors.length, 1);
      expect(logger.interceptors[0], same(interceptor));
      expect(() => (logger.interceptors as List).add(_PrefixInterceptor('x')),
          throwsUnsupportedError);
    });

    test('child logger inherits parent interceptors', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final parent = ChirpLogger(name: 'parent')
          .addWriter(writer)
          .addInterceptor(_PrefixInterceptor('PARENT: '));

      final child = parent.child(name: 'child');
      child.info('child message');

      expect(records.length, 1);
      expect(records[0].message, 'PARENT: child message');
    });

    test('child interceptors are applied after parent interceptors', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final parent = ChirpLogger(name: 'parent')
          .addWriter(writer)
          .addInterceptor(_PrefixInterceptor('P: '));

      final child =
          parent.child(name: 'child').addInterceptor(_PrefixInterceptor('C: '));

      child.info('msg');

      expect(records.length, 1);
      expect(records[0].message, 'C: P: msg'); // Parent first, then child
    });

    test('adopted logger inherits parent interceptors', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final parent = ChirpLogger(name: 'parent')
          .addWriter(writer)
          .addInterceptor(_PrefixInterceptor('PARENT: '));

      final orphan = ChirpLogger(name: 'orphan');
      parent.adopt(orphan);

      orphan.info('adopted message');

      expect(records.length, 1);
      expect(records[0].message, 'PARENT: adopted message');
    });
  });

  group('Chainable API', () {
    test('logger methods can be chained', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);

      final logger = ChirpLogger(name: 'test')
          .setMinLogLevel(ChirpLogLevel.info)
          .addInterceptor(_PrefixInterceptor('LOG: '))
          .addWriter(writer)
          .addContext({'env': 'test'});

      logger.info('chained');

      expect(records.length, 1);
      expect(records[0].message, 'LOG: chained');
      expect(records[0].data['env'], 'test');
    });

    test('writer methods can be chained', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      writer.setMinLogLevel(ChirpLogLevel.warning);
      writer.addInterceptor(_PrefixInterceptor('WARN: '));

      final logger = ChirpLogger(name: 'test').addWriter(writer);

      logger.info('info'); // Filtered by writer
      logger.warning('warning');

      expect(records.length, 1);
      expect(records[0].message, 'WARN: warning');
    });

    test('writer setMinLogLevel can be chained', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      writer.setMinLogLevel(ChirpLogLevel.error);
      writer.addInterceptor(_PrefixInterceptor('ERR: '));

      final logger = ChirpLogger(name: 'test').addWriter(writer);

      logger.warning('warning'); // Filtered
      logger.error('error');

      expect(records.length, 1);
      expect(records[0].message, 'ERR: error');
    });

    test('addContext merges context additively', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);

      final logger = ChirpLogger(name: 'test').addContext({'a': 1}).addContext(
          {'b': 2}).addContext({'a': 3}); // Override 'a'

      logger.addWriter(writer);
      logger.info('test');

      expect(records[0].data['a'], 3);
      expect(records[0].data['b'], 2);
    });
  });

  group('Interceptor requiresCallerInfo', () {
    test(
        'adding interceptor with requiresCallerInfo after writer is added to logger',
        () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test').addWriter(writer);

      // Log before adding interceptor - no caller info
      logger.info('before');
      expect(records[0].caller, isNull);

      // Add interceptor that requires caller info
      writer.addInterceptor(_CallerRequiringInterceptor());

      // Log after adding interceptor - should have caller info now
      logger.info('after');
      expect(records[1].caller, isNotNull);
    });

    test(
        'removing interceptor with requiresCallerInfo stops capturing caller info',
        () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final interceptor = _CallerRequiringInterceptor();
      writer.addInterceptor(interceptor);

      final logger = ChirpLogger(name: 'test').addWriter(writer);

      // Log with interceptor - has caller info
      logger.info('with interceptor');
      expect(records[0].caller, isNotNull);

      // Remove interceptor
      writer.removeInterceptor(interceptor);

      // Log without interceptor - no caller info
      logger.info('without interceptor');
      expect(records[1].caller, isNull);
    });

    test('child logger sees parent writer interceptor changes', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final parentLogger = ChirpLogger(name: 'parent').addWriter(writer);
      final childLogger = parentLogger.child(name: 'child');

      // Log before adding interceptor - no caller info
      childLogger.info('before');
      expect(records[0].caller, isNull);

      // Add interceptor to parent's writer
      writer.addInterceptor(_CallerRequiringInterceptor());

      // Child logger should now capture caller info
      childLogger.info('after');
      expect(records[1].caller, isNotNull);
    });

    test('adopted logger sees adopter writer interceptor changes', () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final rootLogger = ChirpLogger(name: 'root').addWriter(writer);
      final libraryLogger = ChirpLogger(name: 'library');

      rootLogger.adopt(libraryLogger);

      // Log before adding interceptor - no caller info
      libraryLogger.info('before');
      expect(records[0].caller, isNull);

      // Add interceptor to root's writer
      writer.addInterceptor(_CallerRequiringInterceptor());

      // Adopted logger should now capture caller info
      libraryLogger.info('after');
      expect(records[1].caller, isNotNull);
    });

    test(
        'adding logger interceptor with requiresCallerInfo triggers caller capture',
        () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final logger = ChirpLogger(name: 'test').addWriter(writer);

      // Log before adding interceptor - no caller info
      logger.info('before');
      expect(records[0].caller, isNull);

      // Add interceptor to logger that requires caller info
      logger.addInterceptor(_CallerRequiringInterceptor());

      // Log after adding interceptor - should have caller info now
      logger.info('after');
      expect(records[1].caller, isNotNull);
    });

    test(
        'removing logger interceptor with requiresCallerInfo stops caller capture',
        () {
      final records = <LogRecord>[];
      final writer = _TestWriter(records.add);
      final interceptor = _CallerRequiringInterceptor();
      final logger =
          ChirpLogger(name: 'test').addWriter(writer).addInterceptor(interceptor);

      // Log with interceptor - has caller info
      logger.info('with interceptor');
      expect(records[0].caller, isNotNull);

      // Remove interceptor
      logger.removeInterceptor(interceptor);

      // Log without interceptor - no caller info
      logger.info('without interceptor');
      expect(records[1].caller, isNull);
    });
  });
}

class _TestWriter extends ChirpWriter {
  final void Function(LogRecord) onWrite;

  _TestWriter(this.onWrite);

  @override
  bool get requiresCallerInfo => false;

  @override
  void write(LogRecord record) {
    onWrite(record);
  }
}

class _CallerTrackingWriter extends ChirpWriter {
  final void Function() onCallerCaptured;

  _CallerTrackingWriter(this.onCallerCaptured);

  @override
  bool get requiresCallerInfo => true;

  @override
  void write(LogRecord record) {
    if (record.caller != null) {
      onCallerCaptured();
    }
  }
}

class _PrefixInterceptor extends ChirpInterceptor {
  final String prefix;

  _PrefixInterceptor(this.prefix);

  @override
  LogRecord? intercept(LogRecord record) {
    return LogRecord(
      message: '$prefix${record.message}',
      level: record.level,
      error: record.error,
      stackTrace: record.stackTrace,
      caller: record.caller,
      skipFrames: record.skipFrames,
      timestamp: record.timestamp,
      zone: record.zone,
      loggerName: record.loggerName,
      instance: record.instance,
      data: record.data,
      formatOptions: record.formatOptions,
    );
  }
}

class _RejectInterceptor extends ChirpInterceptor {
  @override
  LogRecord? intercept(LogRecord record) => null;
}

class _CallerRequiringInterceptor extends ChirpInterceptor {
  @override
  bool get requiresCallerInfo => true;

  @override
  LogRecord? intercept(LogRecord record) => record;
}
