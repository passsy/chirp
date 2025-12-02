import 'dart:collection';

import 'package:chirp_protocol/chirp_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('Chirp static class', () {
    setUp(() {
      // Save original root logger
    });

    test('root property is mutable and can be reassigned', () {
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      final newRoot = ChirpLogger(name: 'NewRoot');
      Chirp.root = newRoot;

      expect(Chirp.root, same(newRoot));
      expect(Chirp.root.name, 'NewRoot');
    });

    test('root property starts with default ChirpLogger', () {
      expect(Chirp.root, isA<ChirpLogger>());
    });

    test('log() delegates to root logger', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      const customLevel = ChirpLogLevel('custom', 250);
      Chirp.log(
        'test message',
        level: customLevel,
        error: 'test error',
        data: {'key': 'value'},
      );

      expect(records.length, 1);
      expect(records[0].message, 'test message');
      expect(records[0].level, customLevel);
      expect(records[0].error, 'test error');
      expect(records[0].data?['key'], 'value');
    });

    test('trace() logs at trace level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.trace('trace message', data: {'foo': 'bar'});

      expect(records.length, 1);
      expect(records[0].message, 'trace message');
      expect(records[0].level, ChirpLogLevel.trace);
      expect(records[0].data?['foo'], 'bar');
    });

    test('debug() logs at debug level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.debug('debug message');

      expect(records.length, 1);
      expect(records[0].message, 'debug message');
      expect(records[0].level, ChirpLogLevel.debug);
    });

    test('info() logs at info level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.info('info message');

      expect(records.length, 1);
      expect(records[0].message, 'info message');
      expect(records[0].level, ChirpLogLevel.info);
    });

    test('notice() logs at notice level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.notice('notice message');

      expect(records.length, 1);
      expect(records[0].message, 'notice message');
      expect(records[0].level, ChirpLogLevel.notice);
    });

    test('warning() logs at warning level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.warning('warning message');

      expect(records.length, 1);
      expect(records[0].message, 'warning message');
      expect(records[0].level, ChirpLogLevel.warning);
    });

    test('error() logs at error level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final exception = Exception('test exception');
      final stackTrace = StackTrace.current;

      Chirp.error(
        'error message',
        error: exception,
        stackTrace: stackTrace,
      );

      expect(records.length, 1);
      expect(records[0].message, 'error message');
      expect(records[0].level, ChirpLogLevel.error);
      expect(records[0].error, exception);
      expect(records[0].stackTrace, stackTrace);
    });

    test('critical() logs at critical level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.critical('critical message');

      expect(records.length, 1);
      expect(records[0].message, 'critical message');
      expect(records[0].level, ChirpLogLevel.critical);
    });

    test('wtf() logs at wtf level', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      Chirp.wtf('wtf message');

      expect(records.length, 1);
      expect(records[0].message, 'wtf message');
      expect(records[0].level, ChirpLogLevel.wtf);
    });

    test('all log methods support error and stackTrace parameters', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final error = Exception('test');
      final stackTrace = StackTrace.current;

      Chirp.trace('msg', error: error, stackTrace: stackTrace);
      Chirp.debug('msg', error: error, stackTrace: stackTrace);
      Chirp.info('msg', error: error, stackTrace: stackTrace);
      Chirp.notice('msg', error: error, stackTrace: stackTrace);
      Chirp.warning('msg', error: error, stackTrace: stackTrace);
      Chirp.error('msg', error: error, stackTrace: stackTrace);
      Chirp.critical('msg', error: error, stackTrace: stackTrace);
      Chirp.wtf('msg', error: error, stackTrace: stackTrace);

      expect(records.length, 8);
      for (final record in records) {
        expect(record.error, error);
        expect(record.stackTrace, stackTrace);
      }
    });

    test('all log methods support data parameter', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final data = {'key': 'value', 'count': 42};

      Chirp.trace('msg', data: data);
      Chirp.debug('msg', data: data);
      Chirp.info('msg', data: data);
      Chirp.notice('msg', data: data);
      Chirp.warning('msg', data: data);
      Chirp.error('msg', data: data);
      Chirp.critical('msg', data: data);
      Chirp.wtf('msg', data: data);

      expect(records.length, 8);
      for (final record in records) {
        expect(record.data?['key'], 'value');
        expect(record.data?['count'], 42);
      }
    });

    test('all log methods support formatOptions parameter', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      const options = [FormatOptions()];

      Chirp.trace('msg', formatOptions: options);
      Chirp.debug('msg', formatOptions: options);
      Chirp.info('msg', formatOptions: options);
      Chirp.notice('msg', formatOptions: options);
      Chirp.warning('msg', formatOptions: options);
      Chirp.error('msg', formatOptions: options);
      Chirp.critical('msg', formatOptions: options);
      Chirp.wtf('msg', formatOptions: options);

      expect(records.length, 8);
      for (final record in records) {
        expect(record.formatOptions, options);
      }
    });
  });

  group('ChirpLogger constructor', () {
    test('creates logger with optional name', () {
      final logger = ChirpLogger(name: 'TestLogger');
      expect(logger.name, 'TestLogger');
    });

    test('creates logger without name', () {
      final logger = ChirpLogger();
      expect(logger.name, isNull);
    });

    test('instance property is null for regular constructor', () {
      final logger = ChirpLogger(name: 'Test');
      expect(logger.instance, isNull);
    });

    test('parent property is null for regular constructor', () {
      final logger = ChirpLogger(name: 'Test');
      expect(logger.parent, isNull);
    });

    test('context property is empty mutable map', () {
      final logger = ChirpLogger(name: 'Test');
      expect(logger.context, isEmpty);
      expect(logger.context, isA<Map<String, Object?>>());

      // Verify it's mutable
      logger.context['key'] = 'value';
      expect(logger.context['key'], 'value');
    });

    test('writers list is initially empty', () {
      final logger = ChirpLogger(name: 'Test');
      expect(logger.writers, isEmpty);
    });
  });

  group('ChirpLogger properties', () {
    test('name property is final', () {
      final logger = ChirpLogger(name: 'Original');
      expect(logger.name, 'Original');
      // Cannot reassign final property - would cause compile error
    });

    test('instance property is final', () {
      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);
      expect(logger.instance, same(instance));
      // Cannot reassign final property - would cause compile error
    });

    test('parent property is final', () {
      final parent = ChirpLogger(name: 'Parent');
      final child = parent.child();
      expect(child.parent, same(parent));
      // Cannot reassign final property - would cause compile error
    });

    test('context property is mutable map', () {
      final logger = ChirpLogger(name: 'Test');

      logger.context['key1'] = 'value1';
      expect(logger.context['key1'], 'value1');

      logger.context['key2'] = 42;
      expect(logger.context['key2'], 42);

      logger.context['key1'] = 'updated';
      expect(logger.context['key1'], 'updated');
    });

    test('writers list is unmodifiable view', () {
      final logger = ChirpLogger();
      final writer = FakeWriter([]);

      logger.addWriter(writer);

      expect(logger.writers, hasLength(1));
      expect(logger.writers, isA<UnmodifiableListView>());

      // Attempting to modify would throw at runtime
      expect(
        () => (logger.writers as List).add(FakeWriter([])),
        throwsUnsupportedError,
      );
    });
  });

  group('ChirpLogger addWriter/removeWriter', () {
    test('addWriter adds writer to list', () {
      final logger = ChirpLogger();
      final writer1 = FakeWriter([]);
      final writer2 = FakeWriter([]);

      expect(logger.writers, isEmpty);

      logger.addWriter(writer1);
      expect(logger.writers, hasLength(1));
      expect(logger.writers, contains(writer1));

      logger.addWriter(writer2);
      expect(logger.writers, hasLength(2));
      expect(logger.writers, contains(writer2));
    });

    test('addWriter ignores duplicate writers', () {
      final logger = ChirpLogger();
      final writer = FakeWriter([]);

      logger.addWriter(writer);
      logger.addWriter(writer);
      logger.addWriter(writer);

      expect(logger.writers, hasLength(1));
    });

    test('removeWriter removes writer from list', () {
      final logger = ChirpLogger();
      final writer1 = FakeWriter([]);
      final writer2 = FakeWriter([]);

      logger.addWriter(writer1);
      logger.addWriter(writer2);
      expect(logger.writers, hasLength(2));

      final removed = logger.removeWriter(writer1);
      expect(removed, isTrue);
      expect(logger.writers, hasLength(1));
      expect(logger.writers, contains(writer2));
      expect(logger.writers, isNot(contains(writer1)));
    });

    test('removeWriter returns false when writer not found', () {
      final logger = ChirpLogger();
      final writer1 = FakeWriter([]);
      final writer2 = FakeWriter([]);

      logger.addWriter(writer1);

      final removed = logger.removeWriter(writer2);
      expect(removed, isFalse);
      expect(logger.writers, hasLength(1));
    });

    test('removeWriter returns false on empty list', () {
      final logger = ChirpLogger();
      final writer = FakeWriter([]);

      final removed = logger.removeWriter(writer);
      expect(removed, isFalse);
    });
  });

  group('ChirpLogger logging methods', () {
    test('log() creates record with all parameters', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger(name: 'TestLogger')
        ..addWriter(FakeWriter(records));

      const customLevel = ChirpLogLevel('custom', 250);
      final error = Exception('test');
      final stackTrace = StackTrace.current;
      const options = [FormatOptions()];

      logger.log(
        'test message',
        level: customLevel,
        error: error,
        stackTrace: stackTrace,
        data: {'key': 'value'},
        formatOptions: options,
        skipFrames: 2,
      );

      expect(records.length, 1);
      final record = records[0];
      expect(record.message, 'test message');
      expect(record.level, customLevel);
      expect(record.error, error);
      expect(record.stackTrace, stackTrace);
      expect(record.data?['key'], 'value');
      expect(record.formatOptions, options);
      expect(record.skipFrames, 2);
      expect(record.loggerName, 'TestLogger');
    });

    test('log() defaults to info level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.log('message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.info);
    });

    test('trace() logs at trace level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger(name: 'Test')..addWriter(FakeWriter(records));

      logger.trace('trace message', data: {'foo': 'bar'});

      expect(records.length, 1);
      expect(records[0].message, 'trace message');
      expect(records[0].level, ChirpLogLevel.trace);
      expect(records[0].loggerName, 'Test');
    });

    test('debug() logs at debug level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.debug('debug message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.debug);
    });

    test('info() logs at info level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info('info message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.info);
    });

    test('notice() logs at notice level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.notice('notice message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.notice);
    });

    test('warning() logs at warning level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.warning('warning message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.warning);
    });

    test('error() logs at error level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      final exception = Exception('error');
      final stackTrace = StackTrace.current;

      logger.error('error message', error: exception, stackTrace: stackTrace);

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.error);
      expect(records[0].error, exception);
      expect(records[0].stackTrace, stackTrace);
    });

    test('critical() logs at critical level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.critical('critical message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.critical);
    });

    test('wtf() logs at wtf level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.wtf('wtf message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.wtf);
    });

    test('all logging methods include caller stacktrace', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.trace('msg');
      logger.debug('msg');
      logger.info('msg');
      logger.notice('msg');
      logger.warning('msg');
      logger.error('msg');
      logger.critical('msg');
      logger.wtf('msg');

      expect(records.length, 8);
      for (final record in records) {
        expect(record.caller, isNotNull);
        expect(record.caller.toString(), contains('chirp_logger_test.dart'));
      }
    });

    test('logging methods merge context with data', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()
        ..context['global'] = 'globalValue'
        ..context['override'] = 'original'
        ..addWriter(FakeWriter(records));

      logger.info('msg', data: {'local': 'localValue', 'override': 'new'});

      expect(records.length, 1);
      expect(records[0].data?['global'], 'globalValue');
      expect(records[0].data?['local'], 'localValue');
      expect(records[0].data?['override'], 'new'); // Override takes precedence
    });

    test('logging with empty context and no data creates null data field', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info('msg');

      expect(records.length, 1);
      expect(records[0].data, isNull);
    });

    test('logging with context but no data uses context', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()
        ..context['key'] = 'value'
        ..addWriter(FakeWriter(records));

      logger.info('msg');

      expect(records.length, 1);
      expect(records[0].data, isNotNull);
      expect(records[0].data?['key'], 'value');
    });

    test('multiple writers all receive the log record', () {
      final records1 = <LogRecord>[];
      final records2 = <LogRecord>[];
      final records3 = <LogRecord>[];

      final logger = ChirpLogger()
        ..addWriter(FakeWriter(records1))
        ..addWriter(FakeWriter(records2))
        ..addWriter(FakeWriter(records3));

      logger.info('test message');

      expect(records1.length, 1);
      expect(records2.length, 1);
      expect(records3.length, 1);

      expect(records1[0].message, 'test message');
      expect(records2[0].message, 'test message');
      expect(records3[0].message, 'test message');
    });
  });

  group('ChirpLogger child()', () {
    test('creates child with parent reference', () {
      final parent = ChirpLogger(name: 'Parent');
      final child = parent.child();

      expect(child.parent, same(parent));
    });

    test('child inherits parent name by default', () {
      final parent = ChirpLogger(name: 'Parent');
      final child = parent.child();

      expect(child.name, 'Parent');
    });

    test('child can override parent name', () {
      final parent = ChirpLogger(name: 'Parent');
      final child = parent.child(name: 'Child');

      expect(child.name, 'Child');
    });

    test('child inherits parent instance by default', () {
      final instance = Object();
      final parent = ChirpLogger.forInstance(instance);
      final child = parent.child();

      expect(child.instance, same(instance));
    });

    test('child can override parent instance', () {
      final instance1 = Object();
      final instance2 = Object();
      final parent = ChirpLogger.forInstance(instance1);
      final child = parent.child(instance: instance2);

      expect(child.instance, same(instance2));
    });

    test('child inherits parent context', () {
      final parent = ChirpLogger()..context['parentKey'] = 'parentValue';
      final child = parent.child();

      expect(child.context['parentKey'], 'parentValue');
    });

    test('child context can extend parent context', () {
      final parent = ChirpLogger()..context['parentKey'] = 'parentValue';
      final child = parent.child(context: {'childKey': 'childValue'});

      expect(child.context['parentKey'], 'parentValue');
      expect(child.context['childKey'], 'childValue');
    });

    test('child context can override parent context values', () {
      final parent = ChirpLogger()..context['key'] = 'parentValue';
      final child = parent.child(context: {'key': 'childValue'});

      expect(child.context['key'], 'childValue');
    });

    test('child inherits parent writers', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger()..addWriter(FakeWriter(records));
      final child = parent.child();

      child.info('test message');

      expect(records.length, 1);
      expect(records[0].message, 'test message');
    });

    test('child can have additional writers', () {
      final parentRecords = <LogRecord>[];
      final childRecords = <LogRecord>[];

      final parent = ChirpLogger()..addWriter(FakeWriter(parentRecords));
      final child = parent.child()..addWriter(FakeWriter(childRecords));

      child.info('test message');

      expect(parentRecords.length, 1);
      expect(childRecords.length, 1);
    });

    test('parent does not receive child-only writer logs', () {
      final parentRecords = <LogRecord>[];
      final childRecords = <LogRecord>[];

      final parent = ChirpLogger()..addWriter(FakeWriter(parentRecords));
      final child = parent.child()..addWriter(FakeWriter(childRecords));

      parent.info('parent message');

      expect(parentRecords.length, 1);
      expect(childRecords.length, 0); // Child writer doesn't see parent logs
    });

    test('child context is isolated from parent mutations', () {
      final parent = ChirpLogger()..context['key'] = 'original';
      final child = parent.child();

      parent.context['key'] = 'modified';

      expect(parent.context['key'], 'modified');
      expect(child.context['key'], 'original');
    });

    test('multi-level child hierarchy inherits correctly', () {
      final records = <LogRecord>[];

      final grandparent = ChirpLogger(name: 'GP')
        ..context['gp'] = 'gpValue'
        ..addWriter(FakeWriter(records));

      final parent = grandparent.child(
        name: 'P',
        context: {'p': 'pValue'},
      );

      final child = parent.child(
        name: 'C',
        context: {'c': 'cValue'},
      );

      child.info('test');

      expect(records.length, 1);
      expect(records[0].loggerName, 'C');
      expect(records[0].data?['gp'], 'gpValue');
      expect(records[0].data?['p'], 'pValue');
      expect(records[0].data?['c'], 'cValue');
    });
  });

  group('ChirpLogger.forInstance', () {
    test('creates logger with instance reference', () {
      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);

      expect(logger.instance, same(instance));
    });

    test('caches logger for same instance', () {
      final instance = Object();
      final logger1 = ChirpLogger.forInstance(instance);
      final logger2 = ChirpLogger.forInstance(instance);

      expect(logger1, same(logger2));
    });

    test('returns different loggers for different instances', () {
      final instance1 = Object();
      final instance2 = Object();
      final logger1 = ChirpLogger.forInstance(instance1);
      final logger2 = ChirpLogger.forInstance(instance2);

      expect(logger1, isNot(same(logger2)));
      expect(logger1.instance, same(instance1));
      expect(logger2.instance, same(instance2));
    });

    test('instance logger has null name', () {
      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);

      expect(logger.name, isNull);
    });

    test('instance logger has null parent', () {
      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);

      expect(logger.parent, isNull);
    });

    test('instance logger has empty context', () {
      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);

      expect(logger.context, isEmpty);
    });

    test('instance logger dynamically delegates to Chirp.root', () {
      final records1 = <LogRecord>[];
      final records2 = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records1));

      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);

      logger.info('message 1');
      expect(records1.length, 1);
      expect(records2.length, 0);

      // Replace root
      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records2));

      logger.info('message 2');
      expect(records1.length, 1); // Old root not called
      expect(records2.length, 1); // New root called
    });

    test('instance logger includes instance in log records', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final instance = TestObject();
      final logger = ChirpLogger.forInstance(instance);

      logger.info('test message');

      expect(records.length, 1);
      expect(records[0].instance, same(instance));
    });

    test('instance logger writers combine with root writers', () {
      final rootRecords = <LogRecord>[];
      final instanceRecords = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(rootRecords));

      final instance = Object();
      final logger = ChirpLogger.forInstance(instance)
        ..addWriter(FakeWriter(instanceRecords));

      logger.info('test');

      expect(rootRecords.length, 1);
      expect(instanceRecords.length, 1);
    });
  });

  group('ChirpObjectExt', () {
    test('provides chirp getter on any object', () {
      final obj = TestObject();
      expect(obj.chirp, isA<ChirpLogger>());
    });

    test('chirp getter returns same logger on repeated access', () {
      final obj = TestObject();
      final logger1 = obj.chirp;
      final logger2 = obj.chirp;

      expect(logger1, same(logger2));
    });

    test('chirp getter returns different loggers for different objects', () {
      final obj1 = TestObject();
      final obj2 = TestObject();

      expect(obj1.chirp, isNot(same(obj2.chirp)));
    });

    test('chirp logger includes instance in log records', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final obj = TestObject();
      obj.chirp.info('test message');

      expect(records.length, 1);
      expect(records[0].instance, same(obj));
      expect(records[0].message, 'test message');
    });

    test('chirp logger delegates to current Chirp.root', () {
      final records1 = <LogRecord>[];
      final records2 = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records1));

      final obj = TestObject();
      obj.chirp.info('message 1');

      expect(records1.length, 1);
      expect(records2.length, 0);

      // Replace root
      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records2));

      obj.chirp.info('message 2');

      expect(records1.length, 1);
      expect(records2.length, 1);
    });

    test('chirp works with built-in types', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final list = <int>[1, 2, 3];
      list.chirp.info('list logging');

      expect(records.length, 1);
      expect(records[0].instance, same(list));
    });

    test('chirp extension works in class methods', () {
      final records = <LogRecord>[];
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      Chirp.root = ChirpLogger()..addWriter(FakeWriter(records));

      final service = TestService();
      service.doSomething();

      expect(records.length, 1);
      expect(records[0].message, 'doing something');
      expect(records[0].instance, same(service));
    });
  });

  group('ChirpLogger API stability tests', () {
    test('name property is final and cannot be changed', () {
      final logger = ChirpLogger(name: 'Original');
      // This test verifies the API contract - name should be final
      expect(logger.name, 'Original');
    });

    test('instance property is final and cannot be changed', () {
      final instance = Object();
      final logger = ChirpLogger.forInstance(instance);
      // This test verifies the API contract - instance should be final
      expect(logger.instance, same(instance));
    });

    test('parent property is final and cannot be changed', () {
      final parent = ChirpLogger();
      final child = parent.child();
      // This test verifies the API contract - parent should be final
      expect(child.parent, same(parent));
    });

    test('context property is mutable and can be modified', () {
      final logger = ChirpLogger();
      // This test verifies the API contract - context should be mutable
      logger.context['key'] = 'value';
      expect(logger.context['key'], 'value');
    });

    test('writers getter returns unmodifiable list', () {
      final logger = ChirpLogger()..addWriter(FakeWriter([]));
      // This test verifies the API contract - writers should be read-only
      expect(logger.writers, isA<UnmodifiableListView>());
    });

    test('Chirp.root is reassignable', () {
      final originalRoot = Chirp.root;
      addTearDown(() => Chirp.root = originalRoot);

      final newRoot = ChirpLogger();
      Chirp.root = newRoot;
      expect(Chirp.root, same(newRoot));
    });
  });

  group('Edge cases', () {
    test('logging null message', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info(null);

      expect(records.length, 1);
      expect(records[0].message, isNull);
    });

    test('logging non-string message', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info(42);
      logger.info(true);
      logger.info([1, 2, 3]);

      expect(records.length, 3);
      expect(records[0].message, 42);
      expect(records[1].message, true);
      expect(records[2].message, isA<List>());
    });

    test('removing same writer multiple times', () {
      final logger = ChirpLogger();
      final writer = FakeWriter([]);

      logger.addWriter(writer);
      expect(logger.writers, hasLength(1));

      expect(logger.removeWriter(writer), isTrue);
      expect(logger.writers, isEmpty);

      expect(logger.removeWriter(writer), isFalse);
      expect(logger.removeWriter(writer), isFalse);
    });

    test('child of child inherits all writers', () {
      final records = <LogRecord>[];

      final grandparent = ChirpLogger()..addWriter(FakeWriter(records));
      final parent = grandparent.child();
      final child = parent.child();

      child.info('test');

      expect(records.length, 1);
    });

    test('empty data maps are handled correctly', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info('msg', data: {});

      expect(records.length, 1);
      // Empty map is returned as-is (not null) when passed explicitly
      expect(records[0].data, {});
    });

    test('context with empty override data', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()
        ..context['key'] = 'value'
        ..addWriter(FakeWriter(records));

      logger.info('msg', data: {});

      expect(records.length, 1);
      expect(records[0].data, isNotNull);
      expect(records[0].data?['key'], 'value');
    });
  });
}

/// Fake writer implementation for testing.
class FakeWriter implements ChirpWriter {
  final List<LogRecord> records;

  FakeWriter(this.records);

  @override
  void write(LogRecord record) {
    records.add(record);
  }
}

/// Test object for instance logging tests.
class TestObject {}

/// Test service with chirp usage.
class TestService {
  void doSomething() {
    chirp.info('doing something');
  }
}
