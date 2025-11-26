// ignore_for_file: avoid_redundant_argument_values

import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('Colored', () {
    test('nested Colored colors override parent colors', () {
      // Parent: red, Child: blue
      // "Hello " should be red, "World" should be blue
      final span = AnsiColored(
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
            final timestamp = tree.findFirst<Timestamp>();
            timestamp?.replaceWith(_LevelEmojiSpan(record.level));
          },
        ],
      );

      final buffer = ConsoleMessageBuffer();
      formatter.format(record, buffer);
      final result = buffer.toString();

      expect(result, '\u{1f50d} Hello');
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
            final timestamp = tree.findFirst<Timestamp>();
            if (timestamp != null) {
              timestamp.wrap((child) => _BracketedSpan(child: child));
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

  group('LogSpan tree manipulation', () {
    group('replaceWith', () {
      test('replaces a leaf span in parent', () {
        final sequence = SpanSequence([
          PlainText('before'),
          PlainText('target'),
          PlainText('after'),
        ]);

        final target = sequence.children[1];
        target.replaceWith(PlainText('replaced'));

        final buffer = ConsoleMessageBuffer();
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'beforereplacedafter');
      });

      test('replaces nested span', () {
        final outer = AnsiColored(
          foreground: XtermColor.red1_196,
          child: PlainText('nested'),
        );
        final sequence = SpanSequence([outer]);

        outer.child!.replaceWith(PlainText('replaced'));

        final buffer = ConsoleMessageBuffer();
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'replaced');
      });

      test('returns false for root span', () {
        final span = PlainText('root');
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('updates parent references correctly', () {
        final sequence = SpanSequence([PlainText('child')]);
        final newSpan = PlainText('new');

        sequence.children.first.replaceWith(newSpan);

        expect(newSpan.parent, sequence);
      });
    });

    group('remove', () {
      test('removes span from parent', () {
        final sequence = SpanSequence([
          PlainText('a'),
          PlainText('b'),
          PlainText('c'),
        ]);

        sequence.children[1].remove();

        final buffer = ConsoleMessageBuffer();
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'ac');
      });

      test('returns false for root span', () {
        final span = PlainText('root');
        expect(span.remove(), isFalse);
      });

      test('clears parent reference after removal', () {
        final sequence = SpanSequence([PlainText('child')]);
        final child = sequence.children.first;

        child.remove();

        expect(child.parent, isNull);
      });
    });

    group('wrap', () {
      test('wraps a span with colored', () {
        final sequence = SpanSequence([PlainText('hello')]);
        final child = sequence.children.first;

        child.wrap((c) => AnsiColored(foreground: XtermColor.red1_196, child: c));

        expect(sequence.children.first, isA<AnsiColored>());
        expect((sequence.children.first as SingleChildSpan).child, isA<PlainText>());
      });

      test('preserves rendering after wrap', () {
        final sequence = SpanSequence([PlainText('hello')]);
        final child = sequence.children.first;

        child.wrap((c) => AnsiColored(foreground: XtermColor.red1_196, child: c));

        final buffer = ConsoleMessageBuffer();
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
        final sequence = SpanSequence([
          PlainText('before'),
          AnsiColored(child: timestamp),
        ]);

        expect(sequence.findFirst<Timestamp>(), timestamp);
      });

      test('returns null when not found', () {
        final sequence = SpanSequence([PlainText('hello')]);
        expect(sequence.findFirst<Timestamp>(), isNull);
      });
    });

    group('findAll', () {
      test('finds all matching spans', () {
        final t1 = PlainText('a');
        final t2 = PlainText('b');
        final t3 = PlainText('c');
        final sequence = SpanSequence([
          t1,
          AnsiColored(child: t2),
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
        final span = AnsiColored(child: child);
        expect(span.allChildren.toList(), [child]);
      });

      test('returns all children for multi child span', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final c = PlainText('c');
        final span = SpanSequence([a, b, c]);
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
        final inner = AnsiColored(child: b);
        final sequence = SpanSequence([a, inner]);

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
        final middle = AnsiColored(child: deep);
        final root = SpanSequence([middle]);

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
        final root = SpanSequence([AnsiColored(child: deep)]);

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
        final parent = SpanSequence([child]);

        expect(child.parent, parent);
      });
    });

    group('MultiChildSpan operations', () {
      test('addChild adds to end', () {
        final sequence = SpanSequence([PlainText('a')]);
        sequence.addChild(PlainText('b'));

        final buffer = ConsoleMessageBuffer();
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'ab');
      });

      test('insertChild at index', () {
        final sequence = SpanSequence([PlainText('a'), PlainText('c')]);
        sequence.insertChild(1, PlainText('b'));

        final buffer = ConsoleMessageBuffer();
        renderSpan(sequence, buffer);
        expect(buffer.toString(), 'abc');
      });

      test('indexOf returns correct index', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final sequence = SpanSequence([a, b]);

        expect(sequence.indexOf(a), 0);
        expect(sequence.indexOf(b), 1);
      });

      test('previousSiblingOf and nextSiblingOf', () {
        final a = PlainText('a');
        final b = PlainText('b');
        final c = PlainText('c');
        final sequence = SpanSequence([a, b, c]);

        expect(sequence.previousSiblingOf(a), isNull);
        expect(sequence.previousSiblingOf(b), a);
        expect(sequence.nextSiblingOf(b), c);
        expect(sequence.nextSiblingOf(c), isNull);
      });
    });

    group('SingleChildSpan operations', () {
      test('setting child updates parent reference', () {
        final span = AnsiColored();
        final child = PlainText('hello');

        span.child = child;

        expect(child.parent, span);
      });

      test('replacing child clears old parent reference', () {
        final span = AnsiColored();
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

        final buffer = ConsoleMessageBuffer();
        renderSpan(surrounded, buffer);
        expect(buffer.toString(), '[content]');
      });

      test('renders empty when child is null', () {
        final surrounded = Surrounded(
          prefix: PlainText('['),
          suffix: PlainText(']'),
        );

        final buffer = ConsoleMessageBuffer();
        renderSpan(surrounded, buffer);
        expect(buffer.toString(), isEmpty);
      });
    });

    group('complex tree operations', () {
      test('multiple operations preserve consistency', () {
        final sequence = SpanSequence([
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
          expect(child.parent, sequence,
              reason: 'child ${child} should have sequence as parent');
        }

        // Verify output
        final buffer = ConsoleMessageBuffer();
        renderSpan(sequence, buffer);
        expect(buffer.toString(), '0abc');
      });

      test('moving child between parents', () {
        final parent1 = SpanSequence([PlainText('child')]);
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
        final inner = AnsiColored(child: PlainText('inner'));
        final outer = SpanSequence([inner]);

        final newSpan = AnsiColored(child: PlainText('replaced'));
        final result = inner.replaceWith(newSpan);

        expect(result, isTrue);
        expect(outer.children.first, newSpan);
        expect(newSpan.parent, outer);
        expect(inner.parent, isNull);
      });

      test('remove when SingleChildSpan has a parent', () {
        final inner = AnsiColored(child: PlainText('inner'));
        final outer = SpanSequence([inner]);

        final result = inner.remove();

        expect(result, isTrue);
        expect(outer.children, isEmpty);
        expect(inner.parent, isNull);
      });

      test('replaceWith returns false for root SingleChildSpan', () {
        final span = AnsiColored(child: PlainText('child'));
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('remove returns false for root SingleChildSpan', () {
        final span = AnsiColored(child: PlainText('child'));
        expect(span.remove(), isFalse);
      });
    });

    group('MultiChildSpan as nested child', () {
      test('replaceWith when MultiChildSpan has a parent', () {
        final inner = SpanSequence([PlainText('a'), PlainText('b')]);
        final outer = AnsiColored(child: inner);

        final newSpan = SpanSequence([PlainText('replaced')]);
        final result = inner.replaceWith(newSpan);

        expect(result, isTrue);
        expect(outer.child, newSpan);
        expect(newSpan.parent, outer);
        expect(inner.parent, isNull);
      });

      test('remove when MultiChildSpan has a parent', () {
        final inner = SpanSequence([PlainText('a')]);
        final outer = AnsiColored(child: inner);

        final result = inner.remove();

        expect(result, isTrue);
        expect(outer.child, isNull);
        expect(inner.parent, isNull);
      });

      test('replaceWith returns false for root MultiChildSpan', () {
        final span = SpanSequence([PlainText('child')]);
        expect(span.replaceWith(PlainText('new')), isFalse);
      });

      test('remove returns false for root MultiChildSpan', () {
        final span = SpanSequence([PlainText('child')]);
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
        final outer = SpanSequence([inner]);

        final newSpan = Surrounded(child: PlainText('new'));
        final result = inner.replaceWith(newSpan);

        expect(result, isTrue);
        expect(outer.children.first, newSpan);
        expect(newSpan.parent, outer);
        expect(inner.parent, isNull);
      });

      test('remove when SlottedSpan has a parent', () {
        final inner = Surrounded(child: PlainText('content'));
        final outer = SpanSequence([inner]);

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

        child.wrap((c) => AnsiColored(foreground: XtermColor.red1_196, child: c));

        expect(surrounded.child, isA<AnsiColored>());
        expect((surrounded.child as AnsiColored).child, isA<PlainText>());
      });

      test('wrap preserves slot position', () {
        final prefix = PlainText('[');
        final content = PlainText('content');
        final surrounded = Surrounded(
          prefix: prefix,
          child: content,
        );

        prefix.wrap((c) => AnsiColored(foreground: XtermColor.blue1_21, child: c));

        expect(surrounded.prefix, isA<AnsiColored>());

        final buffer = ConsoleMessageBuffer();
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

        final buffer = ConsoleMessageBuffer();
        renderSpan(fancyTimestamp, buffer);

        // Should render as ">>> 10:23:45.123 <<<"
        expect(buffer.toString(), '>>> 10:23:45.123 <<<');
      });

      test('triple chained build works', () {
        // Chain: Level3 -> Level2 -> Level1 -> PlainText
        final span = _Level3Span('hello');

        final buffer = ConsoleMessageBuffer();
        renderSpan(span, buffer);

        expect(buffer.toString(), '<<<[[[hello]]]>>>');
      });
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
    return SpanSequence([
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
