# Chirp API Gap Analysis

Based on comprehensive research of 21 popular logging libraries across 7 programming languages, this document identifies critical gaps in Chirp's current API.

## Summary: What Users Can't Do Today

### ❌ CRITICAL: No Structured Logging
**Impact**: Users cannot attach contextual key-value data to logs

**Current Limitation:**
```dart
// Can only log plain messages
chirp('User logged in');
chirp('Payment processed');
```

**What Users Need:**
```dart
// Attach structured data for querying/filtering
chirp('User logged in', data: {
  'user_id': 123,
  'ip_address': '192.168.1.1',
  'auth_method': 'oauth',
});

chirp('Payment processed', data: {
  'amount': 99.99,
  'currency': 'USD',
  'user_id': 123,
  'transaction_id': 'tx_abc123',
});
```

**Industry Standard**: 18 out of 21 libraries support this (structlog, Serilog, pino, zap, winston, etc.)

---

### ❌ CRITICAL: No Log Levels
**Impact**: Users cannot filter or prioritize logs

**Current Limitation:**
```dart
// Everything logged at same level
chirp('Debug: cache miss');
chirp('Production error!');  // No way to distinguish severity
```

**What Users Need:**
```dart
debug('Cache miss for key: $key');
info('User logged in');
warn('API rate limit approaching');
error('Payment failed', error: e, stackTrace: st);
```

**Industry Standard**: ALL 21 libraries support log levels

---

### ❌ MAJOR: No Context/Child Loggers
**Impact**: Users must manually repeat context in every log call

**Current Limitation:**
```dart
// Must repeat context manually
chirp('Request started - ID: $requestId');
chirp('Fetching user - ID: $requestId');
chirp('User fetched - ID: $requestId');
```

**What Users Need:**
```dart
// Bind context once, appears in all logs
final requestLogger = logger.withContext({
  'request_id': 'abc-123',
  'user_id': 456,
});

requestLogger.info('Request started');
requestLogger.info('Fetching user');
requestLogger.info('User fetched');

// All logs automatically include request_id and user_id
```

**Industry Standard**: winston.child(), zap.With(), Serilog.ForContext(), tracing spans

---

### ⚠️ ARCHITECTURAL: Writer Doesn't Own Formatter
**Impact**: Can't have different formats per destination

**Current Limitation:**
```dart
// CANNOT do this: Console with colors, File with JSON
Chirp.root = Chirp(
  formatter: ???,  // Can only pick ONE
  writer: MultiChirpMessageWriter([
    ConsoleChirpMessageWriter(),  // Wants colored output
    FileChirpMessageWriter(),     // Wants JSON output
  ]),
);
```

**What Users Need:**
```dart
Chirp.root = Chirp(
  writers: [
    ConsoleWriter(formatter: ColoredFormatter()),
    FileWriter(formatter: JsonFormatter()),
    HttpWriter(formatter: JsonFormatter()),
  ],
);
```

**Industry Standard**: Python logging, Log4j, Logback, Serilog, winston all follow Handler-owns-Formatter pattern

---

## Priority Ranking (User Perspective)

### P0: Structured Logging Support
**Why First**: This is the foundation for modern observability
- Without it, logs can't be queried in log aggregation tools (Datadog, Splunk, ELK)
- Users building production apps NEED this
- Affects API design of everything else

**User Stories:**
1. "As a developer, I want to log user_id with every log so I can filter by user in production"
2. "As an SRE, I want to log request_id so I can trace requests across services"
3. "As a product manager, I want to log feature flags so I can correlate behavior with A/B tests"

---

### P0: Log Levels
**Why Second**: Basic functionality expected in ANY logging library
- Users need to control verbosity in production vs development
- Can't filter noise without levels
- Blocking for production use

**User Stories:**
1. "As a developer, I want debug logs in development but only errors in production"
2. "As an SRE, I want to set log level to ERROR during incidents to reduce noise"
3. "As a tester, I want to enable TRACE level for specific components during debugging"

---

### P1: Fix Writer/Formatter Architecture
**Why Third**: Enables real-world production setups
- Users need colored console for dev, JSON for production
- Different destinations need different formats
- Blocks multi-output scenarios

**User Stories:**
1. "As a developer, I want colorful logs in my terminal during development"
2. "As an SRE, I want JSON logs in files for log aggregation tools"
3. "As a DevOps engineer, I want the SAME logs going to both console (human-readable) and file (JSON) simultaneously"

---

### P1: Context/Child Loggers
**Why Fourth**: Developer experience and clean code
- Reduces boilerplate
- Makes logs more queryable
- Common pattern in all modern libraries

**User Stories:**
1. "As a developer, I want to attach request_id once and have it appear in all logs in that request scope"
2. "As a backend engineer, I want to create a logger per HTTP request with request metadata"
3. "As a mobile dev, I want to bind user_id to logger after authentication"

---

## Proposed Implementation Plan (User-Focused)

### Phase 1: Add Structured Logging (P0)
**Timeline**: Week 1

**User-Facing Changes:**
```dart
// New API - backwards compatible
chirp('User logged in', data: {
  'user_id': 123,
  'method': 'oauth',
});

// LogEntry gains `data` field
class LogEntry {
  final Map<String, dynamic>? data;  // NEW
  // ... existing fields
}
```

**Why This First**:
- Unblocks production use cases
- Foundation for all other features
- Can be added without breaking changes

---

### Phase 2: Add Log Levels (P0)
**Timeline**: Week 2

**User-Facing Changes:**
```dart
// New extension methods
extension ChirpObjectExt on Object {
  void debug(Object? message, {Map<String, dynamic>? data});
  void info(Object? message, {Map<String, dynamic>? data});
  void warn(Object? message, {Map<String, dynamic>? data});
  void error(Object? message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data});
}

// Configure min level
Chirp.root = Chirp(
  minLevel: LogLevel.info,  // Only info and above
);

// Usage
debug('Cache miss');  // Won't appear in production
info('User logged in', data: {'user_id': 123});
error('Payment failed', error: e, stackTrace: st);
```

**Why This Second**:
- Unlocks filtering and production readiness
- Natural companion to structured logging
- Users expect this immediately

---

### Phase 3: Fix Writer/Formatter Architecture (P1)
**Timeline**: Week 3

**User-Facing Changes:**
```dart
// OLD (deprecated but still works)
Chirp.root = Chirp(
  formatter: JsonFormatter(),
  writer: ConsoleWriter(),
);

// NEW (recommended)
Chirp.root = Chirp(
  writers: [
    ConsoleWriter(formatter: ColoredFormatter()),
    FileWriter(
      path: 'app.log',
      formatter: JsonFormatter(),
    ),
  ],
);

// Writers own formatters
abstract class ChirpWriter {
  void write(LogEntry entry);  // Receives LogEntry, not String
}

class ConsoleWriter implements ChirpWriter {
  final ChirpFormatter formatter;

  ConsoleWriter({ChirpFormatter? formatter})
      : formatter = formatter ?? ColoredFormatter();

  @override
  void write(LogEntry entry) {
    final formatted = formatter.format(entry);
    print(formatted);
  }
}
```

**Why This Third**:
- Follows industry best practices
- Enables multi-output with different formats
- Migration path via deprecation

---

### Phase 4: Add Context/Child Loggers (P1)
**Timeline**: Week 4

**User-Facing Changes:**
```dart
// Bind persistent context
final requestLogger = logger.withData({
  'request_id': 'abc-123',
  'user_id': 456,
});

requestLogger.info('Request started');
// Automatically includes request_id and user_id

// Nested contexts merge
final userLogger = requestLogger.withData({
  'session_id': 'sess_xyz',
});

userLogger.info('Action performed');
// Includes request_id, user_id, AND session_id

// Scoped context (for async)
await logger.scoped({'request_id': requestId}, () async {
  info('Processing request');  // Has request_id
  await fetchUser();
  info('Request complete');     // Has request_id
});
```

**Why This Fourth**:
- Huge DX improvement
- Reduces boilerplate
- Makes structured logging actually usable

---

## Breaking Changes vs Backwards Compatibility

### ✅ Can Add Without Breaking:
- Structured logging (`data` parameter)
- Log levels (new methods like `debug()`, `info()`)
- Child loggers (`withData()` method)

### ⚠️ Requires Deprecation Path:
- Writer/Formatter architecture change
  - Keep old API working with deprecation warnings
  - Provide migration guide
  - Remove in v2.0

---

## What Users Are Saying (Hypothetical Feedback)

> "I can't use Chirp in production because I need to log user IDs and request IDs for tracing. Right now I have to manually interpolate them into every log message string, which is error-prone and not queryable in our log aggregation tool."
> — Backend Developer

> "I love the colored output and instance tracking, but I need JSON logs in production. I can't have both console logs for dev and JSON logs for files without switching the entire Chirp.root configuration."
> — DevOps Engineer

> "Every other logging library has log levels. I need to disable debug logs in production but keep errors. This should be table stakes."
> — Mobile Developer

> "I want to create a logger per HTTP request that automatically includes the request ID in every log. Having to pass it manually is tedious and I forget sometimes."
> — Full Stack Developer

---

## Success Metrics

After implementing these changes, users should be able to:

1. ✅ Query production logs by user_id, request_id, or any custom field
2. ✅ Control log verbosity via levels (debug in dev, error in prod)
3. ✅ Send colored logs to console AND JSON logs to file simultaneously
4. ✅ Create request-scoped loggers that auto-include context
5. ✅ Integrate with log aggregation tools (Datadog, Splunk, ELK)
6. ✅ Follow Dart/Flutter best practices (matches other ecosystem libraries)

---

## References

See `logging_architecture_research.md` for detailed analysis of:
- Python: structlog (structured logging leader)
- JavaScript: pino, winston (both support structured data)
- Go: zap (strongly-typed fields), logrus (Fields)
- C#: Serilog (message templates with properties)
- Rust: tracing (spans with structured fields)
- And 16 more libraries across 7 languages

All modern libraries support structured logging and log levels as baseline features.
