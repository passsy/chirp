import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('addWriter', () {
    test('adds writer to logger after creation', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'TestLogger');

      // Initially no writers - no output
      logger.addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      logger.info('Test message');

      // Message should be captured by our writer
      expect(messages.length, 1);
      expect(messages[0], contains('Test message'));
    });

    test('adds multiple writers after creation', () {
      final messages1 = <String>[];
      final messages2 = <String>[];
      final logger = ChirpLogger(name: 'TestLogger');

      logger.addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages1.add,
      );
      logger.addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages2.add,
      );

      logger.info('Test message');

      expect(messages1.length, 1);
      expect(messages2.length, 1);
    });

    test('child logger writers are ignored - only parent writers used', () {
      final parentMessages = <String>[];
      final childMessages = <String>[];
      final parent = ChirpLogger(name: 'Parent');
      parent.addConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: parentMessages.add,
      );
      final child = parent.child(context: {'requestId': 'REQ-123'});

      // Add writer to child (will be ignored)
      child.addConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: childMessages.add,
      );

      // Parent logs go only to parent writer
      parent.info('Parent log');
      expect(parentMessages.length, 1);
      expect(childMessages.length, 0);

      // Child logs go only to parent's writer (child's writer is ignored)
      child.info('Child log');
      expect(parentMessages.length, 2); // Parent receives child logs
      expect(childMessages.length, 0); // Child's own writer is ignored
    });

    test('only root writers are used in hierarchy', () {
      final parentMessages = <String>[];
      final childMessages = <String>[];
      final grandchildMessages = <String>[];

      final root = ChirpLogger(name: 'Root');
      root.addConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: parentMessages.add,
      );
      final child = root.child(context: {'level': '1'});
      child.addConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: childMessages.add,
      );
      final grandchild = child.child(context: {'level': '2'});
      grandchild.addConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: grandchildMessages.add,
      );

      // Grandchild logs go only to root's writer (child writers ignored)
      grandchild.info('Deep log');
      expect(parentMessages.length, 1);
      expect(childMessages.length, 0);
      expect(grandchildMessages.length, 0);
    });

    test('logger without writers produces no output', () {
      final libLogger = ChirpLogger(name: 'MyLibrary');

      // No writers configured - this does nothing (silent)
      libLogger.info('Library initialized');

      // Now add a writer
      final messages = <String>[];
      libLogger.addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      // Now logs are captured
      libLogger.info('Library doing work');
      expect(messages.length, 1);
      expect(messages[0], contains('Library doing work'));
    });

    test('addWriter works with logger that already has writers', () {
      final messages1 = <String>[];
      final messages2 = <String>[];

      final logger = ChirpLogger(name: 'TestLogger');
      logger.addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages1.add,
      );

      logger.info('First message');
      expect(messages1.length, 1);
      expect(messages2.length, 0);

      // Add another writer
      logger.addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages2.add,
      );

      logger.info('Second message');
      expect(messages1.length, 2);
      expect(messages2.length, 1);
    });

    test('adding same writer twice is a no-op', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'TestLogger');
      final writer = PrintConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      logger.addWriter(writer);
      logger.addWriter(writer); // Should be ignored

      expect(logger.writers.length, 1);

      logger.info('Test message');
      // Only one message, not two
      expect(messages.length, 1);
    });

    test('addWriter on Chirp.root adds globally', () {
      addTearDown(() => Chirp.root = null);
      final messages = <String>[];

      // Replace root with custom logger (recommended pattern: chain writers)
      Chirp.root = ChirpLogger().addConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      // Static Chirp methods should use the writer
      Chirp.info('Global log');
      expect(messages.length, 1);
      expect(messages[0], contains('Global log'));
    });

    test('child inherits parent writers', () {
      final messages = <String>[];
      final parent = ChirpLogger(name: 'Parent');
      parent.addConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: messages.add,
      );

      final child = parent.child(context: {'requestId': 'REQ-123'});

      // Child uses parent's writer
      child.info('Child log');
      expect(messages.length, 1);
      expect(messages[0], contains('"requestId":"REQ-123"'));
    });
  });

  group('removeWriter', () {
    test('removes writer from logger', () {
      final messages = <String>[];
      final logger = ChirpLogger(name: 'TestLogger');
      final writer = PrintConsoleWriter(
        formatter: CompactChirpMessageFormatter(),
        output: messages.add,
      );

      logger.addWriter(writer);

      logger.info('First message');
      expect(messages.length, 1);

      final removed = logger.removeWriter(writer);
      expect(removed, isTrue);

      logger.info('Second message');
      // Still 1 because writer was removed (no default, so silent)
      expect(messages.length, 1);
    });

    test('returns false when writer not found', () {
      final logger = ChirpLogger(name: 'TestLogger');
      final writer =
          PrintConsoleWriter(formatter: CompactChirpMessageFormatter());

      // Writer was never added
      final removed = logger.removeWriter(writer);
      expect(removed, isFalse);
    });

    test('removeWriter only removes from own logger not parent', () {
      final messages = <String>[];
      final parent = ChirpLogger(name: 'Parent');
      final writer = PrintConsoleWriter(
        formatter: const JsonLogFormatter(),
        output: messages.add,
      );

      parent.addWriter(writer);
      final child = parent.child(context: {'requestId': 'REQ-123'});

      child.info('First log');
      expect(messages.length, 1);

      // Remove via child - won't find it (it's on parent)
      final removed = child.removeWriter(writer);
      expect(removed, isFalse);

      // Writer still works via parent
      child.info('Second log');
      expect(messages.length, 2);

      // Remove from parent works
      final removedFromParent = parent.removeWriter(writer);
      expect(removedFromParent, isTrue);

      child.info('Third log');
      // Still 2 because writer was removed
      expect(messages.length, 2);
    });
  });
}
