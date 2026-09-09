---
name: chirp-logging
description: Set up and use package:chirp in Flutter apps, server backends, and reusable Dart packages, including structured context, writers, and lazy logging. Use when a project uses Chirp or the user asks to adopt it.
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

## Choose the setup for the project

### Flutter apps

Configure the root before `runApp`.
For Flutter DevTools and the attached debugger, use `DeveloperLogConsoleWriter`, which forwards records to `dart:developer` with their level, error, and stack trace.
It requires a debugger connection and does not provide release-build, logcat, or Xcode console output.
When those destinations are required, configure `addConsoleWriter(formatter: RainbowMessageFormatter())` or an appropriate persistent writer instead of relying solely on the developer writer.

```dart
import 'package:chirp/chirp.dart';
import 'package:flutter/material.dart';

void main() {
  Chirp.root = ChirpLogger()
    ..addWriter(DeveloperLogConsoleWriter());

  Chirp.info('Application started');
  runApp(const MaterialApp(home: Scaffold(body: Text('Ready'))));
}
```

Use `chirp` in widget or service instance methods and `Chirp` in static or top-level code.
Keep Flutter imports in the application; the Chirp package itself does not require Flutter.

### Server-side backends

Use structured JSON console output for log collectors and a child logger for each request or job.
Configure the root once at process startup, then pass the request logger to code that needs its context.
`JsonLogFormatter` is a general-purpose default; use `GcpMessageFormatter` or `AwsMessageFormatter` when integrating with their respective cloud logging formats.
The example uses an `info` threshold; choose the deployment's intended level explicitly.

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

### Reusable packages

Expose a named, standalone logger without writers and log through that logger inside the package.
This keeps the package silent until the host application opts in.
Do not assign `Chirp.root`, attach console writers, or use global `Chirp` calls or the root-backed `chirp` extension for package-internal messages.

```dart
// inventory.dart, exported by the package's public library.
import 'package:chirp/chirp.dart';

final inventoryLogger = ChirpLogger(name: 'inventory');

void refreshInventory() {
  inventoryLogger.debug('Refreshing inventory');
}
```

The host application selects its Flutter or backend setup above, then adopts the package logger:

```dart
import 'package:chirp/chirp.dart';

import 'inventory.dart';

void main() {
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: JsonLogFormatter(),
  );
  Chirp.root.adopt(inventoryLogger);
  refreshInventory();
}
```

Here `inventory.dart` is the preceding example file; in a consuming app, import the package's public library instead.
Adoption connects the package logger to the host's writers, context, and inherited minimum level.
Avoid setting a package-specific minimum level unless the package intentionally needs to override the host's threshold.

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
