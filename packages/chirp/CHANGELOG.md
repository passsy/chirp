# Chirp Changelog

## Unreleased

- **New** Bundle the `chirp-logging` AI agent skill for consumers to install with `dart run skills@ get --package chirp`.

- **Fix** `SimpleConsoleMessageFormatter` requests caller info again, restoring the missing source location ([#46](https://github.com/passsy/chirp/issues/46))

- **Fix** `RotatingFileReader.tail` lost, repeated or split records when the file was appended to or rotated while it was read.
  It identifies a file by its first 1024 bytes now, like Filebeat and Vector, and reads every file of the log once, in order, also when it was rotated or compressed in between.
  Two files that start with the same bytes can still be taken for one.
  Records written right before a rotation are read from the rotated file, as long as it exists.
  When retention deletes a file with records the tail saw but did not read yet, the gap is a stream error ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** `RotatingFileReader.tail` waits for the rest of an incomplete record or character instead of emitting it in two parts ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** `RotatingFileReader.tail` reports undecodable bytes and broken archives as stream errors and continues behind them ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** `RotatingFileReader` orders rotated files by the time and counter in their names.
  Compressing a file changed its modification time and could move it behind newer files ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** `RotatingFileReader.read` reads a rotated file once while it is compressed, and reads its `.gz` when it is compressed after it was listed ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** `RotatingFileWriter` deletes the oldest rotated files by their names instead of their modification times, counts a file once while it is compressed, and deletes a file only after its compression is done.
  A compressed file keeps the modification time of the original, for `maxAge`.
  It could delete a newer file than intended, and a file deleted during its compression came back as `.gz` ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** `RotatingFileWriter` names rotated files in the order of the rotations, also when the clock goes back: the suffix within one second counts on from the highest one that still exists.
  It reused the name of a deleted or compressed file, which put the files out of order and could overwrite a compressed one ([#52](https://github.com/passsy/chirp/pull/52))

- **Fix** Only files with the extension of the log file count as its rotated files.
  `app.2024-01-01_10-00-00.backup` is no longer read as history of `app.log` or deleted by the retention policy.
  A log file that is itself named `*.gz` is no longer taken for a compressed one ([#52](https://github.com/passsy/chirp/pull/52))

## 0.9.0

- **New** Lazy message construction — pass `() => 'expensive $message'` to any log method.
  The lambda is only called when the log level passes the filter, avoiding unnecessary string allocations.
- **New** Lazy log builders — `traceLazy`, `debugLazy`, `infoLazy`, `noticeLazy`, `successLazy`, `warningLazy`, `errorLazy`, `criticalLazy`, `wtfLazy`, and `logLazy` (with a `level:` argument) — defer the entire log call (message, `data`, `error`, `stackTrace`, `formatOptions`) until the level filter passes.
  Useful when expensive work lives in the structured `data` map, not just the message string.

  ```dart
  Chirp.warningLazy(
    (log) => log('snapshot', data: {'state': renderState()}),
  );
  ```

  Matching `Chirp.*Lazy` static forwarders are exposed on the global logger.
  Caller resolution lands on the `xxxLazy(...)` invocation line, not the inner `(log) => ...` lambda body, so eager and lazy calls report consistent source locations.
  Adds the `ChirpLogFn` typedef for the inner `log` callback.

## 0.8.0

### New Features

- New `LogRecord.wallClock`, always capturing `DateTime.now()` vs. `LogRecord.time` capturing `clock.now()` which can be faked in tests
- New `RotatingFileWriter` to write log files with automatic rotation and optional compression, including a `RotatingFileReader` to consume the log files again.
- **Unified formatter architecture** — Console and file formatters now share a single `ChirpFormatter` base class with `MessageBuffer`, replacing the separate `ConsoleMessageFormatter` / `FileMessageFormatter` hierarchies.
- Wasm support: `RotatingFileWriter` is only available on non-web platforms.
- Add `minLevel` constructor parameter to all writers

### Breaking Changes

- **Breaking** `ConsoleMessageFormatter` is now a deprecated typedef for `ChirpFormatter` — migrate custom formatters to extend `ChirpFormatter` and use `format(LogRecord record, MessageBuffer buffer)` instead of `format(LogRecord record, ConsoleMessageBuffer buffer)`
- **Breaking** `FileMessageFormatter` is now a deprecated typedef for `ChirpFormatter` — migrate custom file formatters to extend `ChirpFormatter` and write to `buffer.file` instead of returning a `String`
- **Breaking** `JsonFileFormatter` removed — use `JsonLogFormatter` instead
- **Breaking** `JsonLogFormatter` (replaces `JsonMessageFormatter`) simplified: removed `includeSourceLocation`, `includeClassAndInstance`, `useUtcTimestamps`, `JsonDataStyle`, `.console()`, and `.file()` constructors. Source location and class/instance info are now always included. Timestamps are always UTC. Data fields are always written at the root level.
- **Deprecated** `JsonMessageFormatter` — use `JsonLogFormatter` instead

## 0.7.0

### New Features

**Structured logging for cloud platforms**

- Add `GcpMessageFormatter` for Google Cloud Platform with automatic Error Reporting, sourceLocation, and trace correlation
- Add `AwsMessageFormatter` for AWS CloudWatch with proper log level mapping
- Add `JsonMessageFormatter` for platform-agnostic JSON output

**Lambda-based APIs for inline customization**

- Add `DelegatedChirpInterceptor` for creating interceptors inline with lambdas
- Add `DelegatedChirpWriter` for creating writers inline with lambdas
- Add `DelegatedConsoleMessageFormatter` for creating formatters inline with lambdas

**New span types for custom formatters**

- Add `DataKey` and `DataValue` spans for individual key/value rendering
- Add `StackFrameInfo.packageRelativePath` for clean, package-relative file paths
- `InlineData` now supports custom separators via `entrySeparatorBuilder` and `keyValueSeparatorBuilder`

**Other additions**

- Add `LogRecord.copyWith()` for easier log record manipulation in interceptors

### Breaking Changes

- Span-related exports moved from `package:chirp/chirp.dart` to `package:chirp/chirp_spans.dart`
  - Affected: `SpanBasedFormatter`, all span classes (`PlainText`, `AnsiStyled`, etc.), `colorForHash`, `ColorSaturation`
  - Migration: Add `import 'package:chirp/chirp_spans.dart';` if using custom formatters

### Bug Fixes

- Fix child logger not inheriting parent's `minLogLevel`
- Fix `Aligned` span ignoring ANSI escape codes in padding calculation
- Fix `StackTraceSpan` adding extra blank line due to trailing newline

### Improvements

- Remove dimmed styling from log messages without level color for better readability

### Deprecations

- Deprecate `RainbowMessageFormatter.metaWidth` (no longer has any effect)

## 0.6.0

- First public release to pub.dev
- Rework of ANSI colors, now with truecolor support and detection
- Interceptors for filtering and manipulation
- `minLogLevel` for fast level based filtering
- Optional `Stacktrace.current` capturing

## 0.5.0

- First working prototype
