# Chirp Architecture

## Overview

Chirp is a logging package for Dart and Flutter that provides colorful, context-aware logging with instance tracking. It extends any object with logging capabilities while maintaining readability through intelligent formatting and color-coding.

## Core Concepts

### 1. Instance-Based Logging

Every object can log messages with automatic context about:
- **Class name** (with intelligent transformations for Flutter widgets)
- **Instance identity** (via hash code, shown as 4-digit hex)
- **Timestamp** (HH:MM:SS.mmm format)
- **Color coding** (unique per class, red for errors)

### 2. Hybrid Logger Architecture

- **Convenient extension API**: `this.chirp('message')` uses the global `Chirp.root`
- **Explicit instances**: Create custom `Chirp` instances with specific formatters/writers
- **Global default**: `Chirp.root` can be replaced to customize all implicit logging

### 3. Class Name Transformers

A pluggable system to prettify class names for better readability:
- `State<Widget>` → Shows the widget name instead of `_WidgetState`
- `StatelessElement` → Shows `Widget$Element` format
- Custom transformers can be registered by users

### 4. Writers Own Formatters

Single-stage output pipeline following industry best practices:
- **ChirpMessageWriter**: Receives `LogEntry`, formats it via owned formatter, and writes to output
- **ChirpMessageFormatter**: Owned by writers, transforms `LogEntry` → formatted string
- **Benefit**: Each destination can have its own format (console with colors, file with JSON)

## Public API

### Core Logging Extension

```dart
// Extension on all objects
extension ChirpObjectExt<T extends Object> on T {
  /// Log a message with optional error and stack trace
  void chirp(Object? message, [Object? error, StackTrace? stackTrace]);

  /// Log an error message (same as chirp, semantic alias)
  void chirpError(Object? message, [Object? error, StackTrace? stackTrace]);
}
```

**Usage:**
```dart
class MyService {
  void doWork() {
    chirp('Starting work');
    try {
      // ...
      chirp('Work completed');
    } catch (e, stackTrace) {
      chirpError('Work failed', e, stackTrace);
    }
  }
}
```

### Logger Class

```dart
class Chirp {
  /// Create a custom logger instance
  Chirp({
    this.name,
    List<ClassNameTransformer>? classNameTransformers,
    ChirpMessageWriter? writer,
  });

  /// Optional name for this logger (required for explicit instances)
  final String? name;

  /// Class name transformers for this logger
  final List<ClassNameTransformer> classNameTransformers;

  /// The writer used by this logger (owns its formatter)
  ChirpMessageWriter writer;

  /// Log a message
  ///
  /// When called from the extension, instance is provided automatically.
  /// When called directly on a named logger, uses the logger's name.
  void log(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Object? instance,
  });

  /// Register a custom class name transformer for this logger
  void registerClassNameTransformer(ClassNameTransformer transformer);

  /// Global root logger used by the extension
  static Chirp root = Chirp();
}
```

**Usage:**
```dart
// Replace global logger - writer owns formatter
void main() {
  Chirp.root = Chirp(
    writer: ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),
    ),
  );

  runApp(MyApp());
}

// Create custom logger instance
final httpLogger = Chirp(
  name: 'HTTP',
  writer: ConsoleChirpMessageWriter(
    formatter: JsonChirpMessageFormatter(),
  ),
);

httpLogger.log('Request sent');

// Custom transformers for specific logger
final apiLogger = Chirp(name: 'API');
apiLogger.registerClassNameTransformer((instance) {
  if (instance is MyWrapper) return 'Wrapped';
  return null;
});
```

### Message Formatters

```dart
/// Transforms LogEntry into formatted string
abstract class ChirpMessageFormatter {
  String format(LogEntry entry);
}

/// Default colored formatter (from experiment code)
class DefaultChirpMessageFormatter implements ChirpMessageFormatter {
  @override
  String format(LogEntry entry) {
    // Implements:
    // - Colored output with HSL color generation
    // - Timestamp and class:hash header
    // - Multi-line message support
    // - Error highlighting (red)
  }
}

/// Single-line compact format
class CompactChirpMessageFormatter implements ChirpMessageFormatter {
  @override
  String format(LogEntry entry) {
    // "HH:MM:SS ClassName:hash message"
  }
}

/// JSON format for structured logging
class JsonChirpMessageFormatter implements ChirpMessageFormatter {
  @override
  String format(LogEntry entry) {
    // {"timestamp": "...", "class": "...", "message": "..."}
  }
}
```

### Message Writers

```dart
/// Writes log entries to output (owns formatter)
abstract class ChirpMessageWriter {
  void write(LogEntry entry);
}

/// Writes to console using print()
class ConsoleChirpMessageWriter implements ChirpMessageWriter {
  final ChirpMessageFormatter formatter;
  final void Function(String) output;

  ConsoleChirpMessageWriter({
    ChirpMessageFormatter? formatter,
    void Function(String)? output,
  })  : formatter = formatter ?? DefaultChirpMessageFormatter(),
        output = output ?? print;

  @override
  void write(LogEntry entry) {
    final formatted = formatter.format(entry);
    output(formatted);
  }
}

/// Buffers log entries in memory
class BufferedChirpMessageWriter implements ChirpMessageWriter {
  final List<LogEntry> buffer = [];

  @override
  void write(LogEntry entry) => buffer.add(entry);

  void flush(ChirpMessageWriter target) {
    for (final entry in buffer) {
      target.write(entry);
    }
    buffer.clear();
  }
}

/// Forwards to multiple writers (each with own formatter)
class MultiChirpMessageWriter implements ChirpMessageWriter {
  final List<ChirpMessageWriter> writers;

  MultiChirpMessageWriter(this.writers);

  @override
  void write(LogEntry entry) {
    for (final writer in writers) {
      writer.write(entry);
    }
  }
}
```

### Class Name Transformers

```dart
/// Function type for transforming an instance into a display name.
///
/// Return a non-null string to use that as the class name,
/// or null to try the next transformer.
typedef ClassNameTransformer = String? Function(Object instance);

// Built-in transformers (included by default in Chirp instances):
// - StateTransformer: State → Widget name
// - StatelessElementTransformer: StatelessElement → Widget$Element
```

**Usage:**
```dart
// Register custom transformer on root logger
Chirp.root.registerClassNameTransformer((instance) {
  if (instance is MyCustomWrapper) {
    return instance.wrappedObject.runtimeType.toString();
  }
  return null;
});

// Or create logger with custom transformers
final customLogger = Chirp(
  name: 'Custom',
  classNameTransformers: [
    (instance) {
      if (instance is MyType) return 'MyType';
      return null;
    },
  ],
);
```

### Data Models

```dart
class LogEntry {
  /// The log message
  final Object? message;

  /// When this log was created
  final DateTime date;

  /// Optional error/exception
  final Object? error;

  /// Optional stack trace
  final StackTrace? stackTrace;

  /// Resolved class name (after transformers)
  final String className;

  /// Instance identity hash code
  final int instanceHash;

  /// Original instance that logged this
  final Object instance;

  const LogEntry({
    required this.message,
    required this.date,
    this.error,
    this.stackTrace,
    required this.className,
    required this.instanceHash,
    required this.instance,
  });
}
```

## Architecture Layers

```
┌─────────────────────────────────────────┐
│  Extension (ChirpObjectExt)             │
│  - chirp(), chirpError()                │
│  - Delegates to Chirp.root              │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Chirp (Logger Instance)                │
│  - log()                                │
│  - Class name resolution                │
│  - Transformer registry                 │
│  - LogEntry creation                    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  LogEntry (Data Model)                  │
│  - message, date, error, stackTrace     │
│  - className, instanceHash, instance    │
│  - loggerName                           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  ChirpMessageWriter (owns Formatter)    │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ ConsoleWriter                     │ │
│  │ ├─ Formatter (Default/JSON/etc)   │ │
│  │ └─ Output (print/custom)          │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ MultiWriter                       │ │
│  │ ├─ Writer 1 (with Formatter 1)    │ │
│  │ ├─ Writer 2 (with Formatter 2)    │ │
│  │ └─ Writer N (with Formatter N)    │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ BufferedWriter                    │ │
│  │ └─ Buffer of LogEntry objects     │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Extension + Global Logger Pattern
- **Rationale:** Best of both worlds - convenient API with flexible configuration
- **Benefit:** `this.chirp('...')` reads naturally, but users can create custom logger instances
- **Trade-off:** Extension always uses `Chirp.root`, but this is the expected behavior for 99% of use cases

### 2. Writers Own Formatters (Handler-owns-Formatter Pattern)
- **Rationale:** Industry best practice (Python logging, Log4j, Serilog, winston) - each destination owns its formatter
- **Benefit:** Different formats per destination (colored console, JSON file, compact remote)
- **Example:** Console writer with colored formatter + File writer with JSON formatter simultaneously
- **Precedent:** Matches architecture of 18 out of 21 researched logging libraries

### 3. Instance Hash in Output
- **Rationale:** Helps track individual instances in async/concurrent scenarios
- **Benefit:** Easy to follow the lifecycle of specific objects
- **Example:** "UserService:a4f2 fetching data" → "UserService:a4f2 data received"

### 4. Named Loggers vs Instance-Based Logging
- **Rationale:** Support both use cases - extension convenience and explicit logger instances
- **Benefit:** Extension uses instance for class name, explicit loggers use their name
- **Example:**
  - Extension: `this.chirp('msg')` → `"MyClass:a4f2 msg"`
  - Named logger: `httpLogger.log('msg')` → `"HTTP:xxxx msg"`
- **Trade-off:** Named loggers don't track individual instances but provide clearer semantic grouping

### 5. Transformer Pattern for Class Names
- **Rationale:** Flutter widget names are often obfuscated (`_MyWidgetState`)
- **Benefit:** Extensible system per logger instance, no global state
- **Example:** `_HomePageState` displays as `HomePage` automatically

### 6. HSL Color Generation
- **Rationale:** Deterministic, readable colors that avoid red (reserved for errors)
- **Benefit:** Consistent colors per class, good visual separation in logs
- **Algorithm:** Hash class name → HSL (60°-300° hue) → RGB for terminal colors

### 7. LogEntry Immutability
- **Rationale:** Log entries are snapshots in time and should not change
- **Benefit:** Safe to pass around, store, or process asynchronously
- **Example:** Buffer logs during startup, flush to file after initialization

## Usage Patterns

### Basic Logging
```dart
class UserService {
  Future<User> fetchUser(String id) async {
    chirp('Fetching user $id');
    final user = await api.getUser(id);
    chirp('User fetched: ${user.name}');
    return user;
  }
}
```

### Error Logging
```dart
class PaymentService {
  Future<void> processPayment(Payment payment) async {
    try {
      await gateway.charge(payment);
      chirp('Payment processed: ${payment.id}');
    } catch (e, stackTrace) {
      chirpError('Payment failed: ${payment.id}', e, stackTrace);
      rethrow;
    }
  }
}
```

### Custom Logger Configuration
```dart
void main() {
  // Production: JSON logs to console
  if (kReleaseMode) {
    Chirp.root = Chirp(
      writer: ConsoleChirpMessageWriter(
        formatter: JsonChirpMessageFormatter(),
      ),
    );
  } else {
    // Development: Colored console logs (default)
    Chirp.root = Chirp();
  }

  runApp(MyApp());
}
```

### Multiple Writers with Different Formats
```dart
// Log to console (colored) AND file (JSON) simultaneously
Chirp.root = Chirp(
  writer: MultiChirpMessageWriter([
    ConsoleChirpMessageWriter(
      formatter: DefaultChirpMessageFormatter(), // Colored
    ),
    ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),    // JSON
      output: (msg) {
        File('app.log').writeAsStringSync('$msg\n', mode: FileMode.append);
      },
    ),
  ]),
);
```

### Custom Formatter
```dart
class TimestampOnlyFormatter implements ChirpMessageFormatter {
  @override
  String format(LogEntry entry) {
    final time = DateFormat.Hms().format(entry.date);
    return '[$time] ${entry.className}: ${entry.message}';
  }
}

Chirp.root = Chirp(
  writer: ConsoleChirpMessageWriter(
    formatter: TimestampOnlyFormatter(),
  ),
);
```

### Named Logger Usage
```dart
// Create loggers for different subsystems
final httpLogger = Chirp(name: 'HTTP');
final dbLogger = Chirp(name: 'Database');
final cacheLogger = Chirp(name: 'Cache');

// Each logger generates its own hash based on the logger instance
httpLogger.log('GET /api/users');    // → "HTTP:b5c3 GET /api/users"
dbLogger.log('Query executed');      // → "Database:7a2f Query executed"
cacheLogger.log('Cache hit');        // → "Cache:e9d1 Cache hit"

// Meanwhile, extension-based logging tracks individual instances
class UserService {
  void fetchUser() {
    chirp('Fetching user');  // → "UserService:a4f2 Fetching user"
  }
}
```

## Example Output

### Default Formatter
```
10:23:45.123 ================ MyService:a4f2 │ Starting work
10:23:45.456 ================ MyService:a4f2 │ Work completed
10:23:46.789 ================ MyButton:3c1d │ Button pressed
10:23:47.012 ================ MyService:a4f2 │ Error occurred
java.lang.Exception: Network timeout
  at MyService.fetchData (my_service.dart:42)
  ...
```

### Compact Formatter
```
10:23:45.123 MyService:a4f2 Starting work
10:23:45.456 MyService:a4f2 Work completed
10:23:46.789 MyButton:3c1d Button pressed
```

### JSON Formatter
```json
{"timestamp":"2024-01-15T10:23:45.123","class":"MyService","hash":"a4f2","message":"Starting work"}
{"timestamp":"2024-01-15T10:23:45.456","class":"MyService","hash":"a4f2","message":"Work completed"}
{"timestamp":"2024-01-15T10:23:46.789","class":"MyButton","hash":"3c1d","message":"Button pressed"}
```

## Migration from Experiment

The experiment code in `lib/src/experiement.dart` demonstrates a working implementation. The migration involves:

1. **Create `Chirp` class:**
   - Constructor accepting `name`, `classNameTransformers`, `formatter`, and `writer`
   - `log()` method accepting optional `instance` parameter
   - Internal class name resolution using transformers
   - `registerClassNameTransformer()` for runtime registration
   - Static `root` property for global logger

2. **Extract formatting to `DefaultChirpMessageFormatter`:**
   - HSL-to-RGB conversion
   - Color pen creation
   - Layout and timestamp formatting
   - Multi-line message handling

3. **Create `ConsoleChirpMessageWriter`:**
   - Simple wrapper around `print()`

4. **Update extension to delegate:**
   - `chirp()` → `Chirp.root.log(message, instance: this, ...)`
   - `chirpError()` → `Chirp.root.log(message, instance: this, ...)`

5. **Enhance `LogEntry`:**
   - Add `className`, `instanceHash`, `instance` fields
   - All data needed for formatting

6. **Default transformers:**
   - Extract transformer logic into separate functions
   - Include by default in `Chirp` constructor
   - Allow custom transformers via constructor or `registerClassNameTransformer()`

## Dependencies

- `package:ansicolor` - Terminal color support (already added)
- `package:flutter/widgets.dart` - Flutter integration (optional, for widget transformers)

## Testing Strategy

1. **Unit tests:**
   - Class name transformers
   - HSL color generation
   - Each formatter output
   - Each writer behavior

2. **Integration tests:**
   - Extension usage from various object types
   - Transformer registration and precedence
   - Error logging with stack traces
   - Custom logger instances

3. **Golden tests:**
   - Formatter output comparison
   - Color consistency across runs

## Future Enhancements

- **Log levels**: debug, info, warn, error with filtering
- **Filtering**: By class name, tag, or custom predicates
- **Performance metrics**: Timing between chirps, method duration
- **Remote logging**: HTTP sink, cloud logging services
- **Scoped contexts**: Add contextual metadata to all logs in a scope
- **Conditional logging**: Debug mode only, rate limiting
- **Log aggregation**: Group related logs, transaction tracing