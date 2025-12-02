# chirp_protocol

[![Pub](https://img.shields.io/pub/v/chirp_protocol)](https://pub.dev/packages/chirp_protocol)
[![Pub Likes](https://img.shields.io/pub/likes/chirp_protocol)](https://pub.dev/packages/chirp_protocol/score)
![License](https://img.shields.io/github/license/passsy/chirp)
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)

Stable logging API for packages. Use `chirp` for the full implementation with formatters and writers.

## When to Use This Package

Use `chirp_protocol` when you're writing a **package** that wants to emit logs without forcing a specific logging implementation on your users.

| Package | Use Case                            |
|---------|-------------------------------------|
| `chirp_protocol` | packages that emit logs             |
| `chirp` | Applications that configure logging |

## Usage

Add `chirp_protocol` as a dependency in your package:

```yaml
dependencies:
  chirp_protocol: ^0.5.0
```

Then use the `Chirp` API or the `.chirp` extension:

```dart
import 'package:chirp_protocol/chirp_protocol.dart';

class MyPackageClient {
  Future<Response> fetch(String url) async {
    chirp.info('Fetching', data: {'url': url});
    try {
      final response = await _doFetch(url);
      chirp.debug('Response received', data: {'status': response.statusCode});
      return response;
    } catch (e, stackTrace) {
      chirp.error('Fetch failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

## How It Works

Your package logs via `Chirp.root`, which defaults to a no-op logger. When users add `chirp` to their application, they configure `Chirp.root` with writers and formatters - your package's logs automatically flow through their configuration.

```dart
// In the user's application (using chirp package)
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
    ..addConsoleWriter(formatter: RainbowMessageFormatter());

  // Now all logs from your package appear in the console
  final client = MyPackageClient();
  client.fetch('https://api.example.com');
}
```

## API

### Log Levels

| Level | Severity | Use For |
|-------|----------|---------|
| `trace` | 0 | Detailed execution flow |
| `debug` | 100 | Diagnostic information |
| `info` | 200 | Routine operational messages |
| `notice` | 300 | Significant events |
| `warning` | 400 | Potentially problematic situations |
| `error` | 500 | Errors preventing operations |
| `critical` | 600 | Severe errors |
| `wtf` | 1000 | Impossible situations |

### Logging Methods

```dart
Chirp.trace('message');
Chirp.debug('message');
Chirp.info('message');
Chirp.notice('message');
Chirp.warning('message');
Chirp.error('message', error: e, stackTrace: stackTrace);
Chirp.critical('message');
Chirp.wtf('message');
```

### Instance Logging

Use the `.chirp` extension for automatic instance tracking:

```dart
class MyService {
  void doWork() {
    chirp.info('Working'); // Includes instance hash for debugging
  }
}
```

### Structured Data

Attach key-value data to logs:

```dart
Chirp.info('User action', data: {
  'userId': 'user_123',
  'action': 'login',
});
```

### Custom Log Levels

Create application-specific log levels:

```dart
const verbose = ChirpLogLevel('verbose', 50);  // Between trace and debug
const alert = ChirpLogLevel('alert', 450);     // Between warning and error

Chirp.log('Detailed trace info', level: verbose);
```

### ChirpLogger

Create named loggers or loggers with context:

```dart
final logger = ChirpLogger(name: 'MyPackage');
logger.info('Message from MyPackage');

// Child loggers inherit parent configuration
final childLogger = logger.child(context: {'requestId': 'abc123'});
childLogger.info('Request started'); // Includes requestId in output
```

### ChirpWriter

Implement custom log destinations:

```dart
class MyWriter implements ChirpWriter {
  @override
  void write(LogRecord record) {
    print('${record.level.name}: ${record.message}');
  }
}

final logger = ChirpLogger()..addWriter(MyWriter());
```

### LogRecord

The immutable data structure passed to writers:

```dart
class MyWriter implements ChirpWriter {
  @override
  void write(LogRecord record) {
    // Access log data
    print(record.message);       // The log message
    print(record.date);          // When the log was created
    print(record.level);         // ChirpLogLevel (info, error, etc.)
    print(record.error);         // Optional error object
    print(record.stackTrace);    // Optional stack trace
    print(record.data);          // Optional structured data map
    print(record.loggerName);    // Logger name if set
    print(record.instance);      // Object instance if using .chirp extension
  }
}
```

### FormatOptions

Pass per-log formatting hints to formatters:

```dart
Chirp.info(
  'Debug output',
  formatOptions: [MyFormatOptions(verbose: true)],
);
```

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
