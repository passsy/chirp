import 'dart:collection';

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
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
      final logger = ChirpLogger().child(instance: instance);
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
      final logger =
          ChirpLogger(name: 'TestLogger').addWriter(FakeWriter(records));

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
      expect(record.data['key'], 'value');
      expect(record.formatOptions, options);
      expect(record.skipFrames, 2);
      expect(record.loggerName, 'TestLogger');
    });

    test('log() defaults to info level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.log('message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.info);
    });

    test('trace() logs at trace level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger(name: 'Test').addWriter(FakeWriter(records));

      logger.trace('trace message', data: {'foo': 'bar'});

      expect(records.length, 1);
      expect(records[0].message, 'trace message');
      expect(records[0].level, ChirpLogLevel.trace);
      expect(records[0].loggerName, 'Test');
    });

    test('debug() logs at debug level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.debug('debug message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.debug);
    });

    test('info() logs at info level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.info('info message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.info);
    });

    test('notice() logs at notice level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.notice('notice message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.notice);
    });

    test('warning() logs at warning level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.warning('warning message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.warning);
    });

    test('error() logs at error level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

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
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.critical('critical message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.critical);
    });

    test('wtf() logs at wtf level', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.wtf('wtf message');

      expect(records.length, 1);
      expect(records[0].level, ChirpLogLevel.wtf);
    });

    test(
        'all logging methods include caller stacktrace when writer requires it',
        () {
      final records = <LogRecord>[];
      final logger =
          ChirpLogger().addWriter(FakeWriterRequiringCallerInfo(records));

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

    test('caller is null when no writer requires it', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.info('msg');

      expect(records.length, 1);
      expect(records[0].caller, isNull);
    });

    test('logging methods merge context with data', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger();
      logger.context['global'] = 'globalValue';
      logger.context['override'] = 'original';
      logger.addWriter(FakeWriter(records));

      logger.info('msg', data: {'local': 'localValue', 'override': 'new'});

      expect(records.length, 1);
      expect(records[0].data['global'], 'globalValue');
      expect(records[0].data['local'], 'localValue');
      expect(records[0].data['override'], 'new'); // Override takes precedence
    });

    test('logging with empty context and no data creates empty data field', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.info('msg');

      expect(records.length, 1);
      expect(records[0].data, isEmpty); // LogRecord.data defaults to {}
    });

    test('logging with context but no data uses context', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger();
      logger.context['key'] = 'value';
      logger.addWriter(FakeWriter(records));

      logger.info('msg');

      expect(records.length, 1);
      expect(records[0].data, isNotNull);
      expect(records[0].data['key'], 'value');
    });

    test('multiple writers all receive the log record', () {
      final records1 = <LogRecord>[];
      final records2 = <LogRecord>[];
      final records3 = <LogRecord>[];

      final logger = ChirpLogger()
          .addWriter(FakeWriter(records1))
          .addWriter(FakeWriter(records2))
          .addWriter(FakeWriter(records3));

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
      final parent = ChirpLogger().child(instance: instance);
      final child = parent.child();

      expect(child.instance, same(instance));
    });

    test('child can override parent instance', () {
      final instance1 = Object();
      final instance2 = Object();
      final parent = ChirpLogger().child(instance: instance1);
      final child = parent.child(instance: instance2);

      expect(child.instance, same(instance2));
    });

    test('child inherits parent context at log time', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger();
      parent.context['parentKey'] = 'parentValue';
      parent.addWriter(FakeWriter(records));
      final child = parent.child();

      // Child's own context doesn't contain parent key
      expect(child.context['parentKey'], isNull);

      // But when logging, parent context is included
      child.info('test');
      expect(records[0].data['parentKey'], 'parentValue');
    });

    test('child context can extend parent context at log time', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger();
      parent.context['parentKey'] = 'parentValue';
      parent.addWriter(FakeWriter(records));
      final child = parent.child(context: {'childKey': 'childValue'});

      child.info('test');
      expect(records[0].data['parentKey'], 'parentValue');
      expect(records[0].data['childKey'], 'childValue');
    });

    test('child context can override parent context values', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger();
      parent.context['key'] = 'parentValue';
      parent.addWriter(FakeWriter(records));
      final child = parent.child(context: {'key': 'childValue'});

      child.info('test');
      expect(records[0].data['key'], 'childValue');
    });

    test('child inherits parent writers', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger().addWriter(FakeWriter(records));
      final child = parent.child();

      child.info('test message');

      expect(records.length, 1);
      expect(records[0].message, 'test message');
    });

    test('child writers are ignored - only parent writers are used', () {
      final parentRecords = <LogRecord>[];
      final childRecords = <LogRecord>[];

      final parent = ChirpLogger().addWriter(FakeWriter(parentRecords));
      final child = parent.child().addWriter(FakeWriter(childRecords));

      child.info('test message');

      // Only parent's writer receives logs (child's writer is ignored)
      expect(parentRecords.length, 1);
      expect(childRecords.length, 0);
    });

    test('child sees parent context mutations at log time', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger();
      parent.context['key'] = 'original';
      parent.addWriter(FakeWriter(records));
      final child = parent.child();

      // Mutate parent context after child creation
      parent.context['key'] = 'modified';

      // Child sees the modified value at log time
      child.info('test');
      expect(records[0].data['key'], 'modified');
    });

    test('multi-level child hierarchy inherits correctly', () {
      final records = <LogRecord>[];

      final grandparent = ChirpLogger(name: 'GP');
      grandparent.context['gp'] = 'gpValue';
      grandparent.addWriter(FakeWriter(records));

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
      expect(records[0].data['gp'], 'gpValue');
      expect(records[0].data['p'], 'pValue');
      expect(records[0].data['c'], 'cValue');
    });
  });

  group('ChirpLogger API stability tests', () {
    test('name property is final and cannot be changed', () {
      final logger = ChirpLogger(name: 'Original');
      // This test verifies the API contract - name should be final
      expect(logger.name, 'Original');
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
      final logger = ChirpLogger().addWriter(FakeWriter([]));
      // This test verifies the API contract - writers should be read-only
      expect(logger.writers, isA<UnmodifiableListView>());
    });
  });

  group('Edge cases', () {
    test('logging null message', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.info(null);

      expect(records.length, 1);
      expect(records[0].message, isNull);
    });

    test('logging non-string message', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

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

      final grandparent = ChirpLogger().addWriter(FakeWriter(records));
      final parent = grandparent.child();
      final child = parent.child();

      child.info('test');

      expect(records.length, 1);
    });

    test('empty data maps are handled correctly', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger().addWriter(FakeWriter(records));

      logger.info('msg', data: {});

      expect(records.length, 1);
      // Empty map is returned as-is (not null) when passed explicitly
      expect(records[0].data, {});
    });

    test('context with empty override data', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger();
      logger.context['key'] = 'value';
      logger.addWriter(FakeWriter(records));

      logger.info('msg', data: {});

      expect(records.length, 1);
      expect(records[0].data, isNotNull);
      expect(records[0].data['key'], 'value');
    });
  });

  group('ChirpLogger addInterceptor/removeInterceptor', () {
    test('addInterceptor adds interceptor to list', () {
      final logger = ChirpLogger();
      final interceptor = FakeInterceptor();

      expect(logger.interceptors, isEmpty);

      logger.addInterceptor(interceptor);
      expect(logger.interceptors, hasLength(1));
      expect(logger.interceptors, contains(interceptor));
    });

    test('removeInterceptor removes interceptor from list', () {
      final logger = ChirpLogger();
      final interceptor = FakeInterceptor();

      logger.addInterceptor(interceptor);
      expect(logger.interceptors, hasLength(1));

      final removed = logger.removeInterceptor(interceptor);
      expect(removed, isTrue);
      expect(logger.interceptors, isEmpty);
    });

    test('removeInterceptor returns false when interceptor not found', () {
      final logger = ChirpLogger();
      final result = logger.removeInterceptor(FakeInterceptor());
      expect(result, isFalse);
    });

    test('interceptors list is unmodifiable', () {
      final logger = ChirpLogger();
      expect(
        () => logger.interceptors.add(FakeInterceptor()),
        throwsUnsupportedError,
      );
    });

    test('interceptor requiresCallerInfo triggers caller capture', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()
          .addInterceptor(FakeInterceptorRequiringCallerInfo())
          .addWriter(FakeWriter(records));

      logger.info('test');

      expect(records, hasLength(1));
      expect(records[0].caller, isNotNull);
      expect(records[0].caller.toString(), contains('chirp_logger_test.dart'));
    });

    test('removing interceptor that requires caller info stops capture', () {
      final records = <LogRecord>[];
      final interceptor = FakeInterceptorRequiringCallerInfo();
      final logger = ChirpLogger()
          .addInterceptor(interceptor)
          .addWriter(FakeWriter(records));

      logger.info('with interceptor');
      expect(records[0].caller, isNotNull);

      logger.removeInterceptor(interceptor);
      logger.info('without interceptor');
      expect(records[1].caller, isNull);
    });

    test('writer interceptor requiresCallerInfo triggers caller capture', () {
      final records = <LogRecord>[];
      final writer = FakeWriter(records)
          .addInterceptor(FakeInterceptorRequiringCallerInfo());
      final logger = ChirpLogger().addWriter(writer);

      logger.info('test');

      expect(records, hasLength(1));
      expect(records[0].caller, isNotNull);
      expect(records[0].caller.toString(), contains('chirp_logger_test.dart'));
    });

    test('removing writer interceptor that requires caller info stops capture',
        () {
      final records = <LogRecord>[];
      final interceptor = FakeInterceptorRequiringCallerInfo();
      final writer = FakeWriter(records).addInterceptor(interceptor);
      final logger = ChirpLogger().addWriter(writer);

      logger.info('with writer interceptor');
      expect(records[0].caller, isNotNull);

      writer.removeInterceptor(interceptor);
      logger.info('without writer interceptor');
      expect(records[1].caller, isNull);
    });
  });

  group('ChirpLogger setMinLogLevel', () {
    test('setMinLogLevel sets minLogLevel', () {
      final logger = ChirpLogger();
      expect(logger.minLogLevel, isNull);

      logger.setMinLogLevel(ChirpLogLevel.warning);
      expect(logger.minLogLevel, ChirpLogLevel.warning);

      logger.setMinLogLevel(null);
      expect(logger.minLogLevel, isNull);
    });
  });

  group('ChirpLogger addContext', () {
    test('addContext adds entries to context', () {
      final logger = ChirpLogger();
      logger.addContext({'key': 'value', 'nullKey': null});

      expect(logger.context['key'], 'value');
      expect(logger.context.containsKey('nullKey'), isTrue);
    });
  });

  group('ChirpLogger orphan()', () {
    test('orphan removes parent reference', () {
      final parent = ChirpLogger(name: 'parent');
      final child = parent.child(name: 'child');

      expect(child.parent, same(parent));
      child.orphan();
      expect(child.parent, isNull);
    });

    test('orphan logger uses own writers again', () {
      final parentRecords = <LogRecord>[];
      final ownRecords = <LogRecord>[];

      final parent = ChirpLogger().addWriter(FakeWriter(parentRecords));
      final orphan = ChirpLogger().addWriter(FakeWriter(ownRecords));

      parent.adopt(orphan);
      orphan.info('while adopted');
      expect(parentRecords, hasLength(1));
      expect(ownRecords, hasLength(0));

      orphan.orphan();
      orphan.info('after orphan');
      expect(ownRecords, hasLength(1));
      expect(ownRecords[0].message, 'after orphan');
    });

    test('orphan logger loses parent context', () {
      final ownRecords = <LogRecord>[];
      final parent = ChirpLogger();
      parent.context['parentKey'] = 'parentValue';
      parent.addWriter(FakeWriter([]));

      final orphan = ChirpLogger().addWriter(FakeWriter(ownRecords));
      orphan.context['orphanKey'] = 'orphanValue';

      parent.adopt(orphan);
      orphan.orphan();
      orphan.info('test');

      expect(ownRecords[0].data['orphanKey'], 'orphanValue');
      expect(ownRecords[0].data.containsKey('parentKey'), isFalse);
    });

    test('orphan can be adopted by new parent', () {
      final records = <LogRecord>[];

      final parent1 = ChirpLogger(name: 'parent1');
      final parent2 =
          ChirpLogger(name: 'parent2').addWriter(FakeWriter(records));

      final orphan = ChirpLogger(name: 'orphan');

      parent1.adopt(orphan);
      orphan.orphan();
      parent2.adopt(orphan);

      orphan.info('adopted by parent2');
      expect(records, hasLength(1));
    });
  });

  test('all chainable methods can be chained together', () {
    final records = <LogRecord>[];
    final logger = ChirpLogger(name: 'test')
        .setMinLogLevel(ChirpLogLevel.trace)
        .addInterceptor(FakeInterceptor())
        .addWriter(FakeWriter(records))
        .addContext({'env': 'test'}).adopt(ChirpLogger(name: 'orphan'));

    expect(logger, isA<ChirpLogger>());
    expect(logger.minLogLevel, ChirpLogLevel.trace);
    expect(logger.interceptors.length, 1);
    expect(logger.writers.length, 1);
    expect(logger.context['env'], 'test');
  });

  group('ChirpLogger adopt()', () {
    test('adopted logger inherits parent writers', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger(name: 'parent').addWriter(FakeWriter(records));
      final orphan = ChirpLogger(name: 'orphan');

      // Before adoption - orphan is silent
      orphan.info('before adoption');
      expect(records, isEmpty);

      // Adopt the orphan
      parent.adopt(orphan);

      // After adoption - orphan logs through parent's writers
      orphan.info('after adoption');
      expect(records, hasLength(1));
      expect(records[0].message, 'after adoption');
      expect(records[0].loggerName, 'orphan');
    });

    test('adopted logger keeps its own name', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger(name: 'parent').addWriter(FakeWriter(records));
      final orphan = ChirpLogger(name: 'library_logger');

      parent.adopt(orphan);
      orphan.info('test');

      expect(records[0].loggerName, 'library_logger');
    });

    test('adopted logger inherits parent context at log time', () {
      final records = <LogRecord>[];
      final parent = ChirpLogger(name: 'parent');
      parent.context['parentKey'] = 'parentValue';
      parent.addWriter(FakeWriter(records));
      final orphan = ChirpLogger(name: 'orphan');
      orphan.context['orphanKey'] = 'orphanValue';

      parent.adopt(orphan);
      orphan.info('test');

      // Adopted logger inherits parent context (same as child())
      expect(records[0].data['orphanKey'], 'orphanValue');
      expect(records[0].data['parentKey'], 'parentValue');
    });

    test('adopted logger own writers are ignored after adoption', () {
      final parentRecords = <LogRecord>[];
      final orphanRecords = <LogRecord>[];

      final parent = ChirpLogger().addWriter(FakeWriter(parentRecords));
      final orphan = ChirpLogger().addWriter(FakeWriter(orphanRecords));

      // Before adoption, orphan uses its own writer
      orphan.info('before');
      expect(orphanRecords, hasLength(1));
      expect(parentRecords, hasLength(0));

      parent.adopt(orphan);
      orphan.info('after');

      // After adoption, only parent's writer is used (orphan's writer ignored)
      expect(parentRecords, hasLength(1));
      expect(orphanRecords, hasLength(1)); // Still 1 from before adoption
    });

    test('throws StateError when adopting logger that already has parent', () {
      final parent1 = ChirpLogger(name: 'parent1');
      final parent2 = ChirpLogger(name: 'parent2');
      final orphan = ChirpLogger(name: 'orphan');

      parent1.adopt(orphan);

      expect(
        () => parent2.adopt(orphan),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already has a parent'),
        )),
      );
    });

    test('throws StateError when adopting same logger twice', () {
      final parent = ChirpLogger(name: 'parent');
      final orphan = ChirpLogger(name: 'orphan');

      parent.adopt(orphan);

      expect(
        () => parent.adopt(orphan),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when adopting child logger', () {
      final parent = ChirpLogger(name: 'parent');
      final child = parent.child(name: 'child');
      final adopter = ChirpLogger(name: 'adopter');

      // Child already has a parent, so it cannot be adopted
      expect(
        () => adopter.adopt(child),
        throwsA(isA<StateError>()),
      );
    });

    test('adopted logger with children - children also get writers', () {
      final records = <LogRecord>[];
      final adopter =
          ChirpLogger(name: 'adopter').addWriter(FakeWriter(records));

      final libraryLogger = ChirpLogger(name: 'library');
      final libraryChild = libraryLogger.child(name: 'library.sub');

      // Adopt the library logger
      adopter.adopt(libraryLogger);

      // Child of adopted logger also gets the writers through the chain
      libraryChild.info('from child');
      expect(records, hasLength(1));
      expect(records[0].loggerName, 'library.sub');
    });

    test('parent getter returns the adopting parent', () {
      final parent = ChirpLogger(name: 'parent');
      final orphan = ChirpLogger(name: 'orphan');

      expect(orphan.parent, isNull);

      parent.adopt(orphan);

      expect(orphan.parent, same(parent));
    });

    test('effectiveRequiresCallerInfo propagates through adoption', () {
      final records = <LogRecord>[];
      final parent =
          ChirpLogger().addWriter(FakeWriterRequiringCallerInfo(records));
      final orphan = ChirpLogger();

      parent.adopt(orphan);
      orphan.info('test');

      // The caller should be captured because parent's writer requires it
      expect(records[0].caller, isNotNull);
    });

    test('orphan logger without writers is silent until adopted', () {
      final records = <LogRecord>[];
      final orphan = ChirpLogger(name: 'orphan');

      // Silent - no writers
      orphan.info('silent');

      final parent = ChirpLogger().addWriter(FakeWriter(records));
      parent.adopt(orphan);

      // Now it logs
      orphan.info('audible');
      expect(records, hasLength(1));
      expect(records[0].message, 'audible');
    });

    test(
        'adopted logger should NOT capture caller info when parent writer does not require it',
        () {
      // Bug scenario:
      // 1. Library logger has a writer that requires caller info (for standalone use)
      // 2. App root has a writer that does NOT require caller info
      // 3. App adopts the library logger
      // 4. After adoption, _effectiveWriters uses ONLY parent's writers
      // 5. So caller info should NOT be captured (parent's writer doesn't need it)

      final parentRecords = <LogRecord>[];
      final orphanRecords = <LogRecord>[];

      // Parent with simple writer (no caller info needed)
      final parent = ChirpLogger().addWriter(FakeWriter(parentRecords));

      // Orphan with writer that requires caller info (e.g., for standalone debugging)
      final orphan =
          ChirpLogger().addWriter(FakeWriterRequiringCallerInfo(orphanRecords));

      // Before adoption - orphan uses its own writer, caller info IS captured
      orphan.info('before adoption');
      expect(orphanRecords, hasLength(1));
      expect(orphanRecords[0].caller, isNotNull,
          reason:
              'Before adoption, orphan uses its own writer which requires caller info');

      // Adopt the orphan
      parent.adopt(orphan);

      // After adoption - orphan's writer is IGNORED, only parent's writer is used
      // Parent's writer does NOT require caller info, so caller should be null
      orphan.info('after adoption');
      expect(parentRecords, hasLength(1));
      expect(parentRecords[0].caller, isNull,
          reason:
              'After adoption, only parent writers are used. Parent writer does not require caller info, so StackTrace.current should NOT be captured');
    });
  });

  group('lazy message', () {
    test('lambda is resolved when level passes', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info(() => 'lazy message');

      expect(records, hasLength(1));
      expect(records[0].message, 'lazy message');
    });

    test('lambda is not called when level is filtered out', () {
      var callCount = 0;
      final records = <LogRecord>[];
      final logger = ChirpLogger()
        ..setMinLogLevel(ChirpLogLevel.warning)
        ..addWriter(FakeWriter(records));

      logger.trace(() {
        callCount++;
        return 'expensive message';
      });

      expect(records, isEmpty);
      expect(callCount, 0);
    });

    test('non-lambda message still works', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info('plain string');

      expect(records, hasLength(1));
      expect(records[0].message, 'plain string');
    });

    test('lambda works for all log levels', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()
        ..setMinLogLevel(ChirpLogLevel.trace)
        ..addWriter(FakeWriter(records));

      logger.log(() => 'log');
      logger.trace(() => 'trace');
      logger.debug(() => 'debug');
      logger.info(() => 'info');
      logger.notice(() => 'notice');
      logger.success(() => 'success');
      logger.warning(() => 'warning');
      logger.error(() => 'error');
      logger.critical(() => 'critical');
      logger.wtf(() => 'wtf');

      expect(records, hasLength(10));
      expect(records[0].message, 'log');
      expect(records[1].message, 'trace');
      expect(records[2].message, 'debug');
      expect(records[3].message, 'info');
      expect(records[4].message, 'notice');
      expect(records[5].message, 'success');
      expect(records[6].message, 'warning');
      expect(records[7].message, 'error');
      expect(records[8].message, 'critical');
      expect(records[9].message, 'wtf');
    });

    test('lambda returning null is stored as null', () {
      final records = <LogRecord>[];
      final logger = ChirpLogger()..addWriter(FakeWriter(records));

      logger.info(() => null);

      expect(records, hasLength(1));
      expect(records[0].message, isNull);
    });
  });
}

/// Fake writer implementation for testing.
class FakeWriter extends ChirpWriter {
  final List<LogRecord> records;

  FakeWriter(this.records);

  @override
  void write(LogRecord record) {
    records.add(record);
  }
}

/// Fake writer that requires caller info for testing.
class FakeWriterRequiringCallerInfo extends ChirpWriter {
  final List<LogRecord> records;

  FakeWriterRequiringCallerInfo(this.records);

  @override
  bool get requiresCallerInfo => true;

  @override
  void write(LogRecord record) {
    records.add(record);
  }
}

/// Fake interceptor for testing.
class FakeInterceptor extends ChirpInterceptor {
  @override
  bool get requiresCallerInfo => false;

  @override
  LogRecord? intercept(LogRecord record) => record;
}

/// Fake interceptor that requires caller info for testing.
class FakeInterceptorRequiringCallerInfo extends ChirpInterceptor {
  @override
  bool get requiresCallerInfo => true;

  @override
  LogRecord? intercept(LogRecord record) => record;
}
