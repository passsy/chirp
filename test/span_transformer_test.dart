// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Colored', () {
    test('nested Colored colors override parent colors', () {
      // Parent: red, Child: blue
      // "Hello " should be red, "World" should be blue
      const span = AnsiColored(
        foreground: XtermColor.red1_196, // red
        child: SpanSequence([
          PlainText('Hello '),
          AnsiColored(
            foreground: XtermColor.blue1_21, // blue
            child: PlainText('World'),
          ),
          PlainText('!'),
        ]),
      );

      final buffer = ConsoleMessageBuffer(useColors: true);
      renderSpan(span, buffer);
      final result = buffer.toString();

      // Red color code 196 should appear before "Hello"
      expect(result, contains('[38;5;196m'));
      // Blue color code 21 should appear before "World"
      expect(result, contains('[38;5;21m'));
      // "!" should be red - red must be restored after blue ends
      final exclamationIndex = result.indexOf('!');
      final beforeExclamation = result.substring(
          result.lastIndexOf('\x1B', exclamationIndex), exclamationIndex);
      expect(beforeExclamation, contains('[38;5;196m'),
          reason:
              '"!" should be red (parent color restored after nested blue)');
    });
  });

  group('SpanTransformer', () {
    test('replaces Timestamp with level emoji', () {
      final record = LogRecord(
        message: 'Hello',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.info,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (tree, record) {
            final node = tree.findFirst<Timestamp>();
            node?.replaceSpan(_LevelEmojiSpan(record.level));
          },
        ],
      );

      final buffer = ConsoleMessageBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, '🔍 Hello');
    });

    test('wraps Timestamp with custom span', () {
      final record = LogRecord(
        message: 'Hello',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.info,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (tree, record) {
            final node = tree.findFirst<Timestamp>();
            if (node != null) {
              node.replaceSpan(_BracketedSpan(child: node.span));
            }
          },
        ],
      );

      final buffer = ConsoleMessageBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      // Timestamp wrapped with brackets
      expect(result, contains('[10:23:45.123]'));
    });

    test('removes Timestamp entirely', () {
      final record = LogRecord(
        message: 'Hello',
        date: DateTime(2024, 1, 15, 10, 23, 45, 123),
        level: ChirpLogLevel.info,
      );

      final formatter = RainbowMessageFormatter(
        options: const RainbowFormatOptions(
          showTime: true,
          showLocation: false,
          showLogger: false,
          showClass: false,
          showMethod: false,
          showLogLevel: false,
        ),
        spanTransformers: [
          (tree, record) {
            tree.findFirst<Timestamp>()?.remove();
          },
        ],
      );

      final buffer = ConsoleMessageBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      // No timestamp in output
      expect(result, isNot(contains('10:23:45.123')));
      expect(result, contains('Hello'));
    });
  });

  group('SpanNode', () {
    group('wrap', () {
      test('wraps a leaf span with Colored', () {
        final tree = SpanNode.fromSpan(const PlainText('hello'));

        tree.wrap((child) =>
            AnsiColored(foreground: XtermColor.red1_196, child: child));

        expect(tree.span, isA<AnsiColored>());
        expect((tree.span as AnsiColored).foreground, XtermColor.red1_196);
        expect(tree.children.length, 1);
        expect(tree.children.first.span, isA<PlainText>());
        expect((tree.children.first.span as PlainText).value, 'hello');
      });

      test('wraps a node inside a tree', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('before'),
          PlainText('target'),
          PlainText('after'),
        ]));

        final target = tree.children[1];
        target.wrap((child) =>
            AnsiColored(foreground: XtermColor.blue1_21, child: child));

        final result = tree.span;
        final buffer = ConsoleMessageBuffer();
        renderSpan(result, buffer);
        expect(buffer.toString(), 'beforetargetafter');

        // Structure check
        expect(tree.children[1].span, isA<AnsiColored>());
        expect(tree.children[1].children.first.span, isA<PlainText>());
      });

      test('wrap preserves parent reference', () {
        final tree =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));

        final child = tree.children.first;
        child.wrap(
            (c) => AnsiColored(foreground: XtermColor.red1_196, child: c));

        expect(tree.children.first.parent, tree);
        expect(tree.children.first.children.first.parent, tree.children.first);
      });
    });

    group('unwrap', () {
      test('unwraps a Colored span to its child', () {
        final tree = SpanNode.fromSpan(const AnsiColored(
          foreground: XtermColor.red1_196,
          child: PlainText('hello'),
        ));

        expect(tree.unwrap(), isTrue);
        expect(tree.span, isA<PlainText>());
        expect((tree.span as PlainText).value, 'hello');
        expect(tree.children, isEmpty);
      });

      test('unwraps a node inside a tree', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('before'),
          AnsiColored(
              foreground: XtermColor.red1_196, child: PlainText('target')),
          PlainText('after'),
        ]));

        final styledNode = tree.children[1];
        expect(styledNode.unwrap(), isTrue);

        expect(tree.children[1].span, isA<PlainText>());
        expect((tree.children[1].span as PlainText).value, 'target');
      });

      test('unwrap returns false for leaf spans', () {
        final tree = SpanNode.fromSpan(const PlainText('hello'));
        expect(tree.unwrap(), isFalse);
        expect(tree.span, isA<PlainText>());
      });

      test('unwrap returns false for multi-child spans', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('b'),
        ]));
        expect(tree.unwrap(), isFalse);
        expect(tree.span, isA<SpanSequence>());
      });

      test('unwrap preserves parent reference', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          AnsiColored(
              foreground: XtermColor.red1_196, child: PlainText('child')),
        ]));

        final styledNode = tree.children.first;
        styledNode.unwrap();

        expect(tree.children.first.parent, tree);
      });
    });

    test('wrap then unwrap restores original', () {
      final tree = SpanNode.fromSpan(const PlainText('hello'));

      tree.wrap((child) =>
          AnsiColored(foreground: XtermColor.red1_196, child: child));
      expect(tree.span, isA<AnsiColored>());

      tree.unwrap();
      expect(tree.span, isA<PlainText>());
      expect((tree.span as PlainText).value, 'hello');
    });

    group('previousSibling', () {
      test('returns null for root node', () {
        final tree = SpanNode.fromSpan(const PlainText('hello'));
        expect(tree.previousSibling, isNull);
      });

      test('returns null for first child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('first'),
          PlainText('second'),
          PlainText('third'),
        ]));
        expect(tree.children[0].previousSibling, isNull);
      });

      test('returns previous sibling for middle child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('first'),
          PlainText('second'),
          PlainText('third'),
        ]));
        final middle = tree.children[1];
        expect(middle.previousSibling, tree.children[0]);
        expect((middle.previousSibling!.span as PlainText).value, 'first');
      });

      test('returns previous sibling for last child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('first'),
          PlainText('second'),
          PlainText('third'),
        ]));
        final last = tree.children[2];
        expect(last.previousSibling, tree.children[1]);
        expect((last.previousSibling!.span as PlainText).value, 'second');
      });
    });

    group('nextSibling', () {
      test('returns null for root node', () {
        final tree = SpanNode.fromSpan(const PlainText('hello'));
        expect(tree.nextSibling, isNull);
      });

      test('returns null for last child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('first'),
          PlainText('second'),
          PlainText('third'),
        ]));
        expect(tree.children[2].nextSibling, isNull);
      });

      test('returns next sibling for first child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('first'),
          PlainText('second'),
          PlainText('third'),
        ]));
        final first = tree.children[0];
        expect(first.nextSibling, tree.children[1]);
        expect((first.nextSibling!.span as PlainText).value, 'second');
      });

      test('returns next sibling for middle child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('first'),
          PlainText('second'),
          PlainText('third'),
        ]));
        final middle = tree.children[1];
        expect(middle.nextSibling, tree.children[2]);
        expect((middle.nextSibling!.span as PlainText).value, 'third');
      });
    });

    test('sibling navigation chain', () {
      final tree = SpanNode.fromSpan(const SpanSequence([
        PlainText('a'),
        PlainText('b'),
        PlainText('c'),
      ]));

      final a = tree.children[0];
      final b = tree.children[1];
      final c = tree.children[2];

      // Forward navigation
      expect(a.nextSibling, b);
      expect(b.nextSibling, c);
      expect(c.nextSibling, isNull);

      // Backward navigation
      expect(c.previousSibling, b);
      expect(b.previousSibling, a);
      expect(a.previousSibling, isNull);
    });

    group('append', () {
      test('adds child to empty node', () {
        final tree = SpanNode.fromSpan(const SpanSequence([]));
        final child = SpanNode.fromSpan(const PlainText('hello'));

        tree.append(child);

        expect(tree.children.length, 1);
        expect(tree.children.first, child);
        expect(child.parent, tree);
      });

      test('adds child at the end', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('b'),
        ]));
        final child = SpanNode.fromSpan(const PlainText('c'));

        tree.append(child);

        expect(tree.children.length, 3);
        expect(tree.children[2], child);
        expect((tree.children[2].span as PlainText).value, 'c');
        expect(child.parent, tree);
      });

      test('removes child from previous parent', () {
        final parent1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final parent2 = SpanNode.fromSpan(const SpanSequence([]));
        final child = parent1.children.first;

        parent2.append(child);

        expect(parent1.children, isEmpty);
        expect(parent2.children.length, 1);
        expect(parent2.children.first, child);
        expect(child.parent, parent2);
      });

      test('moves child between parents preserves identity', () {
        final parent1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('moving')]));
        final parent2 =
            SpanNode.fromSpan(const SpanSequence([PlainText('existing')]));
        final child = parent1.children.first;

        parent2.append(child);

        expect(identical(parent2.children[1], child), isTrue);
        expect(child.parent, parent2);
        expect(parent1.children, isEmpty);
      });
    });

    group('prepend', () {
      test('adds child to empty node', () {
        final tree = SpanNode.fromSpan(const SpanSequence([]));
        final child = SpanNode.fromSpan(const PlainText('hello'));

        tree.prepend(child);

        expect(tree.children.length, 1);
        expect(tree.children.first, child);
        expect(child.parent, tree);
      });

      test('adds child at the beginning', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('b'),
          PlainText('c'),
        ]));
        final child = SpanNode.fromSpan(const PlainText('a'));

        tree.prepend(child);

        expect(tree.children.length, 3);
        expect(tree.children[0], child);
        expect((tree.children[0].span as PlainText).value, 'a');
        expect((tree.children[1].span as PlainText).value, 'b');
        expect((tree.children[2].span as PlainText).value, 'c');
        expect(child.parent, tree);
      });

      test('removes child from previous parent', () {
        final parent1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final parent2 =
            SpanNode.fromSpan(const SpanSequence([PlainText('existing')]));
        final child = parent1.children.first;

        parent2.prepend(child);

        expect(parent1.children, isEmpty);
        expect(parent2.children.length, 2);
        expect(parent2.children.first, child);
        expect(child.parent, parent2);
      });

      test('existing children have correct parent after prepend', () {
        final tree =
            SpanNode.fromSpan(const SpanSequence([PlainText('existing')]));
        final newChild = SpanNode.fromSpan(const PlainText('new'));
        final existingChild = tree.children.first;

        tree.prepend(newChild);

        expect(existingChild.parent, tree);
        expect(newChild.parent, tree);
        expect(tree.children[0], newChild);
        expect(tree.children[1], existingChild);
      });
    });

    group('insertBefore', () {
      test('returns false for root node', () {
        final tree = SpanNode.fromSpan(const PlainText('root'));
        final newNode = SpanNode.fromSpan(const PlainText('new'));

        expect(tree.insertBefore(newNode), isFalse);
      });

      test('inserts before first child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('b'),
        ]));
        final newNode = SpanNode.fromSpan(const PlainText('new'));
        final firstChild = tree.children[0];

        expect(firstChild.insertBefore(newNode), isTrue);

        expect(tree.children.length, 3);
        expect(tree.children[0], newNode);
        expect(tree.children[1], firstChild);
        expect((tree.children[0].span as PlainText).value, 'new');
        expect((tree.children[1].span as PlainText).value, 'a');
        expect(newNode.parent, tree);
      });

      test('inserts before middle child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('b'),
          PlainText('c'),
        ]));
        final newNode = SpanNode.fromSpan(const PlainText('new'));
        final middleChild = tree.children[1];

        expect(middleChild.insertBefore(newNode), isTrue);

        expect(tree.children.length, 4);
        expect((tree.children[0].span as PlainText).value, 'a');
        expect((tree.children[1].span as PlainText).value, 'new');
        expect((tree.children[2].span as PlainText).value, 'b');
        expect((tree.children[3].span as PlainText).value, 'c');
        expect(newNode.parent, tree);
      });

      test('removes node from previous parent', () {
        final parent1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('moving')]));
        final parent2 =
            SpanNode.fromSpan(const SpanSequence([PlainText('target')]));
        final movingNode = parent1.children.first;
        final targetNode = parent2.children.first;

        expect(targetNode.insertBefore(movingNode), isTrue);

        expect(parent1.children, isEmpty);
        expect(parent2.children.length, 2);
        expect(parent2.children[0], movingNode);
        expect(parent2.children[1], targetNode);
        expect(movingNode.parent, parent2);
      });

      test('sibling relationships correct after insertBefore', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('c'),
        ]));
        final newNode = SpanNode.fromSpan(const PlainText('b'));
        final c = tree.children[1];

        c.insertBefore(newNode);

        final a = tree.children[0];
        final b = tree.children[1];
        expect(a.nextSibling, b);
        expect(b.previousSibling, a);
        expect(b.nextSibling, c);
        expect(c.previousSibling, b);
      });
    });

    group('insertAfter', () {
      test('returns false for root node', () {
        final tree = SpanNode.fromSpan(const PlainText('root'));
        final newNode = SpanNode.fromSpan(const PlainText('new'));

        expect(tree.insertAfter(newNode), isFalse);
      });

      test('inserts after last child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('b'),
        ]));
        final newNode = SpanNode.fromSpan(const PlainText('new'));
        final lastChild = tree.children[1];

        expect(lastChild.insertAfter(newNode), isTrue);

        expect(tree.children.length, 3);
        expect(tree.children[2], newNode);
        expect((tree.children[2].span as PlainText).value, 'new');
        expect(newNode.parent, tree);
      });

      test('inserts after first child', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('c'),
        ]));
        final newNode = SpanNode.fromSpan(const PlainText('b'));
        final firstChild = tree.children[0];

        expect(firstChild.insertAfter(newNode), isTrue);

        expect(tree.children.length, 3);
        expect((tree.children[0].span as PlainText).value, 'a');
        expect((tree.children[1].span as PlainText).value, 'b');
        expect((tree.children[2].span as PlainText).value, 'c');
        expect(newNode.parent, tree);
      });

      test('removes node from previous parent', () {
        final parent1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('moving')]));
        final parent2 =
            SpanNode.fromSpan(const SpanSequence([PlainText('target')]));
        final movingNode = parent1.children.first;
        final targetNode = parent2.children.first;

        expect(targetNode.insertAfter(movingNode), isTrue);

        expect(parent1.children, isEmpty);
        expect(parent2.children.length, 2);
        expect(parent2.children[0], targetNode);
        expect(parent2.children[1], movingNode);
        expect(movingNode.parent, parent2);
      });

      test('sibling relationships correct after insertAfter', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('c'),
        ]));
        final newNode = SpanNode.fromSpan(const PlainText('b'));
        final a = tree.children[0];

        a.insertAfter(newNode);

        final b = tree.children[1];
        final c = tree.children[2];
        expect(a.nextSibling, b);
        expect(b.previousSibling, a);
        expect(b.nextSibling, c);
        expect(c.previousSibling, b);
      });
    });

    group('parent/child consistency', () {
      test('all children have correct parent after multiple operations', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('a'),
          PlainText('b'),
        ]));

        final newFirst = SpanNode.fromSpan(const PlainText('first'));
        final newMiddle = SpanNode.fromSpan(const PlainText('middle'));
        final newLast = SpanNode.fromSpan(const PlainText('last'));

        tree.prepend(newFirst);
        tree.children[2].insertBefore(newMiddle);
        tree.append(newLast);

        // Verify all children point to tree as parent
        for (final child in tree.children) {
          expect(child.parent, tree,
              reason: 'child ${child.span} should have tree as parent');
        }

        // Verify order: first, a, middle, b, last
        expect((tree.children[0].span as PlainText).value, 'first');
        expect((tree.children[1].span as PlainText).value, 'a');
        expect((tree.children[2].span as PlainText).value, 'middle');
        expect((tree.children[3].span as PlainText).value, 'b');
        expect((tree.children[4].span as PlainText).value, 'last');
      });

      test('moving node clears old parent relationship', () {
        final parent1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final parent2 = SpanNode.fromSpan(const SpanSequence([]));
        final child = parent1.children.first;

        // Move child to parent2
        parent2.append(child);

        // child should no longer be in parent1's children
        expect(parent1.children.contains(child), isFalse);
        // child's parent should be parent2
        expect(child.parent, parent2);
      });

      test('toSpan preserves structure after mutations', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          PlainText('b'),
        ]));

        tree.prepend(SpanNode.fromSpan(const PlainText('a')));
        tree.append(SpanNode.fromSpan(const PlainText('c')));

        final span = tree.span;
        final buffer = ConsoleMessageBuffer();
        renderSpan(span, buffer);

        expect(buffer.toString(), 'abc');
      });
    });

    group('allAncestors', () {
      test('returns empty for root node', () {
        final tree = SpanNode.fromSpan(const PlainText('root'));
        expect(tree.allAncestors, isEmpty);
      });

      test('returns parent for direct child', () {
        final tree =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final child = tree.children.first;

        final ancestors = child.allAncestors.toList();

        expect(ancestors.length, 1);
        expect(ancestors[0], tree);
      });

      test('returns ancestors from parent to root', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          AnsiColored(
            foreground: XtermColor.red1_196,
            child: PlainText('deep'),
          ),
        ]));
        final colored = tree.children.first;
        final deep = colored.children.first;

        final ancestors = deep.allAncestors.toList();

        expect(ancestors.length, 2);
        expect(ancestors[0], colored, reason: 'first ancestor is parent');
        expect(ancestors[1], tree, reason: 'last ancestor is root');
      });

      test('does not include self', () {
        final tree =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final child = tree.children.first;

        expect(child.allAncestors.contains(child), isFalse);
      });
    });

    group('root', () {
      test('returns self for root node', () {
        final tree = SpanNode.fromSpan(const PlainText('root'));
        expect(tree.root, tree);
      });

      test('returns root from direct child', () {
        final tree =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final child = tree.children.first;

        expect(child.root, tree);
      });

      test('returns root from deeply nested node', () {
        final tree = SpanNode.fromSpan(const SpanSequence([
          AnsiColored(
            foreground: XtermColor.red1_196,
            child: SpanSequence([
              PlainText('deep'),
            ]),
          ),
        ]));
        final deep = tree.children.first.children.first.children.first;

        expect(deep.root, tree);
      });

      test('root updates after moving node', () {
        final tree1 =
            SpanNode.fromSpan(const SpanSequence([PlainText('child')]));
        final tree2 = SpanNode.fromSpan(const SpanSequence([]));
        final child = tree1.children.first;

        expect(child.root, tree1);

        tree2.append(child);

        expect(child.root, tree2);
      });
    });
  });
}

/// Custom span that shows an emoji based on log level.
class _LevelEmojiSpan extends LogSpan {
  final ChirpLogLevel level;

  const _LevelEmojiSpan(this.level);

  @override
  LogSpan build() {
    final emoji = switch (level.severity) {
      >= 500 => '❌',
      >= 400 => '⚠️',
      >= 300 => 'ℹ️',
      _ => '🔍',
    };
    return PlainText(emoji);
  }
}

/// Custom span that wraps a child with brackets.
class _BracketedSpan extends LogSpan {
  final LogSpan child;

  const _BracketedSpan({required this.child});

  @override
  LogSpan build() =>
      SpanSequence([const PlainText('['), child, const PlainText(']')]);
}
