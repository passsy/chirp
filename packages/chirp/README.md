# Chirp

[![Pub](https://img.shields.io/pub/v/chirp)](https://pub.dev/packages/chirp)
[![Pub Likes](https://img.shields.io/pub/likes/chirp)](https://pub.dev/packages/chirp/score)
![License](https://img.shields.io/github/license/passsy/chirp)
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)

A lightweight, flexible logging library for Dart with instance tracking, child loggers, and multiple output formats.

## Features

- **Zero Configuration**: Works out of the box - just call `Chirp.info('hello')`
- **Multiple APIs**: Static methods, named loggers, or `.chirp` extension on any object
- **Child Loggers**: Hierarchical loggers with inherited writers and merged context
- **Instance Tracking**: Differentiates logs from multiple instances of the same class
- **Structured Logging**: Attach key-value data for machine-readable logs
- **Custom Log Levels**: 9 built-in levels plus support for your own
- **Interceptors**: Transform or filter logs before output (redaction, sampling, enrichment)
- **Multiple Writers**: Send logs to console, files, or custom destinations with different formats
- **Designed for Packages**: Ship loggers with your libraries that apps can adopt

## Installation

Add `chirp` to your `pubspec.yaml`:

```yaml
dependencies:
  chirp: ^0.5.0
```

Then run:
```bash
dart pub get
```

## Quick Start

**Flutter app:**
```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
    .addConsoleWriter(formatter: RainbowMessageFormatter());

  try {
    login();
    Chirp.success('User logged in', data: {'userId': 'abc123'});
  } catch (e, stack) {
    Chirp.error('Error occurred', error: e, stackTrace: stack);
  }

  runApp(MyApp());
}

// Output:
// 14:32:05.123 [success] User logged in (userId: "abc123")
// 14:32:05.456 [error] Error occurred
// Exception: Connection timeout
// #0 login (auth.dart:42)
```

**Backend (Shelf, etc.):**
```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
    .addConsoleWriter(formatter: JsonMessageFormatter());

  final handler = (Request request) {
    final logger = Chirp.root.child(context: {'requestId': request.headers['x-request-id']});
    logger.info('Request received');
    // ...
  };
}

// Output:
// {"timestamp":"2025-01-15T14:32:05.123","level":"info","message":"Request received","requestId":"req-abc"}
```

> **Zero-config:** Skip the setup - `Chirp.info()` works out of the box with sensible defaults.

## Why "Chirp"?

Birds chirp to express everything from danger to delight, your app chirps through its logs.
The name celebrates Dart and Flutter's feathered identity.

## Usage

### Named Loggers

Create named loggers for different parts of your application:

```dart
final logger = ChirpLogger(name: 'MyApp');
logger.info('Application started');
logger.error('Error occurred', error: Exception('Something went wrong'));
```

### Extension-Based Logging

Every object has a `chirp` logger that tracks which instance logged:

```dart
class UserService {
  void fetchUser(String userId) {
    chirp.info('Fetching user: $userId');
  }
}

final service1 = UserService();
final service2 = UserService();
service1.chirp.info('From service 1');
service2.chirp.info('From service 2');

// Output - different instances have different hashes:
// 14:32:05.123 UserService@a1b2 [info] From service 1
// 14:32:05.124 UserService@c3d4 [info] From service 2
```

### When to Use `Chirp` vs `chirp`

| Use Case | Method | Why |
|----------|--------|-----|
| Instance methods | `chirp.info()` | Tracks which instance logged (shows `@a1b2` hash) |
| Static methods | `Chirp.info()` | No instance to track |
| Top-level functions | `Chirp.info()` | No instance to track |

```dart
class PaymentProcessor {
  static void validateConfig() {
    Chirp.info('Validating config');  // Static method → Chirp
  }

  void processPayment(double amount) {
    chirp.info('Processing payment');  // Instance method → chirp (shows @hash)
  }
}
```

### Child Loggers

Create child loggers that inherit their parent's writers configuration but add their own context. Perfect for per-request or per-transaction logging:

```dart
// Configure root logger once
Chirp.root = ChirpLogger()
  .addConsoleWriter(formatter: RainbowMessageFormatter());

// Create child logger with context
final requestLogger = Chirp.root.child(context: {
  'requestId': 'REQ-123',
  'userId': 'user_456',
});

// All logs automatically include requestId and userId
requestLogger.info('Request received');
requestLogger.info('Processing payment');
requestLogger.info('Request completed');

// Nest children for deeper context
final transactionLogger = requestLogger.child(context: {
  'transactionId': 'TXN-789',
});

// Includes requestId, userId, AND transactionId
transactionLogger.info('Transaction started');
```

**Child Logger Features:**
- **Inherit writers**: Child loggers use their parent's (eventually root's) writers
- **Merge context**: Parent context + child context + log call data
- **Set name**: `logger.child(name: 'PaymentService')`
- **Set instance**: `logger.child(instance: this)`
- **Combine all**: `logger.child(name: 'API', instance: this, context: {...})`

### Structured Logging

Attach key-value data to your logs for better searchability and analysis. Data can be deeply nested - maps, lists, and complex objects are fully supported:

```dart
Chirp.info(
  'User logged in',
  data: {
    'userId': 'user_123',
    'email': 'user@example.com',
    'loginMethod': 'oauth',
  },
);

// Deeply nested data is supported
Chirp.info('Order placed', data: {
  'order': {
    'id': 'ORD-123',
    'items': [
      {'sku': 'WIDGET-1', 'qty': 2},
      {'sku': 'GADGET-5', 'qty': 1},
    ],
    'shipping': {'method': 'express', 'address': {'city': 'Berlin'}},
  },
});

// Data is merged with context
final logger = Chirp.root.child(context: {'app': 'myapp'});
logger.info('Event', data: {'event': 'click'});
// Output includes: app=myapp, event=click
```

### Mutable Context Pattern

Add context to a logger as information becomes available:

```dart
// Start with minimal context
final logger = Chirp.root.child(
  name: 'API',
  context: {'requestId': 'REQ-123'},
);

logger.info('Request received');

// Add userId when user authenticates
logger.context['userId'] = 'user_456';
logger.info('User authenticated');

// Add more context as needed
logger.context.addAll({
  'endpoint': '/api/orders',
  'method': 'POST',
});
logger.info('Processing request');
```

### Log Levels

Chirp provides 9 semantic log levels with comprehensive documentation:

| Level | Severity | Use For | Example |
|-------|----------|---------|---------|
| **trace** | 0 | Most detailed execution flow | Loop iterations, variable values |
| **debug** | 100 | Diagnostic information | Function parameters, state changes |
| **info** | 200 | Routine operational messages (DEFAULT) | App started, request completed |
| **notice** | 300 | Normal but significant events | Security events, configuration changes |
| **success** | 310 | Positive outcome confirmation | Deployment succeeded, tests passed |
| **warning** | 400 | Potentially problematic situations | Deprecated usage, resource limits |
| **error** | 500 | Errors that prevent specific operations | API failures, validation errors |
| **critical** | 600 | Severe errors affecting core functionality | Database connection lost |
| **wtf** | 1000 | Impossible situations that should never happen | Invariant violations |

```dart
Chirp.trace('Entering loop iteration', data: {'i': 42});
Chirp.debug('Cache miss for key: $key');
Chirp.info('User logged in', data: {'userId': 'user_123'});
Chirp.notice('User role changed', data: {'userId': 'user_123', 'oldRole': 'user', 'newRole': 'admin'});
Chirp.success('Deployment completed', data: {'version': '1.2.0'});
Chirp.warning('API rate limit approaching', data: {'used': 950, 'limit': 1000});
Chirp.error('Payment failed', error: e, stackTrace: st);
Chirp.critical('Database connection lost', data: {'attempt': 3});
Chirp.wtf('User has negative age', data: {'age': -5}); // Should be impossible!
```

**Note:** Every log method accepts optional `error` and `stackTrace` parameters - not just `error()`. This is useful for logging exceptions at any severity level:

```dart
Chirp.warning('Retrying operation', error: e, stackTrace: st);
Chirp.info('Recovered from error', error: previousError);
```

**Custom Log Levels:**
```dart
// Create your own levels
const verbose = ChirpLogLevel('verbose', 50);
const fatal = ChirpLogLevel('fatal', 700);

Chirp.log('Custom message', level: verbose);
```

### Multiple Writers with Different Formats

Each writer can have its own formatter, perfect for multi-environment setups:

```dart
Chirp.root = ChirpLogger()
  // Colorful console logs for development
  .addConsoleWriter(formatter: CompactChirpMessageFormatter())
  // JSON logs to file for production
  .addConsoleWriter(
    formatter: JsonMessageFormatter(),
    output: (msg) => writeToFile('app.log', msg),
  );
```

### Console Writers

| Writer | Output | Best For |
|--------|--------|----------|
| `PrintConsoleWriter` | `print()` → logcat/os_log | Production, CI/CD, release builds |
| `DeveloperLogConsoleWriter` | `developer.log()` | Development (unlimited length, requires debugger) |

`PrintConsoleWriter` is the default (used by `addConsoleWriter()`). It auto-chunks long messages to handle Android's 1024-char limit.

```dart
// Use both for maximum flexibility
Chirp.root = ChirpLogger()
  .addConsoleWriter()  // PrintConsoleWriter - always works
  .addWriter(DeveloperLogConsoleWriter(name: 'myapp'));  // Unlimited when debugging
```

### Available Formatters

**CompactChirpMessageFormatter** - Colorful, human-readable format for development
```
08:30:45.123 UserService@a1b2 User logged in
```

**JsonMessageFormatter** - Machine-readable JSON format
```json
{"timestamp":"2025-11-11T08:30:45.123","level":"info","class":"UserService","hash":"a1b2","message":"User logged in"}
```

**RainbowMessageFormatter** - Colorful, categorized format with class name colors
```
08:30:45.123 UserService@a1b2 [info] User logged in (userId: "user_123", email: "user@example.com")
```

## Span-Based Formatting (Advanced)

For custom console formatters, Chirp uses a **span-based system** similar to Flutter widgets. Spans are composable, nestable, and support ANSI colors.

```dart
// Add emoji prefix using span transformers
final formatter = RainbowMessageFormatter(
  spanTransformers: [
    (tree, record) {
      final emoji = record.level.severity >= 500 ? '🔴 ' : '🟢 ';
      tree.findFirst<LogMessage>()?.wrap(
        (child) => SpanSequence(children: [PlainText(emoji), child]),
      );
    },
  ],
);
```

See [docs/SPANS.md](docs/SPANS.md) for the full span API documentation.

## Configuration

### Color Support

Chirp auto-detects terminal color support. Override via environment or code:

```bash
NO_COLOR=1 dart run           # Disable colors (https://no-color.org/)
FORCE_COLOR=3 dart run        # Force truecolor (0=off, 1=16, 2=256, 3=truecolor)
```

```dart
// Programmatic override
Chirp.root = ChirpLogger()
  .addConsoleWriter(colorSupport: TerminalColorSupport.none);  // or .truecolor
```

### Root Logger

#### Default Behavior (Zero Configuration)

Chirp works immediately without any setup. When you call `Chirp.info()` or use the `.chirp` extension, logs are automatically printed to the console with colorful formatting:

```dart
// No setup needed - this just works!
Chirp.info('Hello, Chirp!');
```

The default logger uses `PrintConsoleWriter` with `RainbowMessageFormatter`, which outputs colorful logs to the console via `print()`.

#### Custom Configuration

Configure the global root logger that all child loggers and extensions inherit from:

```dart
void main() {
  // Configure once at app startup
  Chirp.root = ChirpLogger()
    .addConsoleWriter(formatter: RainbowMessageFormatter());

  // All loggers now use the configured formatter
  runApp();
}
```

**Important:** Always **replace** `Chirp.root` entirely rather than modifying it:

```dart
// ✅ Correct - replaces the logger
Chirp.root = ChirpLogger().addConsoleWriter();

// ❌ Wrong - throws StateError (by design, to prevent test pollution)
Chirp.root.addWriter(myWriter);
```

### Filtering

Chirp provides two ways to filter logs:

1. **Log Level Filtering** - Drop logs below a severity threshold (fast, simple)
2. **Interceptors** - Programmatic filtering with custom logic (see [Interceptors](#interceptors))

#### Logger-Level Filtering

Set a minimum log level for an entire logger hierarchy:

```dart
final logger = ChirpLogger(name: 'verbose-lib')
  .setMinLogLevel(ChirpLogLevel.warning)  // Only warning and above
  .addConsoleWriter();

logger.debug('Ignored');  // Below threshold
logger.warning('Logged'); // At threshold
```

#### Writer-Level Filtering

Different writers can have different minimum levels:

```dart
Chirp.root = ChirpLogger()
  // Console shows everything
  .addConsoleWriter()
  // File only gets errors
  .addConsoleWriter(
    minLogLevel: ChirpLogLevel.error,
    output: (msg) => errorLog.writeAsStringSync('$msg\n', mode: FileMode.append),
  );
```

### Interceptors

Interceptors transform or filter log records before they reach writers. Use them for:

- **Filtering**: Drop logs based on custom criteria (return `null`)
- **Redaction**: Remove sensitive data from logs
- **Enrichment**: Add fields like request IDs or user context
- **Sampling**: Only log a percentage of high-volume events

```dart
class RedactSecretsInterceptor implements ChirpInterceptor {
  @override
  bool get requiresCallerInfo => false;

  @override
  LogRecord? intercept(LogRecord record) {
    // Transform: modify and return record
    // Reject: return null to drop the record (filtering based on all metadata)
    // Pass through: return record unchanged
    return record;
  }
}

final logger = ChirpLogger(name: 'api')
  .addInterceptor(RedactSecretsInterceptor())
  .addConsoleWriter();
```

See [`examples/simple/bin/main.dart`](examples/simple/bin/main.dart) for interceptor examples.

### Library Logger Adoption

Libraries can expose loggers that app developers can optionally adopt to see internal logs:

```dart
// library.dart - Library exposes a silent logger
final httpLogger = ChirpLogger(name: 'http_client');

void get(String url) {
  httpLogger.debug('GET $url');
}
```

```dart
// app.dart - App adopts the library logger
void main() {
  Chirp.root = ChirpLogger().addConsoleWriter();
  Chirp.root.adopt(httpLogger);  // Library logs now visible!

  get('https://api.example.com');
}

// Output:
// 14:32:05.123 http_client [debug] GET https://api.example.com
```

See [`examples/simple/bin/library.dart`](examples/simple/bin/library.dart) and [`examples/simple/bin/app.dart`](examples/simple/bin/app.dart) for a complete example.

### Custom Formatters

Create your own formatter by extending `ConsoleMessageFormatter`:

```dart
class MyCustomFormatter extends ConsoleMessageFormatter {
  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) {
    buffer.write('[${record.level.name.toUpperCase()}] ${record.message}');
  }
}
```

### Custom Writers

Writers control where logs are sent. Extend `ChirpWriter` to send logs to any destination.

#### Simple Writer (Plain Text)

For basic use cases, format the `LogRecord` directly:

```dart
class FileWriter extends ChirpWriter {
  final File file;

  FileWriter(this.file);

  @override
  void write(LogRecord record) {
    final line = '${record.timestamp} [${record.level.name}] ${record.message}';
    file.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}

// Usage
Chirp.root = ChirpLogger()
  ..addWriter(FileWriter(File('app.log')));
```

#### Writer with Formatter (Span-Based)

For rich formatting with colors and structure, use a `ConsoleMessageFormatter`:

```dart
class NetworkWriter extends ChirpWriter {
  final ConsoleMessageFormatter formatter;
  final HttpClient client;

  NetworkWriter({
    required this.client,
    this.formatter = const JsonMessageFormatter(),
  });

  @override
  bool get requiresCallerInfo => formatter.requiresCallerInfo;

  @override
  void write(LogRecord record) {
    final buffer = ConsoleMessageBuffer(
      capabilities: const TerminalCapabilities(
        colorSupport: TerminalColorSupport.none,
      ),
    );
    formatter.format(record, buffer);

    // Send to logging service
    client.post(Uri.parse('https://logs.example.com'), body: buffer.toString());
  }
}

// Usage
Chirp.root = ChirpLogger()
  ..addWriter(NetworkWriter(client: HttpClient()));
```

#### Writer Options

| Property | Description |
|----------|-------------|
| `requiresCallerInfo` | Return `true` if your writer needs file/line/class info (expensive) |
| `minLogLevel` | Filter logs below this level via `setMinLogLevel()` |
| `interceptors` | Add transforms/filters via `addInterceptor()` |

## Real-World Example

```dart
// Setup (once at app startup)
void main() {
  Chirp.root = ChirpLogger()
    .addConsoleWriter(formatter: RainbowMessageFormatter());

  runApp();
}

// Per-request handler
Future<void> handleRequest(Request req) async {
  // Create request-scoped logger with context
  final logger = Chirp.root.child(context: {
    'requestId': req.id,
    'method': req.method,
    'path': req.path,
  });

  logger.info('Request received');

  try {
    // Add user context when available
    final user = await authenticate(req);
    logger.context['userId'] = user.id;
    logger.info('User authenticated');

    // Process with full context
    final result = await processRequest(req, user);

    logger.info('Request completed', data: {'statusCode': 200});
    return result;
  } catch (e, stackTrace) {
    logger.error('Request failed', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
```

All logs from this request will include `requestId`, `method`, `path`, and (after auth) `userId` automatically.

## Testing

Capture logs in tests by providing a custom output function:

```dart
import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  late List<String> capturedLogs;

  setUp(() {
    capturedLogs = [];
    // Replace root logger for each test
    Chirp.root = ChirpLogger().addConsoleWriter(output: capturedLogs.add);
  });

  tearDown(() {
    // Reset to default behavior
    Chirp.root = null;
  });

  test('logs user login', () {
    myLoginFunction();

    expect(capturedLogs, hasLength(1));
    expect(capturedLogs.first, contains('User logged in'));
  });
}
```

For testing with specific formatters or to verify structured data:

```dart
test('logs structured data correctly', () {
  final records = <LogRecord>[];

  // Use a custom writer that captures LogRecords directly
  Chirp.root = ChirpLogger()
    ..addWriter(_CapturingWriter(records));

  Chirp.info('Payment processed', data: {'amount': 99.99});

  expect(records.single.data, {'amount': 99.99});
});

class _CapturingWriter implements ChirpWriter {
  final List<LogRecord> records;
  _CapturingWriter(this.records);

  @override
  void write(LogRecord record) => records.add(record);

  @override
  bool get requiresCallerInfo => false;

  // ... other required overrides
}
```

## Examples

See [`examples/simple/bin/`](examples/simple/bin/) for runnable examples:

| File | Description |
|------|-------------|
| [`basic.dart`](examples/simple/bin/basic.dart) | Zero-config logging |
| [`log_levels.dart`](examples/simple/bin/log_levels.dart) | All 9 log levels + custom levels |
| [`child_loggers.dart`](examples/simple/bin/child_loggers.dart) | Context inheritance |
| [`instance_tracking.dart`](examples/simple/bin/instance_tracking.dart) | The `.chirp` extension |
| [`multiple_writers.dart`](examples/simple/bin/multiple_writers.dart) | Console + JSON output |
| [`interceptors.dart`](examples/simple/bin/interceptors.dart) | Filtering and transforming logs |
| [`library.dart`](examples/simple/bin/library.dart) / [`app.dart`](examples/simple/bin/app.dart) | Library logger adoption |
| [`main.dart`](examples/simple/bin/main.dart) | Span transformers (advanced) |

## License

```
MIT License

Copyright (c) 2025 Pascal Welsch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
