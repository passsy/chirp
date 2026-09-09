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
Choose the formatter for the reader and destination using the options below.
Logger-level `setMinLogLevel(...)` rejects records before constructing them; a writer's `minLogLevel` only controls that destination.
Choose thresholds based on the application's needs rather than assuming debug logs are disabled by default.

## Choose the formatter for the destination

| Formatter | Use it for | Useful customization |
| --- | --- | --- |
| `RainbowMessageFormatter` | Colorful development output with distinct caller and level colors. | `RainbowFormatOptions` controls caller details, timestamps, and inline or multiline structured data. |
| `CompactChirpMessageFormatter` | Dense, single-line messages with caller location and inline data; errors and stacks follow below. | `timeDisplay` controls timestamps; `spanTransformers` customizes the layout. |
| `SimpleConsoleMessageFormatter` | Detailed text output when inspecting logger, caller, instance, and data together. | Toggle `showCaller`, `showMethod`, `showInstance`, `showLoggerName`, and `showData`. |
| `GcpMessageFormatter` | Google Cloud Logging and Error Reporting. | Set `projectId` for trace correlation and `serviceName`/`serviceVersion` for error reporting. |
| `AwsMessageFormatter` | AWS CloudWatch's level conventions and structured fields. | Enable `includeSourceLocation` when useful. |
| `JsonLogFormatter` | A generic JSON collector without a cloud-specific schema. | Use when the consumer expects Chirp's general JSON record format. |

The text formatters support `spanTransformers` for deeper layout changes; inspect `package:chirp/chirp_spans.dart` when customization beyond their options is requested.
Multiline Rainbow data uses YAML-like formatting; `yaml_formatter.dart` is a helper, not a standalone `YamlFormatter` to instantiate.
A writer chooses where logs go; a formatter chooses their representation.
`DeveloperLogConsoleWriter` strips ANSI colors, so use a console writer when the Rainbow colors themselves are wanted.

## Choose the setup for the project

### Flutter apps

Configure the root before `runApp`.
For colorful console output, use `RainbowMessageFormatter` with multiline data so nested objects are readable while debugging.
For the Flutter DevTools Logging view, choose `DeveloperLogConsoleWriter(formatter: CompactChirpMessageFormatter())` instead; it forwards the level, error, and stack trace to `dart:developer`.
The developer writer requires a debugger connection and does not provide release-build, logcat, or Xcode console output.
Choose writers and log levels explicitly for the app's release logging needs.

```dart
import 'package:chirp/chirp.dart';
import 'package:flutter/material.dart';

void main() {
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: RainbowMessageFormatter(
      options: const RainbowFormatOptions(
        data: DataPresentation.multiline,
        showLocation: true,
      ),
    ),
  );

  Chirp.info('Application started');
  runApp(const MaterialApp(home: Scaffold(body: Text('Ready'))));
}
```

Use `chirp` in widget or service instance methods and `Chirp` in static or top-level code.
Keep Flutter imports in the application; the Chirp package itself does not require Flutter.

### Server-side backends

Use Rainbow or Compact output during local development and select the deployment's collector format in production.
Configure the root once at process startup.
For example, a backend deployed to Google Cloud can select its formatter through a compile-time setting:

```dart
import 'package:chirp/chirp.dart';

void main() {
  const googleCloud = bool.fromEnvironment('GOOGLE_CLOUD');
  Chirp.root = ChirpLogger()
      .setMinLogLevel(ChirpLogLevel.info)
      .addConsoleWriter(
        formatter: googleCloud
            ? GcpMessageFormatter(serviceName: 'orders-api')
            : RainbowMessageFormatter(
                options: const RainbowFormatOptions(
                  data: DataPresentation.multiline,
                ),
              ),
      );
  Chirp.info('Backend configured');
}
```

For AWS, select `AwsMessageFormatter`; retain `JsonLogFormatter` for generic JSON collectors.
Use the HTTP middleware example below to populate request context before the first request log.

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
    formatter: CompactChirpMessageFormatter(),
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

In a Shelf backend, create the child logger in middleware, fill its context, and attach it to the immutable request before emitting the first request log.
Downstream handlers reuse that logger from `request.context`, so they keep the same request metadata without repeating it at each call.
The following example uses `package:shelf/shelf.dart` in the consuming backend; Shelf is not a dependency of Chirp itself.

```dart
import 'package:chirp/chirp.dart';
import 'package:shelf/shelf.dart';

const requestLoggerKey = 'orders.requestLogger';

Middleware requestLogging(ChirpLogger root) {
  var requestNumber = 0;
  return (Handler inner) {
    return (Request request) async {
      final logger = root.child(name: 'HTTP');
      logger.context.addAll({
        'requestId': request.headers['x-request-id'] ??
            'request-${++requestNumber}',
        'method': request.method,
        'path': request.url.path,
      });
      final contextualRequest = request.change(
        context: {requestLoggerKey: logger},
      );

      logger.info('Request received');
      try {
        final response = await inner(contextualRequest);
        logger.info('Request completed', data: {'status': response.statusCode});
        return response;
      } catch (error, stackTrace) {
        logger.error('Request failed', error: error, stackTrace: stackTrace);
        rethrow;
      }
    };
  };
}

Handler ordersHandler(ChirpLogger root) {
  return Pipeline().addMiddleware(requestLogging(root)).addHandler((request) {
    final logger = request.context[requestLoggerKey] as ChirpLogger;
    logger.debug('Loading orders');
    return Response.ok('[]', headers: {'content-type': 'application/json'});
  });
}
```

Install this middleware before downstream components that need the request logger.
All request logs above, including the first one and failures, carry `requestId`, `method`, and `path`.
The fallback counter is scoped to this middleware instance; use the backend's existing request-ID or tracing policy when available.
Awaiting the inner handler keeps asynchronous failures inside the catch block; rethrowing preserves the backend's existing error-response handling.

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
