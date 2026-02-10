// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  group('Colored', () {
    test('applies color to each line of multi-line strings', () {
      final span = AnsiStyled(
        foreground: Ansi256.red1_196,
        child: PlainText('line1\nline2\nline3'),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
            colorSupport: TerminalColorSupport.ansi256),
      );
      renderSpan(span, buffer);
      final result = buffer.toString();

      // Red color (196) should be applied at the start of each line
      // Format: \x1B[38;5;196mline1\n\x1B[38;5;196mline2\n\x1B[38;5;196mline3\x1B[0m
      expect(
        result,
        '\x1B[38;5;196mline1\n'
        '\x1B[38;5;196mline2\n'
        '\x1B[38;5;196mline3'
        '\x1B[0m',
      );
    });

    test('restores parent color after nested multi-line color', () {
      // Parent: red, nested middle line: blue
      final span = AnsiStyled(
        foreground: Ansi256.red1_196,
        child: SpanSequence(children: [
          PlainText('red1\n'),
          AnsiStyled(
            foreground: Ansi256.blue1_21,
            child: PlainText('blue\n'),
          ),
          PlainText('red2'),
        ]),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
            colorSupport: TerminalColorSupport.ansi256),
      );
      renderSpan(span, buffer);
      final result = buffer.toString();

      // red1 in red, then newline, then blue in blue, newline, then red2 in red
      expect(
        result,
        '\x1B[38;5;196mred1\n'
        '\x1B[38;5;196m' // red re-applied after newline
        '\x1B[38;5;21mblue\n'
        '\x1B[38;5;21m' // blue re-applied after newline
        '\x1B[38;5;196m' // red restored after blue pops
        'red2'
        '\x1B[0m',
      );
    });

    test('handles trailing newline in colored text', () {
      final span = AnsiStyled(
        foreground: Ansi256.red1_196,
        child: PlainText('text\n'),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
            colorSupport: TerminalColorSupport.ansi256),
      );
      renderSpan(span, buffer);
      final result = buffer.toString();

      // Should apply color, then text, then newline with color re-applied (even though nothing follows)
      expect(
        result,
        '\x1B[38;5;196mtext\n'
        '\x1B[38;5;196m' // color re-applied after newline
        '\x1B[0m',
      );
    });

    test('nested Colored colors override parent colors', () {
      // Parent: red, Child: blue
      // "Hello " should be red, "World" should be blue
      final span = AnsiStyled(
        foreground: Ansi256.red1_196, // red
        child: SpanSequence(children: [
          PlainText('Hello '),
          AnsiStyled(
            foreground: Ansi256.blue1_21, // blue
            child: PlainText('World'),
          ),
          PlainText('!'),
        ]),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
            colorSupport: TerminalColorSupport.ansi256),
      );
      renderSpan(span, buffer);
      final result = buffer.toString();

      // Red color code 196 should appear before "Hello"
      expect(result, contains('[38;5;196m'));
      // Blue color code 21 should appear before "World"
      expect(result, contains('[38;5;21m'));
      // "!" should be red - red must be restored after blue ends
      final exclamationIndex = result.indexOf('!');
      final beforeExclamation = result.substring(
        result.lastIndexOf('\x1B', exclamationIndex),
        exclamationIndex,
      );
      expect(
        beforeExclamation,
        contains('[38;5;196m'),
        reason: '"!" should be red (parent color restored after nested blue)',
      );
    });
  });

  group('SpanTransformer', () {
    test('replaces Timestamp with level emoji', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final formatter = RainbowMessageFormatter(
        spanTransformers: [
          (tree, record) {
            final timestamp = tree.findFirst<Timestamp>();
            timestamp?.replaceWith(_LevelEmojiSpan(record.level));
          },
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // Emoji replaces timestamp, followed by level and message
      expect(result, contains('\u{1f50d}'));
      expect(result, contains('[info]'));
      expect(result, contains('Hello'));
    });

    test('wraps Timestamp with custom span', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final formatter = RainbowMessageFormatter(
        spanTransformers: [
          (tree, record) {
            final timestamp = tree.findFirst<Timestamp>();
            if (timestamp != null) {
              timestamp.wrap((child) => _BracketedSpan(child: child));
            }
          },
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // Timestamp wrapped with brackets
      expect(result, contains('[10:23:45.123]'));
    });

    test('removes Timestamp entirely', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final formatter = RainbowMessageFormatter(
        spanTransformers: [
          (tree, record) {
            tree.findFirst<Timestamp>()?.remove();
          },
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // No timestamp in output
      expect(result, isNot(contains('10:23:45.123')));
      expect(result, contains('Hello'));
    });

    test('wraps entire WTF log with Bordered using root.wrap', () {
      final record = testRecord(
        message: 'WTF error',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.wtf,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          data: DataPresentation.inline,
          // ignore: deprecated_member_use_from_same_package
          showTime: false,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (tree, record) {
            if (record.level != ChirpLogLevel.wtf) return;
            tree.wrap(
              (child) => Bordered(
                child: child,
                style: BoxBorderStyle.rounded,
                borderColor: Ansi256.red3_160,
              ),
            );
          },
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // Full bordered box around the entire message. Using full-string
      // comparison to ensure all lines (and their order) are correct.
      expect(
        result,
        '╭────────────╮\n'
        '│  WTF error │\n'
        '╰────────────╯',
      );
    });
  });

  group('LogSpan tree manipulation', () {
    group('replaceWith', () {
      test('replaces a leaf span in parent', () {
        final sequence = SpanSequence(children: [
          PlainText('before'),
          PlainText('target'),
          PlainText('after'),
        ]);

        final target = sequence.children[1];
        target.replaceWith(PlainText('replaced'));

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'beforereplacedafter');
      });

      test('replaces nested span', () {
        final outer = AnsiStyled(
          foreground: Ansi256.red1_196,
          child: PlainText('nested'),
        );
        final sequence = SpanSequence(children: [outer]);

        outer.child!.replaceWith(PlainText('replaced'));

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'replaced');
      });

      test('returns false for root span', () {
        final span = PlainText('root');
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('updates parent references correctly', () {
        final sequence = SpanSequence(children: [PlainText('child')]);
        final newSpan = PlainText('new');

        sequence.children.first.replaceWith(newSpan);

        expect(newSpan.parent, sequence);
      });
    });

    group('remove', () {
      test('removes span from parent', () {
        final sequence = SpanSequence(children: [
          PlainText('a'),
          PlainText('b'),
          PlainText('c'),
        ]);

        sequence.children[1].remove();

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'ac');
      });

      test('returns false for root span', () {
        final span = PlainText('root');
        expect(span.remove(), isFalse);
      });

      test('clears parent reference after removal', () {
        final sequence = SpanSequence(children: [PlainText('child')]);
        final child = sequence.children.first;

        child.remove();

        expect(child.parent, isNull);
      });
    });

    group('wrap', () {
      test('wraps a span with colored', () {
        final sequence = SpanSequence(children: [PlainText('hello')]);
        final child = sequence.children.first;

        child.wrap(
          (c) => AnsiStyled(foreground: Ansi256.red1_196, child: c),
        );

        expect(sequence.children.first, isA<AnsiStyled>());
        expect(
          (sequence.children.first as SingleChildSpan).child,
          isA<PlainText>(),
        );
      });

      test('preserves rendering after wrap', () {
        final sequence = SpanSequence(children: [PlainText('hello')]);
        final child = sequence.children.first;

        child.wrap(
          (c) => AnsiStyled(foreground: Ansi256.red1_196, child: c),
        );

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'hello');
      });
    });

    group('findFirst', () {
      test('finds direct match', () {
        final span = Timestamp(DateTime.now());
        expect(span.findFirst<Timestamp>(), span);
      });

      test('finds nested span', () {
        final timestamp = Timestamp(DateTime.now());
        final sequence = SpanSequence(children: [
          PlainText('before'),
          AnsiStyled(child: timestamp),
        ]);

        expect(sequence.findFirst<Timestamp>(), timestamp);
      });

      test('returns null when not found', () {
        final sequence = SpanSequence(children: [PlainText('hello')]);
        expect(sequence.findFirst<Timestamp>(), isNull);
      });
    });

    group('findAll', () {
      test('finds all matching spans', () {
        final t1 = PlainText('a');
        final t2 = PlainText('b');
        final t3 = PlainText('c');
        final sequence = SpanSequence(children: [
          t1,
          AnsiStyled(child: t2),
          t3,
        ]);

        final found = sequence.findAll<PlainText>().toList();
        expect(found, containsAll([t1, t2, t3]));
      });

      test('includes self if matching', () {
        final span = PlainText('hello');
        expect(span.findAll<PlainText>().toList(), [span]);
      });
    });

    group('allChildren', () {
      test('returns empty for leaf span', () {
        final span = PlainText('hello');
        expect(span.allChildren, isEmpty);
      });

      test('returns child for single child span', () {
        final child = PlainText('child');
        final span = AnsiStyled(child: child);
        expect(span.allChildren.toList(), [child]);
      });

      test('returns all children for multi child span', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final c = PlainText('c');
        final span = SpanSequence(children: [a, b, c]);
        expect(span.allChildren.toList(), [a, b, c]);
      });
    });

    group('allDescendants', () {
      test('returns self for leaf', () {
        final span = PlainText('hello');
        expect(span.allDescendants.toList(), [span]);
      });

      test('returns self and all descendants', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final inner = AnsiStyled(child: b);
        final sequence = SpanSequence(children: [a, inner]);

        final descendants = sequence.allDescendants.toList();
        expect(descendants, [sequence, a, inner, b]);
      });
    });

    group('allAncestors', () {
      test('returns empty for root', () {
        final span = PlainText('root');
        expect(span.allAncestors, isEmpty);
      });

      test('returns ancestors from parent to root', () {
        final deep = PlainText('deep');
        final middle = AnsiStyled(child: deep);
        final root = SpanSequence(children: [middle]);

        final ancestors = deep.allAncestors.toList();
        expect(ancestors, [middle, root]);
      });
    });

    group('root', () {
      test('returns self for root span', () {
        final span = PlainText('root');
        expect(span.root, span);
      });

      test('returns root from nested span', () {
        final deep = PlainText('deep');
        final root = SpanSequence(children: [AnsiStyled(child: deep)]);

        expect(deep.root, root);
      });
    });

    group('parent', () {
      test('is null for root span', () {
        final span = PlainText('root');
        expect(span.parent, isNull);
      });

      test('is set for child span', () {
        final child = PlainText('child');
        final parent = SpanSequence(children: [child]);

        expect(child.parent, parent);
      });
    });

    group('MultiChildSpan operations', () {
      test('addChild adds to end', () {
        final sequence = SpanSequence(children: [PlainText('a')]);
        sequence.addChild(PlainText('b'));

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'ab');
      });

      test('insertChild at index', () {
        final sequence =
            SpanSequence(children: [PlainText('a'), PlainText('c')]);
        sequence.insertChild(1, PlainText('b'));

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'abc');
      });

      test('indexOf returns correct index', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final sequence = SpanSequence(children: [a, b]);

        expect(sequence.indexOf(a), 0);
        expect(sequence.indexOf(b), 1);
      });

      test('previousSiblingOf and nextSiblingOf', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final c = PlainText('c');
        final sequence = SpanSequence(children: [a, b, c]);

        expect(sequence.previousSiblingOf(a), isNull);
        expect(sequence.previousSiblingOf(b), a);
        expect(sequence.nextSiblingOf(b), c);
        expect(sequence.nextSiblingOf(c), isNull);
      });
    });

    group('SingleChildSpan operations', () {
      test('setting child updates parent reference', () {
        final span = AnsiStyled();
        final child = PlainText('hello');

        span.child = child;

        expect(child.parent, span);
      });

      test('replacing child clears old parent reference', () {
        final span = AnsiStyled();
        final oldChild = PlainText('old');
        final newChild = PlainText('new');

        span.child = oldChild;
        expect(oldChild.parent, span);

        span.child = newChild;
        expect(oldChild.parent, isNull);
        expect(newChild.parent, span);
      });
    });

    group('SlottedSpan operations', () {
      test('setSlot updates parent reference', () {
        final surrounded = Surrounded();
        final prefix = PlainText('[');
        final child = PlainText('content');

        surrounded.prefix = prefix;
        surrounded.child = child;

        expect(prefix.parent, surrounded);
        expect(child.parent, surrounded);
      });

      test('replacing slot clears old parent reference', () {
        final surrounded = Surrounded();
        final oldChild = PlainText('old');
        final newChild = PlainText('new');

        surrounded.child = oldChild;
        expect(oldChild.parent, surrounded);

        surrounded.child = newChild;
        expect(oldChild.parent, isNull);
        expect(newChild.parent, surrounded);
      });

      test('renders correctly with slots', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          child: PlainText('content'),
          suffix: PlainText(']'),
        );

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(surrounded, buffer);
        expect(buffer.toString(), '[content]');
      });

      test('renders empty when child is null', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          suffix: PlainText(']'),
        );

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(surrounded, buffer);
        expect(buffer.toString(), isEmpty);
      });
    });

    group('complex tree operations', () {
      test('multiple operations preserve consistency', () {
        final sequence = SpanSequence(children: [
          PlainText('a'),
          PlainText('b'),
        ]);

        // Add new children
        sequence.addChild(PlainText('c'));
        sequence.insertChild(0, PlainText('0'));

        // Verify structure
        expect(sequence.children.length, 4);

        // Verify all parents
        for (final child in sequence.children) {
          expect(
            child.parent,
            sequence,
            reason: 'child $child should have sequence as parent',
          );
        }

        // Verify output
        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(sequence, buffer);
        expect(buffer.toString(), '0abc');
      });

      test('moving child between parents', () {
        final parent1 = SpanSequence(children: [PlainText('child')]);
        final parent2 = SpanSequence();
        final child = parent1.children.first;

        parent2.addChild(child);

        expect(parent1.children, isEmpty);
        expect(parent2.children.length, 1);
        expect(child.parent, parent2);
      });
    });

    group('SingleChildSpan as nested child', () {
      test('replaceWith when SingleChildSpan has a parent', () {
        final inner = AnsiStyled(child: PlainText('inner'));
        final outer = SpanSequence(children: [inner]);

        final newSpan = AnsiStyled(child: PlainText('replaced'));
        final result = inner.replaceWith(newSpan);

        expect(result, isTrue);
        expect(outer.children.first, newSpan);
        expect(newSpan.parent, outer);
        expect(inner.parent, isNull);
      });

      test('remove when SingleChildSpan has a parent', () {
        final inner = AnsiStyled(child: PlainText('inner'));
        final outer = SpanSequence(children: [inner]);

        final result = inner.remove();

        expect(result, isTrue);
        expect(outer.children, isEmpty);
        expect(inner.parent, isNull);
      });

      test('replaceWith returns false for root SingleChildSpan', () {
        final span = AnsiStyled(child: PlainText('child'));
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('remove returns false for root SingleChildSpan', () {
        final span = AnsiStyled(child: PlainText('child'));
        expect(span.remove(), isFalse);
      });
    });

    group('MultiChildSpan as nested child', () {
      test('replaceWith when MultiChildSpan has a parent', () {
        final inner = SpanSequence(children: [PlainText('a'), PlainText('b')]);
        final outer = AnsiStyled(child: inner);

        final newSpan = SpanSequence(children: [PlainText('replaced')]);
        final result = inner.replaceWith(newSpan);

        expect(result, isTrue);
        expect(outer.child, newSpan);
        expect(newSpan.parent, outer);
        expect(inner.parent, isNull);
      });

      test('remove when MultiChildSpan has a parent', () {
        final inner = SpanSequence(children: [PlainText('a')]);
        final outer = AnsiStyled(child: inner);

        final result = inner.remove();

        expect(result, isTrue);
        expect(outer.child, isNull);
        expect(inner.parent, isNull);
      });

      test('replaceWith returns false for root MultiChildSpan', () {
        final span = SpanSequence(children: [PlainText('child')]);
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('remove returns false for root MultiChildSpan', () {
        final span = SpanSequence(children: [PlainText('child')]);
        expect(span.remove(), isFalse);
      });
    });

    group('SlottedSpan operations', () {
      test('allChildren returns slot values', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          child: PlainText('content'),
          suffix: PlainText(']'),
        );

        final children = surrounded.allChildren.toList();
        expect(children.length, 3);
      });

      test('replaceWith when SlottedSpan has a parent', () {
        final inner = Surrounded(
          prefix: PlainText('['),
          child: PlainText('content'),
          suffix: PlainText(']'),
        );
        final outer = SpanSequence(children: [inner]);

        final newSpan = Surrounded(child: PlainText('new'));
        final result = inner.replaceWith(newSpan);

        expect(result, isTrue);
        expect(outer.children.first, newSpan);
        expect(newSpan.parent, outer);
        expect(inner.parent, isNull);
      });

      test('remove when SlottedSpan has a parent', () {
        final inner = Surrounded(child: PlainText('content'));
        final outer = SpanSequence(children: [inner]);

        final result = inner.remove();

        expect(result, isTrue);
        expect(outer.children, isEmpty);
        expect(inner.parent, isNull);
      });

      test('replaceWith returns false for root SlottedSpan', () {
        final span = Surrounded(child: PlainText('child'));
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('remove returns false for root SlottedSpan', () {
        final span = Surrounded(child: PlainText('child'));
        expect(span.remove(), isFalse);
      });

      test('setSlot to null removes slot', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          child: PlainText('content'),
        );
        final prefix = surrounded.prefix;

        surrounded.prefix = null;

        expect(surrounded.prefix, isNull);
        expect(prefix?.parent, isNull);
      });
    });

    group('SlottedSpan parent operations', () {
      test('replaceChild in SlottedSpan parent', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          child: PlainText('old'),
          suffix: PlainText(']'),
        );
        final oldChild = surrounded.child!;
        final newChild = PlainText('new');

        oldChild.replaceWith(newChild);

        expect(surrounded.child, newChild);
        expect(newChild.parent, surrounded);
        expect(oldChild.parent, isNull);
      });

      test('removeChild from SlottedSpan parent', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          child: PlainText('content'),
          suffix: PlainText(']'),
        );
        final child = surrounded.child!;

        child.remove();

        expect(surrounded.child, isNull);
        expect(child.parent, isNull);
      });
    });

    group('wrap with SlottedSpan parent', () {
      test('wrap span in SlottedSpan parent', () {
        final child = PlainText('content');
        final surrounded = Surrounded(child: child);

        child.wrap(
          (c) => AnsiStyled(foreground: Ansi256.red1_196, child: c),
        );

        expect(surrounded.child, isA<AnsiStyled>());
        expect((surrounded.child! as AnsiStyled).child, isA<PlainText>());
      });

      test('wrap preserves slot position', () {
        final prefix = PlainText('[');
        final content = PlainText('content');
        final surrounded = Surrounded(
          prefix: prefix,
          child: content,
        );

        prefix.wrap(
          (c) => AnsiStyled(foreground: Ansi256.blue1_21, child: c),
        );

        expect(surrounded.prefix, isA<AnsiStyled>());

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(surrounded, buffer);
        expect(buffer.toString(), '[content');
      });
    });

    group('chained build', () {
      test('renderSpan loops through chained build() calls', () {
        // Chain: FancyTimestamp -> Timestamp -> PlainText
        // This exercises the while loop in renderSpan
        final date = DateTime(2024, 1, 15, 10, 23, 45, 123);
        final fancyTimestamp = _FancyTimestamp(date);

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(fancyTimestamp, buffer);

        // Should render as ">>> 10:23:45.123 <<<"
        expect(buffer.toString(), '>>> 10:23:45.123 <<<');
      });

      test('triple chained build works', () {
        // Chain: Level3 -> Level2 -> Level1 -> PlainText
        final span = _Level3Span('hello');

        final buffer = ConsoleMessageBuffer(
          capabilities: const TerminalCapabilities(
              colorSupport: TerminalColorSupport.none),
        );
        renderSpan(span, buffer);

        expect(buffer.toString(), '<<<[[[hello]]]>>>');
      });
    });
  });

  group('SpanFormatOptions', () {
    test('applies spanTransformers from formatOptions', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        formatOptions: [
          SpanFormatOptions(
            spanTransformers: [
              (span, record) {
                span.findFirst<Timestamp>()?.replaceWith(PlainText('CUSTOM'));
              },
            ],
          ),
        ],
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, 'CUSTOM [info] Hello');
    });

    test('per-log transformers run after formatter transformers', () {
      final transformerOrder = <String>[];

      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        formatOptions: [
          SpanFormatOptions(
            spanTransformers: [
              (span, record) {
                transformerOrder.add('per-log');
              },
            ],
          ),
        ],
      );

      final formatter = RainbowMessageFormatter(
        spanTransformers: [
          (span, record) {
            transformerOrder.add('formatter');
          },
        ],
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));

      expect(transformerOrder, ['formatter', 'per-log']);
    });

    test('multiple SpanFormatOptions are all applied', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        formatOptions: [
          SpanFormatOptions(
            spanTransformers: [
              (span, record) {
                span.findFirst<Timestamp>()?.remove();
              },
            ],
          ),
          SpanFormatOptions(
            spanTransformers: [
              (span, record) {
                span.findFirst<BracketedLogLevel>()?.remove();
              },
            ],
          ),
        ],
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // Both timestamp and level should be removed
      expect(result.trim(), 'Hello');
    });

    test('wraps entire message with Bordered via per-log transformer', () {
      final record = testRecord(
        message: 'Important',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.warning,
        formatOptions: [
          SpanFormatOptions(
            spanTransformers: [
              (span, record) {
                span.wrap(
                  (child) => Bordered(
                    child: child,
                    style: BoxBorderStyle.rounded,
                  ),
                );
              },
            ],
          ),
        ],
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          // ignore: deprecated_member_use_from_same_package
          showTime: false,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(
        result,
        '╭────────────╮\n'
        '│  Important │\n'
        '╰────────────╯',
      );
    });

    test('empty formatOptions list does not affect output', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        formatOptions: const [],
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:23:45.123 [info] Hello');
    });

    test('null formatOptions does not affect output', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, '10:23:45.123 [info] Hello');
    });

    test('non-SpanFormatOptions in formatOptions are ignored', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        formatOptions: const [
          FormatOptions(), // Not SpanFormatOptions
          // ignore: deprecated_member_use_from_same_package
          RainbowFormatOptions(showTime: false), // Different type
        ],
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
        ),
      );

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      // RainbowFormatOptions should still work (showTime: false)
      // The leading space is from the Surrounded span that wraps the timestamp
      expect(result.trimLeft(), '[info] Hello');
    });

    test('works with CompactChirpMessageFormatter', () {
      final record = testRecord(
        message: 'Hello',
        timestamp: DateTime(2024, 1, 15, 10, 23, 45, 123),
        wallClock: DateTime(2024, 1, 15, 10, 23, 45, 123),
        formatOptions: [
          SpanFormatOptions(
            spanTransformers: [
              (span, record) {
                span
                    .findFirst<LogMessage>()
                    ?.replaceWith(PlainText('REPLACED'));
              },
            ],
          ),
        ],
      );

      final formatter = CompactChirpMessageFormatter();

      final buffer = ConsoleMessageBuffer(
        capabilities:
            const TerminalCapabilities(colorSupport: TerminalColorSupport.none),
      );
      formatter.format(record, MessageBuffer(buffer));
      final result = buffer.toString();

      expect(result, contains('REPLACED'));
      expect(result, isNot(contains('Hello')));
    });
  });

  group('Aligned', () {
    test('pads plain text to width', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );
      Aligned(
        width: 10,
        align: HorizontalAlign.left,
        child: PlainText('hello'),
      ).render(buffer);

      expect(buffer.toString(), 'hello     ');
    });

    test('ignores ANSI codes when calculating visible width', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );
      Aligned(
        width: 10,
        align: HorizontalAlign.left,
        child: AnsiStyled(
          foreground: Ansi16.red,
          child: PlainText('hello'),
        ),
      ).render(buffer);

      final result = buffer.toString();
      // The visible content is 'hello' (5 chars) + 5 spaces of padding
      // ANSI codes should NOT be counted towards the width
      final stripped = stripAnsiCodes(result);
      expect(stripped, 'hello     ');
      expect(stripped.length, 10);
    });

    test('right align ignores ANSI codes', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );
      Aligned(
        width: 10,
        align: HorizontalAlign.right,
        child: AnsiStyled(
          foreground: Ansi16.blue,
          child: PlainText('hello'),
        ),
      ).render(buffer);

      final result = buffer.toString();
      final stripped = stripAnsiCodes(result);
      expect(stripped, '     hello');
      expect(stripped.length, 10);
    });

    test('center align ignores ANSI codes', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.ansi256,
        ),
      );
      Aligned(
        width: 10,
        align: HorizontalAlign.center,
        child: AnsiStyled(
          foreground: Ansi16.green,
          child: PlainText('hi'),
        ),
      ).render(buffer);

      final result = buffer.toString();
      final stripped = stripAnsiCodes(result);
      expect(stripped, '    hi    ');
      expect(stripped.length, 10);
    });
  });

  group('StackTraceSpan', () {
    test('trims trailing newline from stack trace', () {
      final stackTrace =
          StackTrace.fromString('#0 main (file:///test.dart:1:1)\n');
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(StackTraceSpan(stackTrace), buffer);
      final result = buffer.toString();

      expect(result, '#0 main (file:///test.dart:1:1)');
      expect(result.endsWith('\n'), isFalse);
    });

    test('preserves stack trace without trailing newline', () {
      final stackTrace =
          StackTrace.fromString('#0 main (file:///test.dart:1:1)');
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(StackTraceSpan(stackTrace), buffer);
      final result = buffer.toString();

      expect(result, '#0 main (file:///test.dart:1:1)');
    });
  });

  group('DataKey', () {
    test('renders simple key', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      DataKey('userId').render(buffer);
      expect(buffer.toString(), 'userId');
    });

    test('quotes key with spaces', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      DataKey('key with spaces').render(buffer);
      expect(buffer.toString(), '"key with spaces"');
    });
  });

  group('DataValue', () {
    test('renders string value quoted', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      DataValue('hello').render(buffer);
      expect(buffer.toString(), '"hello"');
    });

    test('renders number without quotes', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      DataValue(42).render(buffer);
      expect(buffer.toString(), '42');
    });

    test('renders boolean without quotes', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      DataValue(true).render(buffer);
      expect(buffer.toString(), 'true');
    });

    test('renders null as null', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      DataValue(null).render(buffer);
      expect(buffer.toString(), 'null');
    });
  });

  group('InlineData', () {
    test('renders empty for null data', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(InlineData(null), buffer);
      expect(buffer.toString(), '');
    });

    test('renders empty for empty map', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(InlineData({}), buffer);
      expect(buffer.toString(), '');
    });

    test('renders single key-value pair', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(InlineData({'userId': 'abc123'}), buffer);
      expect(buffer.toString(), 'userId: "abc123"');
    });

    test('renders multiple key-value pairs with separator', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(InlineData({'userId': 'abc', 'action': 'login'}), buffer);
      expect(buffer.toString(), 'userId: "abc", action: "login"');
    });

    test('uses custom entry separator', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(
        InlineData(
          {'a': 1, 'b': 2},
          entrySeparatorBuilder: () => PlainText(' | '),
        ),
        buffer,
      );
      expect(buffer.toString(), 'a: 1 | b: 2');
    });

    test('uses custom key-value separator', () {
      final buffer = ConsoleMessageBuffer(
        capabilities: const TerminalCapabilities(
          colorSupport: TerminalColorSupport.none,
        ),
      );
      renderSpan(
        InlineData(
          {'key': 'value'},
          keyValueSeparatorBuilder: () => PlainText('='),
        ),
        buffer,
      );
      expect(buffer.toString(), 'key="value"');
    });
  });
}

/// Builds to Timestamp (which builds to PlainText).
/// Chain: FancyTimestamp -> Timestamp -> PlainText
class _FancyTimestamp extends LeafSpan {
  final DateTime date;

  _FancyTimestamp(this.date);

  @override
  LogSpan build() {
    // Returns a Timestamp wrapped with decoration
    // Timestamp.build() will return PlainText
    return SpanSequence(children: [
      PlainText('>>> '),
      Timestamp(date),
      PlainText(' <<<'),
    ]);
  }
}

/// Level 3 -> Level 2
class _Level3Span extends LeafSpan {
  final String text;

  _Level3Span(this.text);

  @override
  LogSpan build() => _Level2Span(text);
}

/// Level 2 -> Level 1
class _Level2Span extends LeafSpan {
  final String text;

  _Level2Span(this.text);

  @override
  LogSpan build() => _Level1Span(text);
}

/// Level 1 -> PlainText
class _Level1Span extends LeafSpan {
  final String text;

  _Level1Span(this.text);

  @override
  LogSpan build() => PlainText('<<<[[[$text]]]>>>');
}

/// Custom span that shows an emoji based on log level.
class _LevelEmojiSpan extends LeafSpan {
  final ChirpLogLevel level;

  _LevelEmojiSpan(this.level);

  @override
  void render(ConsoleMessageBuffer buffer) {
    final emoji = switch (level.severity) {
      >= 500 => '\u{274c}',
      >= 400 => '\u{26a0}\u{fe0f}',
      >= 300 => '\u{2139}\u{fe0f}',
      _ => '\u{1f50d}',
    };
    buffer.write(emoji);
  }
}

/// Custom span that wraps a child with brackets.
class _BracketedSpan extends MultiChildSpan {
  _BracketedSpan({required LogSpan child}) {
    addChild(PlainText('['));
    addChild(child);
    addChild(PlainText(']'));
  }

  @override
  void render(ConsoleMessageBuffer buffer) {
    for (final child in children) {
      child.render(buffer);
    }
  }
}
