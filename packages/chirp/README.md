# Chirp

[![Pub](https://img.shields.io/pub/v/chirp)](https://pub.dev/packages/chirp)
[![Pub Likes](https://img.shields.io/pub/likes/chirp)](https://pub.dev/packages/chirp/score)
[![License](https://img.shields.io/github/license/passsy/chirp)](https://github.com/passsy/chirp/blob/main/LICENSE)
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)

**Logging for Dart and Flutter that feels right from line one.**

Birds chirp to signal everything from danger to delight — your app chirps through its logs. Start with a single `Chirp.info('Hello!')` with zero setup. As your app grows, Chirp grows right along with you: per-instance `.chirp` loggers, structured data, inherited request context, rotating log files with live tailing, cloud-native JSON for GCP and AWS, and a widget-like span system for custom formats.

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

## Install

```bash
dart pub add chirp
# or in a Flutter project:
flutter pub add chirp
```

Or add it to your `pubspec.yaml`:

```yaml
dependencies:
  chirp: ^0.10.0
```

## Why Chirp

- **Zero setup to start**: Call `Chirp.info('hello')` anywhere and get readable, color-coded console logs right away.
- **Every object gets `.chirp`**: Log from inside any class with `chirp.info(...)` to tag each message with `ClassName@hash`, making it easy to tell multiple instances apart.
- **Structured data, not string glue**: Pass maps and nested objects via `data: {...}` — formatted nicely in development and emitted as clean JSON in production.
- **Child loggers with shared context**: Attach `requestId` or `userId` once and carry it through every log in an operation.
- **9 semantic levels + custom levels**: From `trace` to `wtf`, including `notice` and `success`, plus your own `ChirpLogLevel`s.
- **Dev beauty, cloud JSON**: `RainbowMessageFormatter` and `CompactChirpMessageFormatter` for humans; `GcpMessageFormatter`, `AwsMessageFormatter`, and `JsonLogFormatter` for servers.
- **Rotating files & live tailing**: Write size- or time-rotated (and gzipped) logs with `RotatingFileWriter`, and stream history + new lines across rotations with `writer.reader.tail()`.
- **Widget-like span formatting**: Compose custom console formats from spans, or tweak built-in formatters in place with `spanTransformers`.
- **Lazy logging with accurate callers**: Defer expensive message or `data` construction until a log actually passes the level filter — while still reporting the real call site.
- **Built for packages too**: Ship silent named loggers in reusable libraries that apps can opt into with one call to `adopt()`.
- **Bundled AI agent skill**: Install the `chirp-logging` skill with `dart run skills@ get --package chirp` so coding agents configure Chirp idiomatically.

## Quick Start

Skip configuration completely if you just want to log — `Chirp.info()` works out of the box with `PrintConsoleWriter` and `RainbowMessageFormatter`. When you are ready to customize, replace `Chirp.root` once at startup:

### Flutter & CLI apps

```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: RainbowMessageFormatter(
      options: const RainbowFormatOptions(data: DataPresentation.multiline),
    ),
  );

  try {
    login();
    Chirp.success('User logged in', data: {'userId': 'abc123'});
  } catch (e, stack) {
    Chirp.error('Login failed', error: e, stackTrace: stack);
  }

  runApp(const MyApp());
}
```

### Dart backends (Shelf, Dart Frog, CLI servers)

```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
      .addConsoleWriter(formatter: const JsonLogFormatter());

  // Inside your request handler:
  final logger = Chirp.root.child(
    context: {'requestId': request.headers['x-request-id']},
  );
  logger.info('Request received');
}
```

```json
{"timestamp":"2025-01-15T14:32:05.123Z","level":"info","message":"Request received","requestId":"req-abc"}
```

### Reusable Dart packages

Expose a standalone named logger with no writers. It stays completely silent until the host app chooses to adopt it:

```dart
// In your package:
final httpLogger = ChirpLogger(name: 'http_client');

void get(String url) {
  httpLogger.debug('GET $url');
}
```

```dart
// In the consuming app:
void main() {
  Chirp.root = ChirpLogger().addConsoleWriter();
  Chirp.root.adopt(httpLogger); // Package logs now flow through your root!

  get('https://api.example.com');
}
```

See [`examples/simple/bin/library.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/library.dart) and [`examples/simple/bin/app.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/app.dart) for a runnable example.

## Core Concepts

### Instance Tracking (`chirp` vs `Chirp`)

Every Dart object has a `.chirp` extension that returns a cached logger tied to that specific instance. When you have multiple controllers, sockets, or services alive at once, each instance gets its own short hash in the logs:

```dart
class PaymentProcessor {
  static void validateConfig() {
    Chirp.info('Validating config'); // Static method → Chirp
  }

  void processPayment(double amount) {
    chirp.info('Processing payment', data: {'amount': amount}); // Instance → chirp
  }
}

final p1 = PaymentProcessor();
final p2 = PaymentProcessor();
p1.processPayment(49.0);
p2.processPayment(19.5);
```

```text
14:32:05.123 [info] payment:7 PaymentProcessor@a1b2 processPayment Processing payment (amount: 49.0)
14:32:05.124 [info] payment:7 PaymentProcessor@c3d4 processPayment Processing payment (amount: 19.5)
```

| Where you are | Use | Why |
| --- | --- | --- |
| Instance methods | `chirp.info(...)` | Tags the log with `ClassName@hash` for that instance |
| Static methods & top-level functions | `Chirp.info(...)` | No instance to track |
| Inside a reusable package | `myPackageLogger.info(...)` | Stays silent unless the host app adopts it |

### Structured Data & Child Loggers

Attach key-value maps to any log call — nested maps, lists, and custom objects all work:

```dart
Chirp.info('Order placed', data: {
  'order': {
    'id': 'ORD-123',
    'items': [
      {'sku': 'WIDGET-1', 'qty': 2},
      {'sku': 'GADGET-5', 'qty': 1},
    ],
    'shipping': {'method': 'express', 'city': 'Berlin'},
  },
});
```

When multiple logs share the same metadata (like a request, job, or screen), create a child logger with `child()`. Children inherit their parent's writers and merge parent context, child context, and per-call `data`:

```dart
final requestLogger = Chirp.root.child(
  name: 'API',
  context: {'requestId': 'REQ-123'},
);
requestLogger.info('Request received');

// Add context as you learn more
requestLogger.context['userId'] = 'user_456';
requestLogger.info('User authenticated');

// Nest children for sub-operations
final txnLogger = requestLogger.child(context: {'transactionId': 'TXN-789'});
txnLogger.info('Charging card'); // Includes requestId, userId, and transactionId
```

You can also pass `instance:` to `child(name: 'API', instance: this, context: {...})`.

### Log Levels

Chirp ships with 9 semantic levels, ordered by severity:

| Level | Severity | When to reach for it |
| --- | --- | --- |
| `trace` | 0 | Fine-grained execution flow (loop iterations, raw payloads) |
| `debug` | 100 | Diagnostic details (cache misses, state transitions) |
| `info` | 200 | Normal milestones (app started, request completed) |
| `notice` | 300 | Normal but notable events (role changes, config updates) |
| `success` | 310 | Positive outcomes (login succeeded, deploy finished) |
| `warning` | 400 | Something looks off (rate limit nearing, fallback used) |
| `error` | 500 | An operation failed (API error, failed payment) |
| `critical` | 600 | Core functionality is broken (database unreachable) |
| `wtf` | 1000 | Should never happen (broken invariants) |

Every level method accepts optional `error:` and `stackTrace:` parameters — handy for logging retries as `warning` or recovered failures as `info`:

```dart
Chirp.warning('Retrying request', error: e, stackTrace: st, data: {'attempt': 2});
Chirp.success('Deployment completed', data: {'version': '1.2.0'});
```

Need your own levels? Construct a `ChirpLogLevel` with any name and severity:

```dart
const verbose = ChirpLogLevel('verbose', 50);
const fatal = ChirpLogLevel('fatal', 700);

Chirp.log('Starting worker', level: verbose);
```

### Lazy Logging

Avoid paying for expensive string formatting or `data` serialization when a log level is filtered out.

Pass a closure when only the **message** is expensive:

```dart
// Only runs jsonEncode when trace is enabled
logger.trace(() => 'Payload: ${jsonEncode(hugeMap)}');
```

Use the `...Lazy` variant when **`data`, `error`, or other arguments** are expensive too:

```dart
// Defers every argument until the logger decides to emit
Chirp.debugLazy(
  (log) => log('State snapshot', data: {'state': renderState(), 'metrics': dump()}),
);

Chirp.logLazy(
  (log) => log('Custom level snapshot', data: {'size': computeSize()}),
  level: ChirpLogLevel.trace,
);
```

Every built-in level has a matching `...Lazy` method (`traceLazy`, `debugLazy`, `infoLazy`, `noticeLazy`, `successLazy`, `warningLazy`, `errorLazy`, `criticalLazy`, `wtfLazy`, plus `logLazy`) on both `Chirp` and `ChirpLogger`. Caller info still points to the `...Lazy(...)` call site, not inside the closure.

## Formatters & Writers

### Built-in Formatters

| Formatter | Best for | Highlights |
| --- | --- | --- |
| `RainbowMessageFormatter` | Local development (default) | Color-coded levels, unique color per class, inline or multiline YAML-like data |
| `CompactChirpMessageFormatter` | Dense terminal output | Single-line format with caller location and inline data |
| `SimpleConsoleMessageFormatter` | Full-detail debugging | Toggles for caller, method, instance, logger name, and data |
| `JsonLogFormatter` | Generic JSON log collectors | Single-line UTF-8 JSON with UTC timestamps and root-level data |
| `GcpMessageFormatter` | Google Cloud Run / GKE / Functions | GCP `severity`, `sourceLocation`, labels, and Error Reporting support |
| `AwsMessageFormatter` | AWS Lambda / ECS / CloudWatch | CloudWatch levels (`TRACE`..`FATAL`) and structured JSON |

### Console Writers & Terminal Colors

| Writer | Mechanism | Best for |
| --- | --- | --- |
| `PrintConsoleWriter` | `print()` → stdout / logcat / os_log | Production, CI/CD, release builds (default for `addConsoleWriter()`) |
| `DeveloperLogConsoleWriter` | `dart:developer` `log()` | Flutter DevTools Logging view (unlimited length, requires debugger) |

`PrintConsoleWriter` automatically chunks long messages to work around Android's and iOS's ~1024-character print limits. Note that `DeveloperLogConsoleWriter` strips ANSI colors and only emits while a debugger is attached.

Chirp auto-detects terminal color capabilities. You can override them via environment variables or code:

```bash
NO_COLOR=1 dart run      # Disable colors (https://no-color.org/)
FORCE_COLOR=3 dart run   # 0=off, 1=16 colors, 2=256 colors, 3=truecolor
```

```dart
Chirp.root = ChirpLogger().addConsoleWriter(
  capabilities: const TerminalCapabilities(
    colorSupport: TerminalColorSupport.none,
  ),
);
```

### Rotating File Logging & Live Tailing

Write logs to disk with size- or time-based rotation, automatic retention cleanup, and background gzip compression (in an isolate) using `RotatingFileWriter`:

```dart
final fileWriter = RotatingFileWriter(
  baseFilePathProvider: () => '/var/log/app.jsonl',
  formatter: const JsonLogFormatter(),
  rotationConfig: FileRotationConfig.size(
    maxSize: 50 * 1024 * 1024, // Rotate at 50 MB
    maxFiles: 10,
    compress: true,
  ),
);

// Or rotate daily and keep 30 days:
// rotationConfig: FileRotationConfig.daily(maxAge: Duration(days: 30), compress: true)

Chirp.root = ChirpLogger()
    .addConsoleWriter()
    .addWriter(fileWriter);

// On shutdown:
await fileWriter.close();
```

Need to inspect or stream logs from those rotating files (for an in-app debug console, CLI `tail -f`, or support bundle)? Every `RotatingFileWriter` exposes a `RotatingFileReader` via `writer.reader` that reads across active, rotated, and gzipped files without dropping or duplicating records:

```dart
// Emit the last 50 records, then keep streaming new ones live across rotations
final sub = fileWriter.reader.tail(last: 50).listen(stdout.writeln);

// Or read history once:
await for (final entry in fileWriter.reader.read(last: 100)) {
  stdout.writeln(entry);
}
```

See [`examples/simple/bin/file_writer.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_writer.dart) and [`examples/simple/bin/file_reader.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_reader.dart).

### Multiple Writers & Level Filtering

Combine as many writers as you want, each with its own formatter and minimum log level:

```dart
Chirp.root = ChirpLogger()
    .setMinLogLevel(ChirpLogLevel.debug) // Logger-wide floor (skips trace early)
    .addConsoleWriter(formatter: CompactChirpMessageFormatter())
    .addWriter(
      RotatingFileWriter(
        baseFilePathProvider: () => 'errors.jsonl',
        formatter: const JsonLogFormatter(),
        rotationConfig: FileRotationConfig.daily(maxAge: const Duration(days: 14)),
      )..setMinLogLevel(ChirpLogLevel.error), // File only receives error+
    );
```

Logger-level `setMinLogLevel()` short-circuits before records or lazy builders are evaluated; writer-level filtering controls each individual destination.

### Interceptors

Transform, enrich, sample, or drop records before they reach writers. Return `null` to drop a record.

For quick one-liners, use `DelegatedChirpInterceptor`:

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

For reusable or stateful logic (redaction, rate limiting, enrichment), extend or implement `ChirpInterceptor`:

```dart
class RedactTokensInterceptor extends ChirpInterceptor {
  @override
  LogRecord? intercept(LogRecord record) {
    if (!record.data.containsKey('token')) return record;
    return record.copyWith(data: {...record.data, 'token': '***'});
  }
}
```

Interceptors can be attached to either a logger or a specific writer. See [`examples/simple/bin/interceptors.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/interceptors.dart) for more.

## Make It Yours

### Span-Based Formatting

Chirp's console formatters are built on a **composable span tree** — if you have ever built a Flutter widget tree, this will feel right at home.

Build a custom formatter by assembling spans:

```dart
import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

class MyFormatter extends SpanBasedFormatter {
  MyFormatter({super.spanTransformers});

  @override
  LogSpan buildSpan(LogRecord record) {
    return SpanSequence(children: [
      Timestamp(record.timestamp),
      Whitespace(),
      BracketedLogLevel(record.level),
      Surrounded(prefix: Whitespace(), child: ClassName.fromRecord(record)),
      Whitespace(),
      LogMessage(record.message),
    ]);
  }
}
```

Even better, you don't have to write a formatter from scratch just to tweak one detail. Pass `spanTransformers` to any `SpanBasedFormatter` to wrap, replace, or remove spans in place:

```dart
final formatter = RainbowMessageFormatter(
  spanTransformers: [
    (tree, record) {
      final badge = record.level >= ChirpLogLevel.error ? '🔴 ' : '🟢 ';
      tree.findFirst<LogMessage>()?.wrap(
        (child) => SpanSequence(children: [PlainText(badge), child]),
      );
    },
  ],
);
```

See [docs/SPANS.md](https://github.com/passsy/chirp/blob/main/docs/SPANS.md) for the full span reference.

### Custom Writers & Formatters

Need to ship logs to Sentry, Datadog, a database, or an in-app overlay? Use `DelegatedChirpWriter` inline:

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

Or extend `ChirpWriter` (and optionally `ChirpFormatter`) when you need configuration or lifecycle hooks:

```dart
class SimpleTextFormatter extends ChirpFormatter {
  @override
  void format(LogRecord record, MessageBuffer buffer) {
    buffer.write('[${record.level.name.toUpperCase()}] ${record.message}');
  }
}

class WebhookWriter extends ChirpWriter {
  WebhookWriter(this.endpoint, {this.formatter = const JsonLogFormatter()});

  final Uri endpoint;
  final ChirpFormatter formatter;

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
    // Queue buffer.toString() for async delivery to endpoint
  }
}
```

Setting `requiresCallerInfo => false` (the default on `ChirpWriter`) skips `StackTrace.current` capture entirely when no writer or interceptor needs caller locations.

## Cloud & Backend Logging

Switch between colorful local output and cloud-native structured JSON based on environment:

```dart
void main() {
  final isProduction = Platform.environment.containsKey('PORT');

  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: isProduction
        ? GcpMessageFormatter(
            serviceName: Platform.environment['K_SERVICE'],
            serviceVersion: '1.0.0',
          )
        : RainbowMessageFormatter(),
  );
}
```

- **Google Cloud (`GcpMessageFormatter`)**: Maps levels to GCP `LogSeverity`, populates `logging.googleapis.com/sourceLocation` for click-to-source in Cloud Console, supports trace correlation via `projectId`, and formats errors for Google Error Reporting.
- **AWS (`AwsMessageFormatter`)**: Emits CloudWatch-compatible levels (`TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`) with UTC timestamps and optional source locations.
- **Any other collector (`JsonLogFormatter`)**: Single-line JSON with Chirp's level names and merged data fields.

Combine this with request-scoped child loggers in middleware (Shelf, Dart Frog, etc.) so every log emitted while handling a request shares its `requestId`, `method`, and `path`:

```dart
Handler requestLoggingMiddleware(Handler innerHandler) {
  return (Request request) async {
    final logger = Chirp.root.child(context: {
      'requestId': request.headers['x-request-id'] ?? generateRequestId(),
      'method': request.method,
      'path': request.requestedUri.path,
    });

    logger.info('Request started');
    try {
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

See [`examples/simple/bin/shelf_server.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/shelf_server.dart) for a complete Shelf server example.

## Testing

Always **replace** `Chirp.root` rather than mutating it (reading `Chirp.root` before assignment throws a `StateError` by design, preventing accidental writer accumulation across tests), and reset `Chirp.root = null` in `tearDown`:

```dart
import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  late List<String> logs;

  setUp(() {
    logs = [];
    Chirp.root = ChirpLogger().addConsoleWriter(output: logs.add);
  });

  tearDown(() => Chirp.root = null);

  test('logs user login', () {
    myLoginFunction();

    expect(logs, hasLength(1));
    expect(logs.single, contains('User logged in'));
  });
}
```

To assert on structured fields directly without parsing formatted strings, attach a `DelegatedChirpWriter`:

```dart
test('logs structured payment data', () {
  final records = <LogRecord>[];
  Chirp.root = ChirpLogger().addWriter(DelegatedChirpWriter(records.add));

  Chirp.info('Payment processed', data: {'amount': 99.99});

  expect(records.single.data, {'amount': 99.99});
});
```

## AI Agent Skill

Chirp bundles a `chirp-logging` skill with ready-to-use setups for Flutter apps, server backends, and reusable packages, plus guidance on structured context, writers, and lazy logging. Install it from your project root:

```bash
dart run skills@ get --package chirp
```

See [Dart package skills](https://dart.dev/ai/package-skills) for CLI setup and supported agents.

## Examples

Runnable examples live in [`examples/simple/bin/`](https://github.com/passsy/chirp/tree/main/examples/simple/bin):

| File | What it shows |
| --- | --- |
| [`basic.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/basic.dart) | Zero-config logging |
| [`log_levels.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/log_levels.dart) | All 9 log levels + custom levels |
| [`instance_tracking.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/instance_tracking.dart) | The `.chirp` instance extension |
| [`child_loggers.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/child_loggers.dart) | Context inheritance & mutable context |
| [`multiple_writers.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/multiple_writers.dart) | Console + JSON output |
| [`file_writer.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_writer.dart) | File logging with rotation |
| [`file_reader.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/file_reader.dart) | Live tailing rotating log files |
| [`lazy_messages.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/lazy_messages.dart) | Lazy message construction |
| [`interceptors.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/interceptors.dart) | Filtering, redaction, and enrichment |
| [`library.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/library.dart) / [`app.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/app.dart) | Library logger adoption |
| [`shelf_server.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/shelf_server.dart) | Shelf HTTP server with GCP/AWS/JSON logging |
| [`color_support.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/color_support.dart) | Terminal color detection & overrides |
| [`time_display.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/time_display.dart) | Clock vs wall-clock timestamps |
| [`main.dart`](https://github.com/passsy/chirp/blob/main/examples/simple/bin/main.dart) | Span transformers (advanced) |

## License

MIT License — see [LICENSE](https://github.com/passsy/chirp/blob/main/LICENSE) for details.
