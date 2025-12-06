# Span-Based Formatting

Chirp's console formatters use a **span-based formatting system** - a composable tree of rendering elements similar to Flutter widgets. If you're familiar with Flutter's widget tree, you'll feel right at home: spans are composable, nestable, and each span knows how to render itself.

> **When to use spans:** The span API is designed for **human-readable console output** with colors, formatting, and visual structure. For machine-readable logs (log files, log aggregators, cloud logging), use JSON formatters like `JsonMessageFormatter` instead.

## Spans Work Like Flutter Widgets

Just like Flutter widgets, spans form a tree where each node is responsible for its own rendering:

```dart
// Flutter Widget tree
Column(
  children: [
    Text('Hello'),
    Padding(
      padding: EdgeInsets.all(8),
      child: Text('World'),
    ),
  ],
)

// Chirp Span tree - same concept!
SpanSequence(children: [
  PlainText('Hello'),
  AnsiStyled(
    foreground: Ansi16.blue,
    child: PlainText('World'),
  ),
])
```

Key similarities:
- **Composable**: Combine simple spans to create complex output
- **Single child vs multi child**: `AnsiStyled` wraps one child, `SpanSequence` holds many
- **Nested styling**: Colors and formatting cascade through the tree
- **Declarative**: Describe what you want, not how to build it

## SpanSequence - Your Starting Point

Almost every formatter starts with `SpanSequence` - it's like Flutter's `Row`, rendering children one after another:

```dart
SpanSequence(children: [
  Timestamp(record.date),        // 14:32:05.123
  Whitespace(),                  // ' '
  BracketedLogLevel(record.level), // [INFO]
  Whitespace(),                  // ' '
  LogMessage(record.message),    // User logged in
])
// Output: 14:32:05.123 [INFO] User logged in
```

Nest sequences and styled spans to build complex output:

```dart
SpanSequence(children: [
  AnsiStyled(
    foreground: Ansi16.brightBlack,
    child: Timestamp(record.date),
  ),
  Whitespace(),
  AnsiStyled(
    foreground: Ansi16.green,
    child: LogMessage(record.message),
  ),
])
```

## Creating Custom Spans

Create your own spans by extending the base span classes:

```dart
/// A span that displays a request ID with cyan coloring
class RequestIdSpan extends LeafSpan {
  final String requestId;
  RequestIdSpan(this.requestId);

  @override
  LogSpan build() {
    // build() transforms this semantic span into renderable spans
    return AnsiStyled(
      foreground: Ansi16.cyan,
      child: PlainText('[$requestId]'),
    );
  }
}

/// A span that shows an emoji based on log level
class LevelEmojiSpan extends LeafSpan {
  final ChirpLogLevel level;
  LevelEmojiSpan(this.level);

  @override
  LogSpan build() {
    final emoji = switch (level.severity) {
      >= 500 => '🔴',  // Error+
      >= 400 => '🟡',  // Warning
      >= 200 => '🟢',  // Info
      _ => '⚪',       // Debug/Trace
    };
    return PlainText(emoji);
  }
}
```

## Creating a Custom Span-Based Formatter

To create your own formatter with complete control over the output, extend `SpanBasedFormatter`:

```dart
class MyConsoleFormatter extends SpanBasedFormatter {
  @override
  LogSpan buildSpan(LogRecord record) {
    // Build your span tree - this is your "widget tree" for the log line
    return SpanSequence(children: [
      // Emoji based on level
      LevelEmojiSpan(record.level),
      Whitespace(),

      // Timestamp in gray
      AnsiStyled(
        foreground: Ansi16.brightBlack,
        child: Timestamp(record.date),
      ),
      Whitespace(),

      // Log message - colored by level
      AnsiStyled(
        foreground: _colorForLevel(record.level),
        child: LogMessage(record.message),
      ),

      // Optional: show data if present
      if (record.data?.isNotEmpty ?? false) ...[
        NewLine(),
        MultilineData(record.data),
      ],
    ]);
  }

  IndexedColor _colorForLevel(ChirpLogLevel level) {
    return switch (level.severity) {
      >= 500 => Ansi16.red,
      >= 400 => Ansi16.yellow,
      _ => Ansi16.white,
    };
  }
}
```

Use your formatter:
```dart
Chirp.root = ChirpLogger(
  writers: [
    PrintConsoleWriter(formatter: MyConsoleFormatter()),
  ],
);
```

## Transforming Existing Formatters

Don't want to build a formatter from scratch? Use **span transformers** to modify the output of existing formatters. This is perfect for small tweaks:

```dart
final formatter = RainbowMessageFormatter(
  spanTransformers: [
    (tree, record) {
      // The tree is mutable - find spans and modify them!

      // Replace timestamp with emoji
      tree.findFirst<Timestamp>()?.replaceWith(
        LevelEmojiSpan(record.level),
      );
    },
  ],
);
```

**Tree Navigation** - find spans anywhere in the tree:
```dart
tree.findFirst<Timestamp>();     // First matching span
tree.findAll<AnsiStyled>();     // All matching spans
tree.allDescendants;             // Every span in the tree
```

**Tree Modification** - mutate the tree before rendering:
```dart
// Replace a span with something else
span.replaceWith(PlainText('replacement'));

// Remove a span entirely
span.remove();

// Wrap a span with another span
span.wrap((child) => AnsiStyled(
  foreground: Ansi16.red,
  child: child,
));
```

## Transformer Examples

**Add emoji prefix to messages:**
```dart
(tree, record) {
  final emoji = switch (record.level.name) {
    'error' => '🔴 ',
    'warning' => '🟡 ',
    'info' => '🟢 ',
    _ => '⚪ ',
  };
  tree.findFirst<LogMessage>()?.wrap(
    (child) => SpanSequence(children: [PlainText(emoji), child]),
  );
}
```

**Remove timestamps (useful for tests with golden output):**
```dart
(tree, record) {
  tree.findFirst<Timestamp>()?.remove();
}
```

**Highlight errors with red background:**
```dart
(tree, record) {
  if (record.level.severity >= 500) {
    tree.findFirst<LogMessage>()?.wrap(
      (child) => AnsiStyled(
        background: Ansi16.red,
        foreground: Ansi16.white,
        child: child,
      ),
    );
  }
}
```

**Add borders around critical logs:**
```dart
(tree, record) {
  if (record.level.name == 'critical') {
    // Wrap the entire tree
    tree.wrap((child) => Bordered(
      style: BoxBorderStyle.double,
      child: child,
    ));
  }
}
```

## Smart Color Nesting

The span system handles nested colors correctly. When you pop a color, it restores the previous color instead of resetting to default:

```dart
AnsiStyled(
  foreground: Ansi16.red,
  child: SpanSequence(children: [
    PlainText('red '),
    AnsiStyled(
      foreground: Ansi16.blue,
      child: PlainText('blue'),
    ),
    PlainText(' red again'),  // Correctly returns to red!
  ]),
)
```

This "just works" because colors are managed as a stack internally.

## Built-in Span Reference

**Basic Text Spans:**
```dart
PlainText('hello')     // hello
Whitespace()           // (single space)
NewLine()              // (line break)
EmptySpan()            // (renders nothing - like SizedBox.shrink())
```

**Semantic Spans** - these know how to format log data:
```dart
Timestamp(dateTime)                                    // 14:32:05.123
FullTimestamp(dateTime)                                // 2025-01-15 14:32:05.123
BracketedLogLevel(ChirpLogLevel.info)                  // [info]
LogMessage('User logged in')                           // User logged in
LoggerName('payment')                                  // payment
ClassName('UserService', instanceHash: 'a1b2')         // UserService@a1b2
MethodName('fetchUser')                                // fetchUser
DartSourceCodeLocation(fileName: 'user.dart', line: 42) // user.dart:42
InlineData({'userId': '123'})                          //  (userId: "123")
MultilineData({'a': 1, 'b': 2})                        // a: 1
                                                       // b: 2
ErrorSpan(exception)                                   // Exception: Something went wrong
StackTraceSpan(stackTrace)                             // #0 main (file.dart:10)
                                                       // #1 ...
```

**Container Spans:**
```dart
SpanSequence(children: [a, b, c])                // Renders a, b, c in order
AnsiStyled(foreground: Ansi16.red, child: span)  // Colored text
Bordered(style: BoxBorderStyle.rounded, child: span)  // ╭─────╮
                                                      // │text │
                                                      // ╰─────╯
Surrounded(prefix: PlainText('['), child: span, suffix: PlainText(']'))
// Only renders if child is non-null: [text] or nothing
```

## When to Use Spans vs JSON

| Use Case | Recommended Approach |
|----------|---------------------|
| Development console | Span-based formatters (`RainbowMessageFormatter`) |
| CI/CD logs | Span-based or simple text formatters |
| Log files | `JsonMessageFormatter` |
| Cloud logging (GCP, AWS) | JSON formatters |
| Log aggregators (ELK, Datadog) | JSON formatters |
| Debugging with colors | Span-based formatters |

**Example: Multiple writers for different outputs:**
```dart
Chirp.root = ChirpLogger()
  // Pretty console output for humans
  .addConsoleWriter(formatter: RainbowMessageFormatter())
  // JSON for log files - no spans needed
  .addConsoleWriter(
    formatter: JsonMessageFormatter(),
    output: (msg) => logFile.writeAsStringSync('$msg\n', mode: FileMode.append),
  );
```
