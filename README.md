# Chirp

A lightweight, flexible logging library for Dart with instance tracking and multiple output formats.

## Features

- **Simple API**: Just call `.log()` on a `Chirp` instance or `.chirp()` on any object
- **Instance Tracking**: Automatically tracks object instances with unique hashes
- **Named Loggers**: Create loggers for different subsystems (HTTP, Database, etc.)
- **Multiple Formats**: Default, compact, and JSON formatters included
- **Multiple Writers**: Send logs to multiple destinations with different formats
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

See [example/main.dart](example/main.dart) for more examples.

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
      