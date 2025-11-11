# Chirp

A lightweight, flexible logging library for Dart with instance tracking, child loggers, and multiple output formats.

## Features

- **Simple API**: Static methods, named loggers, or `.chirp` extension on any object
- **Child Loggers**: Winston-style `.child()` method for creating loggers with inherited configuration
- **Instance Tracking**: Automatically tracks object instances with unique hashes
- **Named Loggers**: Create loggers for different subsystems (HTTP, Database, etc.)
- **Structured Logging**: Attach key-value data to log entries for machine-readable logs
- **Contextual Logging**: Per-request/per-transaction loggers with automatic context propagation
- **7 Log Levels**: Trace, debug, info, warning, error, critical, and wtf with comprehensive documentation
- **Multiple Formats**: Compact, JSON, GCP, and Rainbow formatters included
- **Multiple Writers**: Send logs to multiple destinations with different formats per writer
- **GCP Integration**: First-class support for Google Cloud Platform logging
- **Customizable**: Transform class names and create custom formatters

## Usage

### Basic Logging - Static Methods

Use static methods for quick logging without creating logger instances:

```dart
import 'package:chirp/chirp.dart';

// Static methods on Chirp class
Chirp.trace('Detailed trace information');
Chirp.debug('Debug information');
Chirp.info('Application started');
Chirp.warning('Deprecated API used');
Chirp.error('Failed to connect', error: e, stackTrace: st);
Chirp.critical('Database connection lost');
Chirp.wtf('Impossible state detected'); // What a Terrible Failure
```

### Named Loggers

Create named loggers for different parts of your application:

```dart
final logger = ChirpLogger(name: 'MyApp');
logger.info('Application started');
logger.error('Error occurred', error: Exception('Something went wrong'));
```

### Extension-Based Logging

Log from any object with automatic instance tracking:

```dart
class UserService {
  void fetchUser(String userId) {
    chirp.info('Fetching user: $userId');
    // Simulate work
    chirp.info('User fetched successfully');
  }
}

// Different instances get different hash codes
final service1 = UserService();
final service2 = UserService();
service1.chirp.info('From service 1'); // Instance hash: a1b2
service2.chirp.info('From service 2'); // Instance hash: c3d4
```

### Child Loggers (Winston-Style)

Create child loggers that inherit their parent's writers configuration but add their own context. Perfect for per-request or per-transaction logging:

```dart
// Configure root logger once
Chirp.root = ChirpLogger(
  writers: [
    ConsoleChirpMessageWriter(
      formatter: GcpChirpMessageFormatter(
        projectId: 'my-project',
        logName: 'app-logs',
      ),
    ),
  ],
);

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

Attach key-value data to your logs for better searchability and analysis:

```dart
Chirp.info(
  'User logged in',
  data: {
    'userId': 'user_123',
    'email': 'user@example.com',
    'loginMethod': 'oauth',
  },
);

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

Chirp provides 7 semantic log levels with comprehensive documentation:

| Level | Severity | Use For | Example |
|-------|----------|---------|---------|
| **trace** | 0 | Most detailed execution flow | Loop iterations, variable values |
| **debug** | 100 | Diagnostic information | Function parameters, state changes |
| **info** | 200 | Routine operational messages (DEFAULT) | App started, request completed |
| **warning** | 400 | Potentially problematic situations | Deprecated usage, resource limits |
| **error** | 500 | Errors that prevent specific operations | API failures, validation errors |
| **critical** | 600 | Severe errors affecting core functionality | Database connection lost |
| **wtf** | 1000 | Impossible situations that should never happen | Invariant violations |

```dart
Chirp.trace('Entering loop iteration', data: {'i': 42});
Chirp.debug('Cache miss for key: $key');
Chirp.info('User logged in', data: {'userId': 'user_123'});
Chirp.warning('API rate limit approaching', data: {'used': 950, 'limit': 1000});
Chirp.error('Payment failed', error: e, stackTrace: st);
Chirp.critical('Database connection lost', data: {'attempt': 3});
Chirp.wtf('User has negative age', data: {'age': -5}); // Should be impossible!
```

**Custom Log Levels:**
```dart
// Create your own levels
const verbose = ChirpLogLevel('verbose', 50);
const fatal = ChirpLogLevel('fatal', 700);

Chirp.log('Custom message', level: verbose);
```

### Google Cloud Platform (GCP) Integration

Chirp includes a GCP-compatible formatter that outputs logs in the format expected by Google Cloud Logging:

```dart
Chirp.root = ChirpLogger(
  writers: [
    ConsoleChirpMessageWriter(
      formatter: GcpChirpMessageFormatter(
        projectId: 'my-project-id',
        logName: 'application-logs',
      ),
    ),
  ],
);

// Logs are automatically formatted for GCP with proper severity levels
Chirp.error(
  'Payment failed',
  error: e,
  stackTrace: st,
  data: {'userId': 'user_123', 'amount': 99.99},
);
```

**GCP Formatter Output:**
```json
{
  "severity": "ERROR",
  "message": "Payment failed",
  "timestamp": "2025-11-11T05:00:00.000Z",
  "logName": "projects/my-project-id/logs/application-logs",
  "userId": "user_123",
  "amount": 99.99,
  "error": "Exception: Insufficient funds",
  "stackTrace": "..."
}
```

**GCP Severity Mapping:**
- `trace` (0-99) → `DEFAULT`
- `debug` (100-199) → `DEBUG`
- `info` (200-299) → `INFO`
- `warning` (400-499) → `WARNING`
- `error` (500-599) → `ERROR`
- `critical` (600-699) → `CRITICAL`
- `wtf` (1000+) → `EMERGENCY`

### Multiple Writers with Different Formats

Each writer can have its own formatter, perfect for multi-environment setups:

```dart
Chirp.root = ChirpLogger(
  writers: [
    // Colorful console logs for development
    ConsoleChirpMessageWriter(
      formatter: CompactChirpMessageFormatter(),
    ),
    // JSON logs to file for production
    ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),
      output: (msg) => writeToFile('app.log', msg),
    ),
    // GCP format for cloud logging
    ConsoleChirpMessageWriter(
      formatter: GcpChirpMessageFormatter(
        projectId: 'my-project',
        logName: 'app-logs',
      ),
      output: (msg) => sendToGcp(msg),
    ),
  ],
);
```

### Available Formatters

**CompactChirpMessageFormatter** - Colorful, human-readable format for development
```
08:30:45.123 ══════════════════════════════════ UserService:a1b2
User logged in
```

**JsonChirpMessageFormatter** - Machine-readable JSON format
```json
{"timestamp":"2025-11-11T08:30:45.123","level":"info","class":"UserService","hash":"a1b2","message":"User logged in"}
```

**GcpChirpMessageFormatter** - Google Cloud Platform compatible format
```json
{"severity":"INFO","message":"User logged in","timestamp":"2025-11-11T08:30:45.123Z","logName":"projects/my-project/logs/app"}
```

**RainbowMessageFormatter** - Colorful, categorized format with class name colors
```
08:30:45.123 ══════════════════════════════════ UserService:a1b2
User logged in
  data: userId=user_123, email=user@example.com
```

## Configuration

### Root Logger

Configure the global root logger that all child loggers and extensions inherit from:

```dart
void main() {
  // Configure once at app startup
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-project',
          logName: 'app-logs',
        ),
      ),
    ],
  );

  // All loggers now use GCP format
  runApp();
}
```

### Custom Formatters

Create your own formatter by extending `ChirpMessageFormatter`:

```dart
class MyCustomFormatter extends ChirpMessageFormatter {
  @override
  String format(LogRecord entry) {
    return '[${entry.level.name.toUpperCase()}] ${entry.message}';
  }
}
```

## Real-World Example

```dart
// Setup (once at app startup)
void main() {
  Chirp.root = ChirpLogger(
    writers: [
      ConsoleChirpMessageWriter(
        formatter: GcpChirpMessageFormatter(
          projectId: 'my-project',
          logName: 'app-logs',
        ),
      ),
    ],
  );

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

## Examples

See [example/main.dart](example/main.dart) for a comprehensive example covering:
- All 7 log levels (trace through wtf)
- Named loggers with structured data
- Child loggers for per-request context
- Instance tracking with `.chirp` extension
- GCP Cloud Logging format
- Multiple writers with different formats

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
