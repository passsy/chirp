---
name: chirp-logging
description: Add or change logging with package:chirp, including root setup, child loggers, structured context, writer configuration, and lazy logging. Use when a project uses Chirp or the user asks to adopt it.
---

# Logging with Chirp

Import `package:chirp/chirp.dart`.
Keep the application's existing logging configuration unless the task calls for changing it.

## Choose the logger

- `Chirp.info(...)` and the other static level methods work without setup using the default console logger.
- Inside an instance method, `chirp.info(...)` uses the extension on that instance and includes its identity.
  Use `Chirp` in static methods and top-level functions.
- `ChirpLogger(name: 'my_library')` is independent and silent until it has a writer or is adopted by another logger.
  Creating a named logger does not automatically attach it to `Chirp.root`.
- For application components that should inherit output and context, use `Chirp.root.child(name: 'Orders')` after the root has been configured.
- For a reusable library, expose an independent logger and let the application opt in with `Chirp.root.adopt(libraryLogger)`.
  Do not configure the application's global root from library code.

## Configure output at the application boundary

Configure a new logger and assign it to `Chirp.root`.
Reading `Chirp.root` before explicit assignment throws `StateError`, even though static logging works without setup.
Do not try to configure the default logger by calling `Chirp.root.addWriter(...)` before assigning a root.
Replacing the root during setup also avoids accumulating writers across repeated setup calls.

`addConsoleWriter()` returns the logger for chaining and uses `RainbowMessageFormatter` by default.
Use `JsonLogFormatter` when the destination expects structured JSON.
Logger-level `setMinLogLevel(...)` rejects records before constructing them; a writer's `minLogLevel` only controls that destination.
Choose thresholds based on the application's needs rather than assuming debug logs are disabled by default.

## Complete example

```dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
      .setMinLogLevel(ChirpLogLevel.info)
      .addConsoleWriter(formatter: JsonLogFormatter());

  final requestLogger = Chirp.root.child(
    name: 'Orders',
    context: {'requestId': 'req-42'},
  );
  requestLogger.info('Request received');

  try {
    throw StateError('Inventory unavailable');
  } catch (error, stackTrace) {
    requestLogger.error(
      'Order failed',
      error: error,
      stackTrace: stackTrace,
      data: {'orderId': 'order-7'},
    );
  }
}
```

## Context and errors

Use child `context` for fields shared by a request or operation, and `data` for fields specific to a log call.
Context is merged from parent to child, then with call data; more local values override the same keys.
Parent context is resolved at log time, so later mutations are visible to existing children.
Keep concurrent requests on separate child loggers instead of putting request-specific fields on the shared root.

Pass the caught error and stack trace through `error:` and `stackTrace:` to preserve their structure.
Choose fields deliberately; avoid putting credentials or entire sensitive request bodies in messages or data.
When transforming or filtering records, implement `ChirpInterceptor.intercept`; returning `null` drops a record.

## Defer expensive logging work

Pass a message closure when only the message is expensive.
Use a level's `...Lazy` method when constructing `data` or other arguments is expensive too.
Both defer work until the logger-level filter passes; writer filtering does not provide the same guarantee.
Keep these closures free of application side effects because filtered calls may never invoke them.

```dart
import 'dart:convert';

import 'package:chirp/chirp.dart';

void logSnapshot(ChirpLogger logger, Map<String, Object?> state) {
  logger.debug(() => 'State: ${jsonEncode(state)}');
  logger.debugLazy(
    (log) => log('State snapshot', data: {'encoded': jsonEncode(state)}),
  );
}
```

## Test logging without changing global state

For code accepting a logger, create a local `ChirpLogger().addConsoleWriter(output: messages.add)` with a `List<String>` to capture output.
Choose `JsonLogFormatter` and decode each message when asserting structured fields, so tests do not depend on terminal colors or timestamps.
If a test needs static or extension logging, assign a fresh root and use `Chirp.root = null` in teardown to restore the default behavior.

For custom writers, file rotation, or formatters beyond these patterns, consult the installed version's public API before choosing constructors and lifecycle methods.
