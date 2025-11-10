# Architecture Migration: Writer-Owns-Formatter Pattern

## What Changed

Chirp now follows the **Handler-owns-Formatter** pattern used by 18 out of 21 popular logging libraries researched (Python logging, Log4j, Logback, Serilog, winston, NLog, Semantic Logger, and more).

### Before (Old Architecture)
```dart
// ❌ OLD: Chirp owned both formatter and writer separately
Chirp.root = Chirp(
  formatter: JsonChirpMessageFormatter(),  // One formatter for all writers
  writer: MultiChirpMessageWriter([
    ConsoleChirpMessageWriter(),
    FileChirpMessageWriter(),
  ]),
);

// Problem: Both console and file get the SAME format
```

### After (New Architecture)
```dart
// ✅ NEW: Writers own their formatters
Chirp.root = Chirp(
  writer: MultiChirpMessageWriter([
    ConsoleChirpMessageWriter(
      formatter: DefaultChirpMessageFormatter(), // Colored for console
    ),
    ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),    // JSON for file
      output: (msg) => File('app.log').writeAsStringSync('$msg\n'),
    ),
  ]),
);

// Now: Each destination has its own format!
```

## Benefits

### 1. Different Formats Per Destination
```dart
// Console: Colorful for developers
// File: JSON for log aggregation tools
// Remote: Compact for bandwidth efficiency

Chirp.root = Chirp(
  writer: MultiChirpMessageWriter([
    ConsoleChirpMessageWriter(
      formatter: DefaultChirpMessageFormatter(), // Colors + pretty
    ),
    ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),    // Machine-readable
      output: fileWriter,
    ),
    ConsoleChirpMessageWriter(
      formatter: CompactChirpMessageFormatter(), // Minimal
      output: httpSender,
    ),
  ]),
);
```

### 2. Follows Industry Standards
Matches architecture of:
- Python `logging` (Handler owns Formatter)
- Java `Log4j` (Appender owns Layout)
- Java `Logback` (Appender owns Encoder)
- C# `Serilog` (Sink owns Formatter)
- JavaScript `winston` (Transport owns Format)
- Ruby `Semantic Logger` (Appender owns Formatter)
- And 12 more libraries

### 3. Cleaner Separation of Concerns
- **Chirp**: Creates structured LogEntry
- **Writer**: Decides HOW to format and WHERE to write
- **Formatter**: Transforms LogEntry → String

## Technical Changes

### ChirpMessageWriter Interface
```dart
// Before
abstract class ChirpMessageWriter {
  void write(String message);  // ❌ Received formatted string
}

// After
abstract class ChirpMessageWriter {
  void write(LogEntry entry);  // ✅ Receives structured data
}
```

### ConsoleChirpMessageWriter
```dart
// Before
class ConsoleChirpMessageWriter implements ChirpMessageWriter {
  void write(String message) {
    print(message);  // ❌ Just printed pre-formatted string
  }
}

// After
class ConsoleChirpMessageWriter implements ChirpMessageWriter {
  final ChirpMessageFormatter formatter;  // ✅ Owns formatter
  final void Function(String) output;

  ConsoleChirpMessageWriter({
    ChirpMessageFormatter? formatter,
    void Function(String)? output,
  })  : formatter = formatter ?? DefaultChirpMessageFormatter(),
        output = output ?? print;

  void write(LogEntry entry) {
    final formatted = formatter.format(entry);  // ✅ Formats here
    output(formatted);
  }
}
```

### BufferedChirpMessageWriter
```dart
// Before
class BufferedChirpMessageWriter {
  final List<String> buffer = [];  // ❌ Stored formatted strings

  void write(String message) => buffer.add(message);
}

// After
class BufferedChirpMessageWriter {
  final List<LogEntry> buffer = [];  // ✅ Stores structured data

  void write(LogEntry entry) => buffer.add(entry);

  void flush(ChirpMessageWriter target) {
    for (final entry in buffer) {
      target.write(entry);  // ✅ Target formats on its own
    }
  }
}
```

### Chirp Class
```dart
// Before
class Chirp {
  ChirpMessageFormatter formatter;  // ❌ Owned formatter
  ChirpMessageWriter writer;

  void log(...) {
    final entry = LogEntry(...);
    final formatted = formatter.format(entry);  // ❌ Formatted here
    writer.write(formatted);
  }
}

// After
class Chirp {
  ChirpMessageWriter writer;  // ✅ Writer owns formatter

  void log(...) {
    final entry = LogEntry(...);
    writer.write(entry);  // ✅ Writer handles formatting
  }
}
```

## Migration Guide

### Simple Logger (No Changes Needed)
```dart
// This still works with defaults
Chirp.root = Chirp();
```

### Custom Formatter
```dart
// Before
Chirp.root = Chirp(
  formatter: JsonChirpMessageFormatter(),
);

// After - wrap formatter in writer
Chirp.root = Chirp(
  writer: ConsoleChirpMessageWriter(
    formatter: JsonChirpMessageFormatter(),
  ),
);
```

### Multiple Writers
```dart
// Before - all writers got same format
Chirp.root = Chirp(
  formatter: DefaultChirpMessageFormatter(),
  writer: MultiChirpMessageWriter([...]),
);

// After - each writer has its own format
Chirp.root = Chirp(
  writer: MultiChirpMessageWriter([
    ConsoleChirpMessageWriter(formatter: DefaultChirpMessageFormatter()),
    ConsoleChirpMessageWriter(formatter: JsonChirpMessageFormatter()),
  ]),
);
```

## Real-World Use Cases

### Development: Colorful Console
```dart
Chirp.root = Chirp(
  writer: ConsoleChirpMessageWriter(
    formatter: DefaultChirpMessageFormatter(), // Colors!
  ),
);
```

### Production: JSON to File + Console
```dart
Chirp.root = Chirp(
  writer: MultiChirpMessageWriter([
    // Human-readable for dev team watching logs
    ConsoleChirpMessageWriter(
      formatter: CompactChirpMessageFormatter(),
    ),
    // JSON for log aggregation (Datadog, Splunk, ELK)
    ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),
      output: (msg) {
        File('logs/app.json').writeAsStringSync(
          '$msg\n',
          mode: FileMode.append,
        );
      },
    ),
  ]),
);
```

### Testing: Buffered Logs
```dart
final buffer = BufferedChirpMessageWriter();

setUp(() {
  Chirp.root = Chirp(writer: buffer);
});

test('logs user action', () {
  service.doAction();

  expect(buffer.buffer, hasLength(1));
  expect(buffer.buffer[0].message, contains('action performed'));
  expect(buffer.buffer[0].className, equals('UserService'));
});
```

## Data Flow Comparison

### Before
```
Extension.chirp()
  → Chirp.log()
    → Creates LogEntry
      → Formatter.format(entry) → String
        → Writer.write(string)
```

### After
```
Extension.chirp()
  → Chirp.log()
    → Creates LogEntry
      → Writer.write(entry)
        → Formatter.format(entry) → String
          → Output destination
```

## Backward Compatibility

**Breaking Changes:**
- ❌ `Chirp(formatter: ...)` constructor parameter removed
- ❌ `ChirpMessageWriter.write(String)` → `write(LogEntry)`
- ❌ `BufferedChirpMessageWriter.buffer` type changed from `List<String>` to `List<LogEntry>`

**What Still Works:**
- ✅ Extension methods: `chirp()`, `chirpError()`
- ✅ Default construction: `Chirp()`
- ✅ Named loggers: `Chirp(name: 'HTTP')`
- ✅ All formatters: `DefaultChirpMessageFormatter`, `JsonChirpMessageFormatter`, `CompactChirpMessageFormatter`

## Next Steps

With the architecture fixed, Chirp is now ready for:
1. ✅ **Structured logging** - LogEntry can gain `data` field
2. ✅ **Log levels** - Writers can filter by level
3. ✅ **Child loggers** - Context binding with persistent data
4. ✅ **Production use** - Console + File + Remote simultaneously

This architecture change was **essential** to unlock these features following industry best practices.

---

**See Also:**
- `logging_architecture_research.md` - Research of 21 logging libraries
- `API_GAP_ANALYSIS.md` - Missing features analysis
- `ARCHITECTURE.md` - Updated architecture documentation
