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