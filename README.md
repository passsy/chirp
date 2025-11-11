# Chirp

A lightweight, flexible logging library for Dart with instance tracking and multiple output formats.

## Features

- **Simple API**: Just call `.log()` on a `Chirp` instance or `.chirp()` on any object
- **Instance Tracking**: Automatically tracks object instances with unique hashes
- **Named Loggers**: Create loggers for different subsystems (HTTP, Database, etc.)
- **Structured Logging**: Attach key-value data to log entries for machine-readable logs
- **Contextual Logging**: Per-request/per-transaction loggers with automatic context propagation
- **Log Levels**: Debug, info, warning, error, and critical with GCP-compatible severity
- **Multiple Formats**: Default, compact, JSON, and GCP formatters included
- **Multiple Writers**: Send logs to multiple destinations with different formats
- **GCP Integration**: First-class support for Google Cloud Platform logging
- **Customizable**: Transform class names and create custom formatters

## Usage

### Basic Logging

```dart
import 'package:chirp/chirp.dart';

final logger = Chirp(name: 'MyApp');
logger.log('Application started');
logger.log('Error occurred', error: Exception('Something went wrong'));
```

### Extension-Based Logging

Log from any object with automatic instance tracking:

```dart
class UserService {
  void fetchUser(String userId) {
    chirp('Fetching user: $userId');
    // Simulate work
    chirp('User fetched successfully');
  }
}
```

### Custom Formatters

```dart
Chirp.root = Chirp(
  writers: [
    ConsoleChirpMessageWriter(
      formatter: CompactChirpMessageFormatter(),
    ),
  ],
);
```

### Structured Logging

Attach key-value data to your logs for better searchability and analysis:

```dart
final logger = Chirp(name: 'API');
logger.info(
  'User logged in',
  data: {
    'userId': 'user_123',
    'email': 'user@example.com',
    'loginMethod': 'oauth',
  },
);
```

### Contextual Logging (Per-Request Loggers)

Create loggers with contextual data that automatically attaches to all logs. Perfect for per-request or per-transaction logging:

```dart
// Immutable pattern - create logger with all context upfront
final requestLogger = Chirp.root.withContext({
  'requestId': 'REQ-123',
  'userId': 'user_456',
});

// All logs automatically include requestId and userId
requestLogger.info('Request received');
requestLogger.info('Processing payment');
requestLogger.info('Request completed');
```

Or use the mutable pattern to add context as it becomes available:

```dart
// Start with minimal context
final logger = Chirp(name: 'API', context: {'requestId': 'REQ-123'});

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

Benefits for cloud logging:
- All logs from a request share the same `requestId` for easy correlation in GCP Logs Explorer
- Add user context, session IDs, trace IDs, etc. automatically to every log
- Create nested contexts (request → transaction → operation)

### Log Levels

Use semantic log levels for better filtering and severity indication:

```dart
logger.debug('Debugging info');
logger.info('General information');
logger.warning('Warning message');
logger.error('Error occurred');
logger.critical('Critical system failure');
```

### Google Cloud Platform (GCP) Integration

Chirp includes a GCP-compatible formatter that outputs logs in the format expected by Google Cloud Logging:

```dart
Chirp.root = Chirp(
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
service.chirpError(
  'Payment failed',
  error: e,
  data: {'userId': 'user_123', 'amount': 99.99},
);
```

The GCP formatter outputs JSON with:
- `severity`: GCP-compatible severity levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `message`: Your log message
- `timestamp`: ISO 8601 formatted timestamp
- `logName`: Properly formatted GCP log name
- `labels`: Class name and instance tracking
- Structured data merged at the root level for easy querying

### Multiple Writers

Send the same log to multiple destinations with different formats:

```dart
Chirp.root = Chirp(
  writers: [
    ConsoleChirpMessageWriter(
      formatter: DefaultChirpMessageFormatter(),
    ),
    ConsoleChirpMessageWriter(
      formatter: JsonChirpMessageFormatter(),
      output: (msg) => writeToFile(msg),
    ),
  ],
);
```

## Examples

- [example/main.dart](example/main.dart) - Basic usage, formatters, and multiple writers
- [example/gcp_logging.dart](example/gcp_logging.dart) - GCP Cloud Logging integration
- [example/contextual_logging.dart](example/contextual_logging.dart) - Per-request loggers and contextual data

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
      