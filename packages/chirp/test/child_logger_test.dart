import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Child Logger', () {
    test("child inherits parent's writers", () {
      final messages = <String>[];
      final parent = ChirpLogger(name: 'Parent').addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final child = parent.child(context: {'childKey': 'childValue'});

      child.info('Child log');

      expect(messages.length, 1);
      expect(messages[0], contains('"childKey":"childValue"'));
    });

    test('child maintains reference to parent instance', () {
      addTearDown(() => Chirp.root = null);
      final messages1 = <String>[];
      final messages2 = <String>[];

      // Configure root with first writer
      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages1.add,
      );

      // Create child - gets reference to current root instance
      final child = Chirp.root.child(context: {'requestId': 'REQ-123'});

      child.info('First log');
      expect(messages1.length, 1);
      expect(messages2.length, 0);

      // Reassign Chirp.root to a new logger instance
      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages2.add,
      );

      // Child still uses original parent (not the new root)
      child.info('Second log');
      expect(messages1.length, 2); // Child still writes to first writer
      expect(messages2.length, 0); // Not to the new root's writer
    });

    test('nested children merge context through the chain', () {
      final messages = <String>[];
      final root = ChirpLogger()
          .addContext({'app': 'myapp'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      final requestLogger = root.child(context: {'requestId': 'REQ-123'});
      final userLogger = requestLogger.child(context: {'userId': 'user_456'});
      final actionLogger = userLogger.child(context: {'action': 'payment'});

      actionLogger.info('Nested log');

      expect(messages[0], contains('"app":"myapp"'));
      expect(messages[0], contains('"requestId":"REQ-123"'));
      expect(messages[0], contains('"userId":"user_456"'));
      expect(messages[0], contains('"action":"payment"'));
    });

    test('child can override parent context keys', () {
      final messages = <String>[];
      final parent = ChirpLogger()
          .addContext({'status': 'pending', 'app': 'myapp'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      final child = parent.child(context: {'status': 'completed'});

      child.info('Status changed');

      expect(messages[0], contains('"app":"myapp"'));
      expect(messages[0], contains('"status":"completed"'));
      expect(messages[0], isNot(contains('"status":"pending"')));
    });

    test('child with name parameter', () {
      final messages = <String>[];
      final parent = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final child = parent.child(name: 'PaymentService');

      child.info('Named child log');

      expect(messages[0], contains('"class":"PaymentService"'));
    });

    test('child inherits parent name if not specified', () {
      final messages = <String>[];
      final parent = ChirpLogger(name: 'API').addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final child = parent.child(context: {'requestId': 'REQ-123'});

      child.info('Child log');

      expect(messages[0], contains('"class":"API"'));
    });

    test('child can override parent name', () {
      final messages = <String>[];
      final parent = ChirpLogger(name: 'API').addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final child = parent.child(name: 'PaymentAPI');

      child.info('Child log');

      expect(messages[0], contains('"class":"PaymentAPI"'));
      expect(messages[0], isNot(contains('"class":"API"')));
    });

    test('child with instance parameter', () {
      final messages = <String>[];
      final parent = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final myInstance = Object();
      final child = parent.child(instance: myInstance);

      child.info('Instance child log');

      final instanceHash =
          identityHashCode(myInstance).toRadixString(16).padLeft(4, '0');
      expect(messages[0], contains('"hash":"$instanceHash"'));
    });

    test('child inherits parent instance if not specified', () {
      final messages = <String>[];
      final parentInstance = Object();
      // Use child() from a logger that has an instance set
      final parent = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );
      final parentWithInstance = parent.child(instance: parentInstance);

      final child = parentWithInstance.child(context: {'requestId': 'REQ-123'});

      child.info('Child log');

      final instanceHash =
          identityHashCode(parentInstance).toRadixString(16).padLeft(4, '0');
      expect(messages[0], contains('"hash":"$instanceHash"'));
    });

    test('child can override parent instance', () {
      final messages = <String>[];
      final parentInstance = Object();
      final childInstance = Object();

      final parent = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );
      final parentWithInstance = parent.child(instance: parentInstance);

      final child = parentWithInstance.child(instance: childInstance);

      child.info('Child log');

      final childHash =
          identityHashCode(childInstance).toRadixString(16).padLeft(4, '0');
      expect(messages[0], contains('"hash":"$childHash"'));

      final parentHash =
          identityHashCode(parentInstance).toRadixString(16).padLeft(4, '0');
      expect(messages[0], isNot(contains('"hash":"$parentHash"')));
    });

    test('child of Chirp.root inherits root writers', () {
      addTearDown(() => Chirp.root = null);
      final messages = <String>[];

      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final child = Chirp.root.child(context: {'requestId': 'REQ-123'});

      child.info('Child of root');

      expect(messages.length, 1);
      expect(messages[0], contains('"requestId":"REQ-123"'));
    });

    test('instance logger uses root via parent reference', () {
      addTearDown(() => Chirp.root = null);
      final messages = <String>[];

      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: JsonMessageFormatter(),
        output: messages.add,
      );

      final instance = Object();
      final logger = instance.chirp;

      logger.info('Instance log');

      expect(messages.length, 1);
      final instanceHash =
          identityHashCode(instance).toRadixString(16).padLeft(4, '0');
      expect(messages[0], contains('"hash":"$instanceHash"'));
    });

    test('child without any parameters is valid', () {
      final messages = <String>[];
      final parent = ChirpLogger(name: 'Parent')
          .addContext({'parentKey': 'parentValue'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      final child = parent.child();

      child.info('Exact copy child');

      expect(messages[0], contains('"class":"Parent"'));
      expect(messages[0], contains('"parentKey":"parentValue"'));
    });

    test('deeply nested children maintain context chain', () {
      final messages = <String>[];
      final root = ChirpLogger()
          .addContext({'level0': 'root'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      var logger = root;
      for (var i = 1; i <= 5; i++) {
        logger = logger.child(context: {'level$i': 'value$i'});
      }

      logger.info('Deep nested log');

      // Root level
      expect(messages[0], contains('"level0":"root"'));
      // All child levels should be present
      for (var i = 1; i <= 5; i++) {
        expect(messages[0], contains('"level$i":"value$i"'));
      }
    });

    test('child logger sees parent context mutations at log time', () {
      final messages = <String>[];
      final parent = ChirpLogger()
          .addContext({'shared': 'original'})
          .addConsoleWriter(
            formatter: JsonMessageFormatter(),
            output: messages.add,
          );

      final child = parent.child(context: {'childKey': 'childValue'});

      // Modify parent context after child creation
      parent.context['shared'] = 'modified';
      parent.context['newKey'] = 'newValue';

      parent.info('Parent log');
      child.info('Child log');

      // Parent has modified values
      expect(messages[0], contains('"shared":"modified"'));
      expect(messages[0], contains('"newKey":"newValue"'));

      // Child sees parent mutations at log time (context resolved dynamically)
      expect(messages[1], contains('"shared":"modified"'));
      expect(messages[1], contains('"newKey":"newValue"'));
      expect(messages[1], contains('"childKey":"childValue"'));
    });
  });
}
