# Chirp

[![Pub](https://img.shields.io/pub/v/chirp)](https://pub.dev/packages/chirp)
[![Pub Likes](https://img.shields.io/pub/likes/chirp)](https://pub.dev/packages/chirp/score)
[![License](https://img.shields.io/github/license/passsy/chirp)](https://github.com/passsy/chirp/blob/main/LICENSE)
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)

**Logging for Dart and Flutter that feels right from line one.**

Birds chirp to express everything from danger to delight — your app chirps through its logs. Start with a single `Chirp.info('Hello!')` with zero setup, and grow into per-instance `.chirp` loggers, deeply structured data, hierarchical child loggers, rotating files with live tailing, cloud-native JSON for GCP and AWS, and a Flutter-widget-like span system for custom formats.

```dart
import 'package:chirp/chirp.dart';

class OrderService {
  void placeOrder(String orderId) {
    chirp.info('Placing order', data: {'orderId': orderId, 'items': 3});
    chirp.success('Order confirmed');
  }
}

void main() {
  Chirp.info('App started'); // Works immediately, no setup required
  OrderService().placeOrder('ORD-42');
}
```

```text
14:32:05.120 [info] main:11 main App started
14:32:05.123 [info] main:5 OrderService@6de4 placeOrder Placing order (orderId: "ORD-42", items: 3)
14:32:05.124 [success] main:6 OrderService@6de4 placeOrder Order confirmed
```

Colors, timestamps, caller file and line, unique instance hash (`@6de4`), and structured data — all out of the box.

## Features

- **Zero Configuration**: Works out of the box — just call `Chirp.info('hello')`
- **Every Object Gets `.chirp`**: Instance-aware loggers automatically tag messages with `ClassName@hash` so you can tell instances apart
- **9 Built-In Log Levels + Custom Levels**: `trace` through `wtf` (including `notice` and `success`), plus your own `ChirpLogLevel`s
- **Automatic Caller Info**: File, line, class, and method included when needed — skipped automatically when no writer asks for it
- **Structured Data**: Pass flat or deeply nested maps, lists, and objects via `data: {...}` instead of hand-building long log strings
- **Child Loggers**: Hierarchical loggers with inherited writers, merged context, and mutable context as more info arrives
- **Cloud-Ready JSON**: Built-in formatters for Google Cloud Logging (with Error Reporting), AWS CloudWatch, and generic JSON collectors
- **Multiple Writers**: Route logs to console, rotating files, or custom destinations — each with its own formatter, level filter, and interceptors
- **Rotating Files & Live Tailing**: Size- or time-based log rotation with gzip compression (`RotatingFileWriter`) and live streaming across rotations (`RotatingFileReader`)
- **Lazy Logging**: Defer expensive message or `data` construction until a log passes the level filter, while preserving exact caller locations

Chirp is built to be extended:

- **Span-Based Formatting**: Build custom console formats like Flutter widgets, or tweak built-in formatters in place with `spanTransformers`
- **Interceptors**: Filter, redact, sample, or enrich records before output — inline or as reusable classes
- **Custom Writers**: Creating your own writer is as easy as a one-line `DelegatedChirpWriter` or subclassing `ChirpWriter`
- **Designed for Packages**: Ship silent loggers inside your libraries that host apps can adopt into their logging hierarchy with a single line

## Installation

```bash
dart pub add chirp
# or in a Flutter project:
flutter pub add chirp
```

Or add `chirp` to your `pubspec.yaml`:

```yaml
dependencies:
  chirp: ^0.10.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Flutter app

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

  runApp(const MyApp());
}
```

```text
14:32:05.123 [success] main:9 main User logged in (userId: "abc123")
14:32:05.456 [error] main:11 main Error occurred
Exception: Connection timeout
#0      login (auth.dart:42:5)
```

### Backend (Shelf, Dart Frog, etc.)

```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
      .addConsoleWriter(formatter: const JsonLogFormatter());

  final handler = (Request request) {
    final logger = Chirp.root.child(
      context: {'requestId': request.headers['x-request-id']},
    );
    logger.info('Request received');
    // ...
  };
}
```

```json
{"timestamp":"2025-01-15T14:32:05.123Z","level":"info","message":"Request received","requestId":"req-abc"}
```

> **Zero-config:** Skip setup entirely — `Chirp.info()` works immediately with sensible defaults.

## Why "Chirp"

Birds chirp to express everything from danger to delight; your app chirps through its logs. The name celebrates Dart and Flutter's feathered identity.

## Usage

### AI Agent Skill

Chirp ships a `chirp-logging` skill with separate setups for Flutter apps, server-side backends, and reusable packages, plus guidance for structured context, writers, and lazy logging. Install the skill from your project's root:

```bash
dart run skills@ get --package chirp
```

See [package skills](https://dart.dev/ai/package-skills) for CLI setup and supported agents.

### Named Loggers

Create named loggers for different subsystems of your app. Use `Chirp.root.child(name: ...)` to inherit your root logger's writers, or create an independent `ChirpLogger(name: ...)` with its own writers:

```dart
// Inherits writers and formatters from Chirp.root
final authLogger = Chirp.root.child(name: 'Auth');
authLogger.info('Session started');

// Standalone logger (silent until you add a writer or adopt it)
final logger = ChirpLogger(name: 'MyApp').addConsoleWriter();
logger.info('Application started');
logger.error('Error occurred', error: Exception('Something went wrong'));
```

### Extension-Based Logging (`.chirp`)

Every Dart object has a `.chirp` logger that automatically tracks which instance logged:

```dart
class UserService {
  void fetchUser(String userId) {
    chirp.info('Fetching user', data: {'userId': userId});
  }
}

final service1 = UserService();
final service2 = UserService();
service1.chirp.info('From service 1');
service2.chirp.info('From service 2');
```

```text
14:32:05.123 [info] main:9 UserService@a1b2 main From service 1
14:32:05.124 [info] main:10 UserService@c3d4 main From service 2
```

### When to Use `Chirp` vs `chirp`

| Use Case | Method | Why |
| --- | --- | --- |
| Instance methods | `chirp.info()` | Tracks which instance logged (shows `@a1b2` hash) |
| Static methods | `Chirp.info()` | No instance to track |
| Top-level functions | `Chirp.info()` | No instance to track |

```dart
class PaymentProcessor {
  static void validateConfig() {
    Chirp.info('Validating config'); // Static method → Chirp
  }

  void processPayment(double amount) {
    chirp.info('Processing payment'); // Instance method → chirp (shows @hash)
  }
}
```

### Child Loggers

Create child loggers that inherit their parent's writers while attaching their own context — ideal for per-request, per-job, or per-transaction logging:

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

Child logger capabilities:

- **Inherit writers**: Child loggers forward to their parent's (eventually root's) writers
- **Merge context**: Parent context + child context + per-call `data`
- **Set name**: `logger.child(name: 'PaymentService')`
- **Set instance**: `logger.child(instance: this)`
- **Combine all**: `logger.child(name: 'API', instance: this, context: {...})`

### Structured Logging

Attach key-value data to any log call for better searchability and analysis. Data can be flat or **deeply nested** — maps, lists, and complex objects are all supported:

```dart
Chirp.info(
  'User logged in',
  data: {
    'userId': 'user_123',
    'email': 'user@example.com',
    'loginMethod': 'oauth',
  },
);

// Deeply nested data (maps, lists, objects) is supported
Chirp.info('Order placed', data: {
  'order': {
    'id': 'ORD-123',
    'items': [
      {'sku': 'WIDGET-1', 'qty': 2},
      {'sku': 'GADGET-5', 'qty': 1},
    ],
    'shipping': {
      'method': 'express',
      'address': {'city': 'Berlin'},
    },
  },
});

// Per-call data is merged with logger context
final logger = Chirp.root.child(context: {'app': 'myapp'});
logger.info('Event', data: {'event': 'click'});
// Output includes both app: "myapp" and event: "click"
```

With `RainbowMessageFormatter`, you can even switch nested data to YAML-like multiline rendering using `RainbowFormatOptions(data: DataPresentation.multiline)`.

### Mutable Context Pattern

Build up a logger's context step by step as more information becomes available during an operation:

```dart
// Start with minimal context
final logger = Chirp.root.child(
  name: 'API',
  context: {'requestId': 'REQ-123'},
);

logger.info('Request received');

// Add userId once the user authenticates
logger.context['userId'] = 'user_456';
logger.info('User authenticated');

// Add multiple fields at once
logger.context.addAll({
  'endpoint': '/api/orders',
  'method': 'POST',
});
logger.info('Processing request');
```

### Log Levels

Chirp provides 9 semantic log levels ordered by severity:

| Level | Severity | Use For | Example |
| --- | --- | --- | --- |
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
Chirp.debug('Cache miss', data: {'key': key});
Chirp.info('User logged in', data: {'userId': 'user_123'});
Chirp.notice('User role changed', data: {'userId': 'user_123', 'oldRole': 'user', 'newRole': 'admin'});
Chirp.success('Deployment completed', data: {'version': '1.2.0'});
Chirp.warning('API rate limit approaching', data: {'used': 950, 'limit': 1000});
Chirp.error('Payment failed', error: e, stackTrace: st);
Chirp.critical('Database connection lost', data: {'attempt': 3});
Chirp.wtf('User has negative age', data: {'age': -5}); // Should be impossible!
```

Every log method accepts optional `error` and `stackTrace` parameters — not just `error()`. Use them whenever an exception belongs at a different severity:

```dart
Chirp.warning('Retrying operation', error: e, stackTrace: st);
Chirp.info('Recovered from error', error: previousError);
```

Define custom levels with any name and severity:

```dart
const verbose = ChirpLogLevel('verbose', 50);
const fatal = ChirpLogLevel('fatal', 700);

Chirp.log('Custom message', level: verbose);
```

### Library Logger Adoption

One of Chirp's most distinctive features is how cleanly libraries and apps work together. Reusable packages expose a silent `ChirpLogger` — and can create internal child loggers beneath it — without ever touching `Chirp.root` or inventing a custom logging-callback API. Host apps opt in with a single `adopt()` call:

```dart
// library.dart — package exposes a silent root logger (and optional children)
final httpLogger = ChirpLogger(name: 'http_client');
final retryLogger = httpLogger.child(name: 'http_client.retry');

void get(String url) {
  httpLogger.debug('GET $url');
  retryLogger.trace('Attempt 1');
}
```

```dart
// app.dart — host app adopts the package logger into its hierarchy
void main() {
  Chirp.root = ChirpLogger().addConsoleWriter();
  Chirp.root.adopt(httpLogger); // httpLogger + all its children now use Chirp.root's writers!

  // Optionally tune verbosity for just this library
  httpLogger.setMinLogLevel(ChirpLogLevel.debug);

  get('https://api.example.com');
}
```

```text
14:32:05.123 [debug] library:6 http_client get GET https://api.example.com
```

Because `adopt()` attaches the library logger as a child of the adopting logger:

- All logs from the library (and any child loggers it creates) flow through your app's writers and formatters
- Adopted loggers inherit your context while keeping their own logger name and instance info
- Libraries stay completely quiet until an app decides to adopt them (or set a minimum level)

See [`examples/simple/bin/library.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/library.dart) and [`examples/simple/bin/app.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/app.dart) for a complete runnable example.

### Multiple Writers with Different Formats

Each writer can have its own formatter, level filter, and destination — great for sending readable logs to your console and structured JSON to disk at the same time:

```dart
final fileWriter = RotatingFileWriter(
  baseFilePathProvider: () => 'app.jsonl',
  formatter: const JsonLogFormatter(),
  rotationConfig: FileRotationConfig.size(maxSize: 10 * 1024 * 1024, maxFiles: 5),
);

Chirp.root = ChirpLogger()
    // Colorful console logs for development
    .addConsoleWriter(formatter: CompactChirpMessageFormatter())
    // Structured JSON to a rotating file
    .addWriter(fileWriter);
```

### Console Writers

| Writer | Output | Best For |
| --- | --- | --- |
| `PrintConsoleWriter` | `print()` → stdout / logcat / os_log | Production, CI/CD, release builds |
| `DeveloperLogConsoleWriter` | `dart:developer` `log()` | Development & Flutter DevTools (unlimited length, requires debugger) |

`PrintConsoleWriter` is the default (used by `addConsoleWriter()`). It automatically chunks long messages to handle Android's and iOS's ~1024-character limits. Note that `DeveloperLogConsoleWriter` strips ANSI colors and requires an attached debugger.

```dart
// Use both for maximum flexibility
Chirp.root = ChirpLogger()
    .addConsoleWriter() // PrintConsoleWriter — always works
    .addWriter(DeveloperLogConsoleWriter()); // Unlimited length when debugging
```

### File Writers & Live Tailing

`RotatingFileWriter` writes logs to files with automatic rotation, retention cleanup, and optional background gzip compression (in an isolate). Always configure rotation to keep disk usage bounded:

```dart
// Size-based: rotate at 100 MB, keep 10 files, compress old logs
final writer = RotatingFileWriter(
  baseFilePathProvider: () => '/var/log/app.jsonl',
  formatter: const JsonLogFormatter(),
  rotationConfig: FileRotationConfig.size(
    maxSize: 100 * 1024 * 1024,
    maxFiles: 10,
    compress: true,
  ),
);

Chirp.root = ChirpLogger()
    .addConsoleWriter()
    .addWriter(writer);
```

```dart
// Time-based: rotate daily, keep 30 days
final writer = RotatingFileWriter(
  baseFilePathProvider: () => '/var/log/app.jsonl',
  formatter: const JsonLogFormatter(),
  rotationConfig: FileRotationConfig.daily(
    maxAge: const Duration(days: 30),
    compress: true,
  ),
);
```

Call `await writer.close()` on shutdown to flush buffers.

Every `RotatingFileWriter` also exposes a `RotatingFileReader` via `writer.reader` so you can read log history or live-tail records across active, rotated, and compressed files without losing, repeating, or reordering entries:

```dart
// Stream the last 50 records, then keep following new ones across rotations
final subscription = writer.reader.tail(last: 50).listen(stdout.writeln);

// Or read historical entries once
await for (final entry in writer.reader.read(last: 100)) {
  stdout.writeln(entry);
}
```

See [`examples/simple/bin/file_writer.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_writer.dart) and [`examples/simple/bin/file_reader.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_reader.dart) for complete examples.

### Available Formatters

| Formatter | Best For | Highlights |
| --- | --- | --- |
| `RainbowMessageFormatter` | Local development (default) | Color-coded levels, unique color per class, inline or multiline data |
| `CompactChirpMessageFormatter` | Dense single-line logs | Caller location, class, message, and inline data on one line |
| `SimpleConsoleMessageFormatter` | Detailed plain-text debugging | Toggles for caller, method, instance, logger name, and data |
| `JsonLogFormatter` | Generic JSON log collectors | Single-line UTF-8 JSON with UTC timestamps and root-level data |
| `GcpMessageFormatter` | Google Cloud Run / GKE / Functions | GCP `severity`, `sourceLocation`, labels, and Error Reporting |
| `AwsMessageFormatter` | AWS Lambda / ECS / CloudWatch | CloudWatch log levels (`TRACE`..`FATAL`) and structured JSON |

**`RainbowMessageFormatter`** — Colorful, categorized format with a unique color per class:

```text
08:30:45.123 [info] auth:42 UserService@a1b2 login User logged in (userId: "user_123", email: "user@example.com")
```

**`CompactChirpMessageFormatter`** — Concise, single-line format for development:

```text
08:30:45.123 [info] auth:42 UserService@a1b2 User logged in (userId: "user_123")
```

**`SimpleConsoleMessageFormatter`** — Complete text output with configurable fields:

```text
08:30:45.123 [INFO] auth:42 login UserService@a1b2 [auth] - User logged in (userId: "user_123")
```

**`JsonLogFormatter`** — Machine-readable single-line JSON:

```json
{"timestamp":"2025-11-11T08:30:45.123Z","level":"info","class":"UserService","instance":"UserService@a1b2","message":"User logged in"}
```

## Span-Based Formatting (Advanced)

For custom console formatters, Chirp uses a **span-based system** modeled after Flutter widgets. Spans are composable, nestable, and support ANSI colors:

```dart
import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

class MyMessageFormatter extends SpanBasedFormatter {
  MyMessageFormatter({super.spanTransformers});

  @override
  LogSpan buildSpan(LogRecord record) {
    return SpanSequence(children: [
      Timestamp(record.timestamp), // 14:32:05.123
      Whitespace(),
      BracketedLogLevel(record.level), // [INFO]
      Surrounded(prefix: Whitespace(), child: ClassName.fromRecord(record)), // UserService@a1b2
      Whitespace(),
      LogMessage(record.message), // User logged in
    ]);
  }
}
```

Each span knows its parent and can be manipulated in place with a `SpanTransformer` (replaced, removed, or wrapped — much like DOM elements in HTML). That means you can customize existing formatters without writing one from scratch:

```dart
// Add an emoji prefix using span transformers
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

See [docs/SPANS.md](https://github.com/passsy/chirp/blob/main/docs/SPANS.md) for the full span API documentation.

## Configuration

### Color Support

Chirp auto-detects terminal color support. Override it via environment variables or code:

```bash
NO_COLOR=1 dart run      # Disable colors (https://no-color.org/)
FORCE_COLOR=3 dart run   # Force truecolor (0=off, 1=16, 2=256, 3=truecolor)
```

```dart
// Programmatic override
Chirp.root = ChirpLogger().addConsoleWriter(
  capabilities: const TerminalCapabilities(
    colorSupport: TerminalColorSupport.none,
  ),
);
```

### Root Logger

#### Default Behavior (Zero Configuration)

Chirp works immediately without setup. Calling `Chirp.info()` or using `.chirp` automatically prints colorful logs to the console via `PrintConsoleWriter` and `RainbowMessageFormatter`:

```dart
// No setup needed — this just works!
Chirp.info('Hello, Chirp!');
```

#### Custom Configuration

Configure the global root logger once at startup so all child loggers and `.chirp` extensions inherit it:

```dart
void main() {
  Chirp.root = ChirpLogger()
      .addConsoleWriter(formatter: RainbowMessageFormatter());

  runApp(const MyApp());
}
```

**Important:** Always **replace** `Chirp.root` entirely rather than mutating it:

```dart
// ✅ Correct — replaces the logger
Chirp.root = ChirpLogger().addConsoleWriter();

// ❌ Wrong — throws StateError before root is assigned (by design, to prevent test pollution)
Chirp.root.addWriter(myWriter);
```

### Lazy Logging

Defer expensive log construction until the logger has decided to actually emit. Pick the flavor that matches where the expensive work lives.

#### Lazy Messages

Pass a closure instead of a string when only the message is expensive. The closure is only called when the log level passes the logger's filter:

```dart
// Always builds the string, even if trace is filtered out
logger.trace('User data: ${jsonEncode(hugeMap)}');

// Closure only runs when trace level is active
logger.trace(() => 'User data: ${jsonEncode(hugeMap)}');
```

This is especially useful for `trace` and `debug` calls that are typically disabled in production.

#### Lazy Builders

When the expensive work lives in `data`, `error`, `stackTrace`, or any other named argument — not just the message — use the `xxxLazy` variant. The builder runs only when the level passes, so every argument it constructs is skipped when the record is filtered out:

```dart
// Defers EVERY argument (message, data, error, ...) until the logger emits
Chirp.warningLazy(
  (log) => log('snapshot', data: {'state': renderState(), 'metrics': dump()}),
);

// Works for every level
Chirp.errorLazy((log) => log('failed', error: e, stackTrace: st));

// logLazy takes a custom level: argument
Chirp.logLazy(
  (log) => log('msg', data: {'state': render()}),
  level: ChirpLogLevel.debug,
);
```

The inner `log` callback has the same signature as the eager methods (typedef `ChirpLogFn`), so call sites read identically — without wasted work on discarded logs.

Caller resolution is handled automatically: the `xxxLazy(...)` invocation line is reported, not the inner `(log) => ...` body, so source locations look identical whether the call is eager or lazy.

Available variants: `traceLazy`, `debugLazy`, `infoLazy`, `noticeLazy`, `successLazy`, `warningLazy`, `errorLazy`, `criticalLazy`, `wtfLazy`, plus the generic `logLazy` on both `ChirpLogger` instances and the global `Chirp` static API.

Lazy builders cost one closure allocation per call when the level passes; the level-filtered hot path stays as cheap as the eager methods. Reach for `xxxLazy` when constructing `data` (or other arguments) is expensive, and the lazy-message form when only the message is.

### Filtering

Chirp provides two ways to filter logs:

1. **Log Level Filtering** — Drop logs below a severity threshold (fast, simple)
2. **Interceptors** — Programmatic filtering with custom logic (see [Interceptors](#interceptors))

#### Logger-Level Filtering

Set a minimum log level for an entire logger hierarchy (short-circuits before constructing records or running lazy builders):

```dart
final logger = ChirpLogger(name: 'verbose-lib')
    .setMinLogLevel(ChirpLogLevel.warning) // Only warning and above
    .addConsoleWriter();

logger.debug('Ignored'); // Below threshold
logger.warning('Logged'); // At threshold
```

#### Writer-Level Filtering

Give each writer its own minimum level:

```dart
Chirp.root = ChirpLogger()
    // Console shows everything
    .addConsoleWriter()
    // Error file only gets error and above
    .addWriter(
      RotatingFileWriter(
        baseFilePathProvider: () => 'errors.jsonl',
        formatter: const JsonLogFormatter(),
        rotationConfig: FileRotationConfig.daily(maxAge: const Duration(days: 14)),
      )..setMinLogLevel(ChirpLogLevel.error),
    );
```

You can also pass `minLogLevel:` directly to `addConsoleWriter(minLogLevel: ChirpLogLevel.error)`.

### Interceptors

Interceptors transform or filter log records before they reach writers. Return `null` from `intercept()` to drop a log record.

For quick inline filters or transforms, use `DelegatedChirpInterceptor`:

```dart
final logger = ChirpLogger()
    .addInterceptor(
      DelegatedChirpInterceptor((record) {
        if (record.message.toString().contains('/health')) return null;
        return record;
      }),
    )
    .addConsoleWriter();
```

For reusable or stateful interceptors, extend `ChirpInterceptor`:

```dart
/// Filters out high-frequency health check logs.
class HealthCheckFilter extends ChirpInterceptor {
  @override
  LogRecord? intercept(LogRecord record) {
    // Return null to drop the log record
    if (record.message.toString().contains('/health')) return null;
    return record;
  }
}

final logger = ChirpLogger()
    .addInterceptor(HealthCheckFilter())
    .addConsoleWriter();

logger.info('GET /health'); // Dropped
logger.info('GET /api/users'); // Logged
```

Other common interceptor use cases:

- **Redaction**: Strip secrets, tokens, or PII from messages and `data`
- **Enrichment**: Attach ambient fields like trace IDs or user context
- **Sampling**: Forward only a percentage of high-volume events

Interceptors can be attached to either a logger or an individual writer. See [`examples/simple/bin/interceptors.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/interceptors.dart) for more examples.

### Custom Formatters

Create your own formatter by extending `ChirpFormatter`:

```dart
class MyCustomFormatter extends ChirpFormatter {
  @override
  void format(LogRecord record, MessageBuffer buffer) {
    buffer.write('[${record.level.name.toUpperCase()}] ${record.message}');
  }
}
```

### Custom Writers

Writers control where logs are sent. Use `DelegatedChirpWriter` for one-liners, or extend `ChirpWriter` for stateful destinations.

#### Inline Writer (`DelegatedChirpWriter`)

```dart
Chirp.root = ChirpLogger()
    .addConsoleWriter()
    .addWriter(
      DelegatedChirpWriter((record) {
        if (record.level >= ChirpLogLevel.error) {
          crashReporter.recordError(record.error, record.stackTrace);
        }
      }),
    );
```

#### Simple Writer (Plain Text)

For basic custom destinations, format the `LogRecord` directly:

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
Chirp.root = ChirpLogger()..addWriter(FileWriter(File('app.log')));
```

#### Writer with Formatter

For rich formatting with colors or JSON structure, delegate to a `ChirpFormatter`:

```dart
class NetworkWriter extends ChirpWriter {
  final ChirpFormatter formatter;
  final HttpClient client;

  NetworkWriter({
    required this.client,
    this.formatter = const JsonLogFormatter(),
  });

  @override
  bool get requiresCallerInfo => formatter.requiresCallerInfo;

  @override
  void write(LogRecord record) {
    final buffer = MessageBuffer.console(
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
Chirp.root = ChirpLogger()..addWriter(NetworkWriter(client: HttpClient()));
```

#### Writer Options

| Property | Description |
| --- | --- |
| `requiresCallerInfo` | Return `true` if your writer needs file/line/class info (defaults to `false` to skip stack trace capture) |
| `minLogLevel` | Filter logs below this level via `setMinLogLevel()` |
| `interceptors` | Add transforms/filters via `addInterceptor()` |

## Backend / Server-Side Logging

For backend projects (Shelf, Dart Frog, CLI daemons), Chirp ships structured JSON formatters tailored to major cloud logging platforms.

### Basic Setup

Use `JsonLogFormatter` for platform-agnostic JSON logs:

```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
      .addConsoleWriter(formatter: const JsonLogFormatter());

  // Start your server...
}
```

```json
{"timestamp":"2025-01-15T10:30:45.123Z","level":"info","message":"Server started","port":8080}
```

### Cloud Platform Formatters

| Formatter | Platform | Log Levels | Special Features |
| --- | --- | --- | --- |
| `JsonLogFormatter` | Any | Chirp levels (lowercase) | Platform-agnostic |
| `GcpMessageFormatter` | Google Cloud | GCP `LogSeverity` | `sourceLocation`, labels, Error Reporting |
| `AwsMessageFormatter` | AWS CloudWatch | `TRACE`/`DEBUG`/`INFO`/`WARN`/`ERROR`/`FATAL` | CloudWatch log level filtering |

#### Google Cloud Platform (Cloud Run, Cloud Functions, GKE)

```dart
Chirp.root = ChirpLogger().addConsoleWriter(
  formatter: GcpMessageFormatter(
    serviceName: 'my-api-service', // For Error Reporting grouping
    serviceVersion: '1.0.0',
  ),
);
```

Output is automatically parsed by Cloud Logging:

```json
{
  "severity": "INFO",
  "message": "Request received",
  "timestamp": "2025-01-15T10:30:45.123Z",
  "logging.googleapis.com/sourceLocation": {"file": "...", "line": "42", "function": "..."},
  "logging.googleapis.com/labels": {"class": "UserService", "instance": "UserService@a1b2c3d4"}
}
```

GCP-specific features:

- Trace correlation via `logging.googleapis.com/trace` (set `projectId` and pass trace data)
- Automatic Error Reporting integration for errors and stack traces
- `sourceLocation` for click-to-source in Cloud Console

#### AWS (Lambda, ECS, CloudWatch)

```dart
Chirp.root = ChirpLogger()
    .addConsoleWriter(formatter: AwsMessageFormatter());
```

```json
{"timestamp":"2025-01-15T10:30:45.123Z","level":"INFO","message":"Request received"}
```

AWS log level mapping:

- `trace` → `TRACE`
- `debug` → `DEBUG`
- `info`, `notice`, `success` → `INFO`
- `warning` → `WARN`
- `error` → `ERROR`
- `critical`, `wtf` → `FATAL`

### Request-Scoped Logging

Create child loggers with request context in middleware — and add fields like `userId` mid-request — so every log for a request is correlated automatically:

```dart
Handler requestLoggingMiddleware(Handler innerHandler) {
  return (Request request) async {
    final requestId = request.headers['x-request-id'] ?? generateRequestId();

    // Create request-scoped logger
    final logger = Chirp.root.child(context: {
      'requestId': requestId,
      'method': request.method,
      'path': request.requestedUri.path,
    });

    logger.info('Request started');

    try {
      // Add user context once authenticated
      final user = await authenticate(request);
      if (user != null) {
        logger.context['userId'] = user.id;
      }

      final response = await innerHandler(request);
      logger.info('Request completed', data: {'statusCode': response.statusCode});
      return response;
    } catch (e, stackTrace) {
      logger.error('Request failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  };
}
```

### Environment-Based Configuration

Switch formatters automatically between local development and production:

```dart
void main() {
  final isProduction = Platform.environment.containsKey('PORT'); // Cloud Run

  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: isProduction
        ? GcpMessageFormatter(
            serviceName: Platform.environment['K_SERVICE'],
          )
        : RainbowMessageFormatter(),
  );
}
```

See [`examples/simple/bin/shelf_server.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/shelf_server.dart) for a complete Shelf server example.

## Testing

Capture formatted logs in tests by passing a custom `output` function, and reset `Chirp.root = null` in `tearDown`:

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

To inspect structured `LogRecord`s directly without parsing strings, attach a `DelegatedChirpWriter`:

```dart
test('logs structured data correctly', () {
  final records = <LogRecord>[];

  Chirp.root = ChirpLogger().addWriter(DelegatedChirpWriter(records.add));

  Chirp.info('Payment processed', data: {'amount': 99.99});

  expect(records.single.data, {'amount': 99.99});
});
```

## Examples

See [`examples/simple/bin/`](https://github.com/passsy/chirp/tree/main/examples/simple/bin) for runnable examples:

| File | Description |
| --- | --- |
| [`basic.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/basic.dart) | Zero-config logging |
| [`log_levels.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/log_levels.dart) | All 9 log levels + custom levels |
| [`child_loggers.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/child_loggers.dart) | Context inheritance |
| [`instance_tracking.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/instance_tracking.dart) | The `.chirp` extension |
| [`multiple_writers.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/multiple_writers.dart) | Console + JSON output |
| [`file_writer.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_writer.dart) | File logging with rotation |
| [`file_reader.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_reader.dart) | Live tailing rotating log files |
| [`lazy_messages.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/lazy_messages.dart) | Lazy message construction for performance |
| [`interceptors.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/interceptors.dart) | Filtering and transforming logs |
| [`library.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/library.dart) / [`app.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/app.dart) | Library logger adoption |
| [`shelf_server.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/shelf_server.dart) | Shelf HTTP server with GCP/AWS/JSON logging |
| [`color_support.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/color_support.dart) | Terminal color detection & overrides |
| [`time_display.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/time_display.dart) | Clock vs wall-clock timestamps |
| [`main.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/main.dart) | Span transformers (advanced) |

## License

MIT License — see [LICENSE](https://github.com/passsy/chirp/blob/main/LICENSE) for details.
