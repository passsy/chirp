# Logging Architecture Research: Logger, Formatter, and Writer/Handler Relationships

This document analyzes how popular logging libraries across different programming languages handle the relationship between loggers, formatters/formats, and writers/handlers/appenders.

## Table of Contents

1. [Python](#python)
   - [logging (stdlib)](#python-logging-stdlib)
   - [loguru](#loguru)
   - [structlog](#structlog)
2. [Java](#java)
   - [SLF4J](#slf4j)
   - [Log4j](#log4j)
   - [Logback](#logback)
3. [JavaScript/TypeScript](#javascripttypescript)
   - [winston](#winston)
   - [pino](#pino)
   - [bunyan](#bunyan)
4. [Go](#go)
   - [zap](#zap)
   - [logrus](#logrus)
   - [zerolog](#zerolog)
5. [Rust](#rust)
   - [tracing](#tracing)
   - [log + env_logger](#log--env_logger)
   - [slog](#slog)
6. [C#/.NET](#cnet)
   - [Serilog](#serilog)
   - [NLog](#nlog)
   - [log4net](#log4net)
7. [Ruby](#ruby)
   - [Logger (stdlib)](#ruby-logger-stdlib)
   - [Lograge](#lograge)
   - [Semantic Logger](#semantic-logger)
8. [Summary of Patterns](#summary-of-patterns)

---

## Python

### Python logging (stdlib)

**Architecture Pattern:** Handler-owns-Formatter

**Components:**
- **Logger**: Entry point for application logging
- **Handler**: Dispatches log records to destinations
- **Formatter**: Serializes LogRecord to string
- **Filter**: Fine-grained filtering control
- **LogRecord**: Data structure passed between components

**Relationships:**
```
Logger (creates LogRecord)
  ├─> Handler 1 (owns Formatter 1)
  ├─> Handler 2 (owns Formatter 2)
  └─> Handler N (owns Formatter N)
```

**Data Flow:**
1. Logger creates a `LogRecord` (structured dict-like object with fields: levelno, levelname, pathname, lineno, msg, args, etc.)
2. LogRecord is passed to all attached Handlers and ancestor Handlers (via propagation)
3. Each Handler passes LogRecord to its Formatter
4. Formatter converts LogRecord to formatted string
5. Handler writes formatted string to destination

**Key Characteristics:**
- **Ownership**: Handlers own Formatters
- **Data Structure**: LogRecord objects (structured) passed to handlers
- **Hierarchical**: Child loggers propagate to parent handlers
- **Configuration**: Handlers are attached to loggers

**Code Example:**
```python
import logging

# Create logger
logger = logging.getLogger('my_app')
logger.setLevel(logging.DEBUG)

# Create handler with its own formatter
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(console_formatter)

# Create file handler with different formatter
file_handler = logging.FileHandler('app.log')
file_handler.setLevel(logging.DEBUG)
file_formatter = logging.Formatter('%(levelname)s:%(name)s:%(message)s')
file_handler.setFormatter(file_formatter)

# Attach handlers to logger
logger.addHandler(console_handler)
logger.addHandler(file_handler)

logger.info('This is a test')
```

**References:**
- https://docs.python.org/3/library/logging.html
- https://docs.python.org/3/howto/logging.html

---

### loguru

**Architecture Pattern:** Sink-owns-Format (simplified unified logger)

**Components:**
- **Logger**: Single pre-configured global logger instance
- **Sink**: Destination for log messages (replaces Handler)
- **Format**: String template or function (configured per-sink)

**Relationships:**
```
Logger (single global instance)
  ├─> Sink 1 (configured with format 1)
  ├─> Sink 2 (configured with format 2)
  └─> Sink N (configured with format N)
```

**Data Flow:**
1. Logger is called (single global instance)
2. Message string with `.record` attribute (containing contextual information) is passed to all sinks
3. Each sink formats the message according to its own format configuration
4. Sink writes to its destination

**Key Characteristics:**
- **Ownership**: Sinks own their format configuration
- **Data Structure**: Formatted string with `.record` attribute (dict with context)
- **Simplification**: One global logger, no hierarchy
- **Configuration**: All-in-one `add()` method combines level, format, and filter

**Code Example:**
```python
from loguru import logger

# Remove default handler
logger.remove()

# Add console sink with custom format
logger.add(
    sys.stderr,
    format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} - {message}",
    level="INFO"
)

# Add file sink with JSON format
logger.add(
    "app.log",
    format="{message}",
    level="DEBUG",
    serialize=True  # JSON format
)

logger.info("Hello World")
```

**References:**
- https://github.com/Delgan/loguru
- https://loguru.readthedocs.io/

---

### structlog

**Architecture Pattern:** Processor-Pipeline

**Components:**
- **Logger**: Entry point (can wrap stdlib or other loggers)
- **Processors**: Chain of callables that transform event dict
- **Formatters/Renderers**: Special processors that produce final output (JSONRenderer, ConsoleRenderer, KeyValueRenderer)
- **Wrapped Logger**: Final destination (e.g., stdlib logging)

**Relationships:**
```
Logger
  ├─> Processor 1 (e.g., add_log_level)
  ├─> Processor 2 (e.g., TimeStamper)
  ├─> Processor 3 (e.g., add context)
  ├─> ...
  ├─> Formatter/Renderer (e.g., JSONRenderer)
  └─> Wrapped Logger (e.g., stdlib logging)
```

**Data Flow:**
1. Logger method called with event and context
2. Event dict created/updated
3. Event dict passed through processor chain (each processor receives logger, method_name, event_dict)
4. Each processor can modify, filter, or add to event dict
5. Formatter/renderer processor converts dict to final format (usually last in chain)
6. Result passed to wrapped logger for output

**Key Characteristics:**
- **Ownership**: Logger owns processor chain; formatters are just special processors
- **Data Structure**: Event dictionary (structured) passed through pipeline
- **Structured**: Preserves type information throughout pipeline
- **Composability**: Processors are composable functions

**Code Example:**
```python
import structlog

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()  # Final formatter
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

log = structlog.get_logger()
log.info("user_action", user_id=42, action="login")
```

**References:**
- https://www.structlog.org/
- https://www.structlog.org/en/stable/processors.html

---

## Java

### SLF4J

**Architecture Pattern:** Facade/Abstraction Layer

**Components:**
- **Logger API**: Interface for logging (org.slf4j.Logger)
- **Binding/Provider**: Runtime bridge to actual implementation
- **Implementation**: Actual logging framework (Logback, Log4j, etc.)

**Relationships:**
```
Application Code
  └─> SLF4J API (Logger interface)
        └─> Binding/Provider (selected at runtime)
              └─> Concrete Implementation (Logback/Log4j/etc.)
                    └─> Appenders/Handlers with Layouts/Formatters
```

**Data Flow:**
1. Application calls SLF4J Logger interface methods
2. SLF4J API delegates to bound implementation (discovered via ServiceLoader in 2.0+)
3. Concrete implementation handles formatting and output

**Key Characteristics:**
- **Ownership**: Implementation-dependent (SLF4J is just a facade)
- **Data Structure**: Implementation-dependent
- **Decoupling**: Compile-time dependency on API, runtime dependency on implementation
- **Pluggability**: Switch implementations by changing classpath

**Code Example:**
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class MyApp {
    private static final Logger logger = LoggerFactory.getLogger(MyApp.class);

    public void doSomething() {
        logger.info("Processing user {}", userId);
        logger.error("Error occurred", exception);
    }
}
```

**Configuration:** Depends on bound implementation (Logback XML, Log4j properties, etc.)

**References:**
- https://www.slf4j.org/manual.html
- https://www.slf4j.org/

---

### Log4j

**Architecture Pattern:** Appender-owns-Layout

**Components:**
- **Logger**: Entry point for logging, hierarchical
- **Appender**: Output destination
- **Layout**: Formats LogEvent to bytes/string
- **Filter**: Filtering logic
- **LogEvent**: Data structure containing log information

**Relationships:**
```
Logger (hierarchical)
  ├─> Appender 1 (owns Layout 1)
  ├─> Appender 2 (owns Layout 2)
  └─> Appender N (owns Layout N)
```

**Data Flow:**
1. Logger creates LogEvent (structured object)
2. LogEvent passed to Appenders (and inherited appenders)
3. Appender delegates filtering to Filters
4. Appender delegates formatting to Layout
5. Layout encodes LogEvent to byte array
6. Appender writes to destination

**Key Characteristics:**
- **Ownership**: Appenders own Layouts
- **Data Structure**: LogEvent objects (structured)
- **Hierarchical**: Child loggers inherit appenders
- **Performance**: Zero-allocation JSON encoder available

**Code Example:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="%d{HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n"/>
        </Console>
        <File name="File" fileName="app.log">
            <JsonLayout compact="true" eventEol="true"/>
        </File>
    </Appenders>
    <Loggers>
        <Root level="info">
            <AppenderRef ref="Console"/>
            <AppenderRef ref="File"/>
        </Root>
    </Loggers>
</Configuration>
```

```java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class MyApp {
    private static final Logger logger = LogManager.getLogger(MyApp.class);

    public void process() {
        logger.info("Processing started");
        logger.error("Error occurred", exception);
    }
}
```

**References:**
- https://logging.apache.org/log4j/2.x/
- https://www.baeldung.com/log4j2-appenders-layouts-filters

---

### Logback

**Architecture Pattern:** Appender-owns-Encoder

**Components:**
- **Logger**: Entry point, hierarchical (compatible with SLF4J)
- **Appender**: Output destination
- **Encoder**: Transforms event to byte array and writes (replaces Layout in modern versions)
- **Layout**: Legacy formatting (still supported)
- **Pattern**: Template within Encoder/Layout

**Relationships:**
```
Logger (hierarchical, SLF4J compatible)
  ├─> Appender 1 (owns Encoder 1)
  ├─> Appender 2 (owns Encoder 2)
  └─> Appender N (owns Encoder N)
```

**Data Flow:**
1. Logger (via SLF4J interface) creates log event
2. Event passed to Appenders
3. Appender delegates to Encoder
4. Encoder transforms event to byte array using PatternLayout or other formatting
5. Encoder writes to OutputStream
6. Appender manages the output

**Key Characteristics:**
- **Ownership**: Appenders own Encoders (modern) or Layouts (legacy)
- **Data Structure**: Structured log events
- **Evolution**: Moved from Layout to Encoder for better performance
- **Native SLF4J**: Logback implements SLF4J natively with zero overhead

**Code Example:**
```xml
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <appender name="FILE" class="ch.qos.logback.core.FileAppender">
        <file>app.log</file>
        <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
    </appender>

    <root level="debug">
        <appender-ref ref="STDOUT" />
        <appender-ref ref="FILE" />
    </root>
</configuration>
```

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class MyApp {
    private static final Logger logger = LoggerFactory.getLogger(MyApp.class);

    public void execute() {
        logger.info("Execution started");
    }
}
```

**References:**
- https://logback.qos.ch/
- https://www.baeldung.com/logback

---

## JavaScript/TypeScript

### winston

**Architecture Pattern:** Transport-owns-Format (flexible composition)

**Components:**
- **Logger**: Configurable logger instance
- **Transport**: Storage destination (Console, File, HTTP, etc.)
- **Format**: Transformation pipeline for info object
- **Info Object**: Data structure containing level, message, metadata

**Relationships:**
```
Logger (created via createLogger)
  ├─> Format Pipeline (shared or per-logger)
  ├─> Transport 1 (can override format)
  ├─> Transport 2 (can override format)
  └─> Transport N (can override format)
```

**Data Flow:**
1. Logger method called
2. Info object created (minimum: {level, message}, plus metadata)
3. Info object passes through format pipeline (format.combine())
4. Formatted info object sent to each Transport
5. Transport can apply additional formatting
6. Transport writes to destination

**Key Characteristics:**
- **Ownership**: Formats can be at logger level or transport level
- **Data Structure**: Info objects (structured) passed as objectMode streams
- **Flexibility**: Formats are composable via `format.combine()`
- **Decoupling**: Separates levels, formatting, and storage

**Code Example:**
```javascript
const winston = require('winston');
const { createLogger, format, transports } = winston;
const { combine, timestamp, label, printf, json } = format;

// Custom format
const myFormat = printf(({ level, message, label, timestamp }) => {
  return `${timestamp} [${label}] ${level}: ${message}`;
});

const logger = createLogger({
  // Logger-level format (applied to all transports)
  format: combine(
    label({ label: 'my-app' }),
    timestamp(),
    format.errors({ stack: true })
  ),
  transports: [
    // Console transport with custom format
    new transports.Console({
      format: combine(
        myFormat
      )
    }),
    // File transport with JSON format
    new transports.File({
      filename: 'app.log',
      format: json()
    })
  ]
});

logger.info('Application started', { userId: 123 });
```

**References:**
- https://github.com/winstonjs/winston
- https://betterstack.com/community/guides/logging/how-to-install-setup-and-use-winston-and-morgan-to-log-node-js-applications/

---

### pino

**Architecture Pattern:** Stream-based with Separate Workers

**Components:**
- **Logger**: Entry point for logging
- **Serializers**: Transform specific properties when present
- **Formatters**: Transform entire log object structure
- **Destination/Stream**: Output destination (can be worker thread)
- **Transports**: Format/process logs in worker threads

**Relationships:**
```
Logger
  ├─> Serializers (transform specific fields if present)
  ├─> Formatters (transform entire log structure)
  └─> Destination/Stream
        └─> Transport (worker thread, optional)
```

**Data Flow:**
1. Logger method called
2. Serializers applied to matching properties (if present in log object)
3. Formatters applied to entire log object (always processed)
4. JSON serialization (highly optimized)
5. Written to Destination stream
6. Optional: Transport in worker thread processes/forwards logs

**Key Characteristics:**
- **Ownership**: Logger owns serializers and formatters
- **Data Structure**: JSON objects (optimized serialization)
- **Performance**: Asynchronous, worker-thread-based transports
- **Separation**: Serializers (specific fields) vs Formatters (entire object)

**Code Example:**
```javascript
const pino = require('pino');

// Serializers for specific fields
const logger = pino({
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      headers: req.headers
    }),
    err: pino.stdSerializers.err
  },
  // Formatters for overall structure
  formatters: {
    level: (label) => {
      return { level: label };
    },
    bindings: (bindings) => {
      return { pid: bindings.pid, host: bindings.hostname };
    },
    log: (object) => {
      // Transform entire log object
      return object;
    }
  }
});

// Using transport (worker thread)
const transport = pino.transport({
  target: 'pino-pretty',
  options: { colorize: true }
});

const prettyLogger = pino(transport);

logger.info({ req }, 'Request received');
```

**References:**
- https://github.com/pinojs/pino
- https://signoz.io/guides/pino-logger/

---

### bunyan

**Architecture Pattern:** Stream-based with Serializers

**Components:**
- **Logger**: Entry point (can have multiple instances)
- **Stream**: Output destination (similar to appender)
- **Serializer**: Function to transform specific fields
- **Log Record**: JSON object

**Relationships:**
```
Logger
  ├─> Serializers (transform specific top-level fields)
  ├─> Stream 1 (destination + level)
  ├─> Stream 2 (destination + level)
  └─> Stream N (destination + level)
```

**Data Flow:**
1. Logger method called
2. Log record object created (JSON)
3. Serializers applied to matching top-level fields
4. Additional fields added automatically (pid, hostname, time, v)
5. Record written to each Stream based on level
6. Each Stream writes to its destination (file, stdout, etc.)

**Key Characteristics:**
- **Ownership**: Logger owns Serializers; Streams are output destinations
- **Data Structure**: JSON objects (always)
- **Simplicity**: No separate formatter concept - always JSON
- **Stream-based**: Uses Node.js Writable Stream interface

**Code Example:**
```javascript
const bunyan = require('bunyan');

const logger = bunyan.createLogger({
  name: 'myapp',
  // Serializers for specific fields
  serializers: {
    req: bunyan.stdSerializers.req,
    res: bunyan.stdSerializers.res,
    err: bunyan.stdSerializers.err
  },
  // Multiple streams with different levels
  streams: [
    {
      level: 'debug',
      stream: process.stdout
    },
    {
      level: 'trace',
      path: 'app.log'
    }
  ]
});

logger.info({ req }, 'Request started');
logger.error({ err }, 'Error occurred');
```

**CLI for human-readable output:**
```bash
node app.js | bunyan  # Pretty-prints JSON logs
```

**References:**
- https://github.com/trentm/node-bunyan
- https://nodejs.org/en/blog/module/service-logging-in-json-with-bunyan

---

## Go

### zap

**Architecture Pattern:** Core composition (Encoder + WriteSyncer + LevelEnabler)

**Components:**
- **Logger**: Entry point for logging
- **Core**: Combines Encoder, WriteSyncer, and LevelEnabler
- **Encoder**: Formats log entries (JSON or Console)
- **WriteSyncer**: Output destination (io.Writer with Sync)
- **LevelEnabler**: Determines if level is enabled

**Relationships:**
```
Logger
  └─> Core (or Tee of multiple Cores)
        ├─> Core 1: Encoder + WriteSyncer + LevelEnabler
        ├─> Core 2: Encoder + WriteSyncer + LevelEnabler
        └─> Core N: Encoder + WriteSyncer + LevelEnabler
```

**Data Flow:**
1. Logger method called (e.g., Info, Error)
2. Logger delegates to Core(s)
3. Core checks LevelEnabler
4. If enabled, Core passes structured fields to Encoder
5. Encoder formats to JSON or console format
6. Core writes encoded bytes to WriteSyncer
7. WriteSyncer flushes to destination

**Key Characteristics:**
- **Ownership**: Core owns Encoder, WriteSyncer, and LevelEnabler as composition
- **Data Structure**: Structured fields (type-safe, zero-allocation)
- **Performance**: Reflection-free, zero-allocation design
- **Composition**: Tee combines multiple cores for multi-output

**Code Example:**
```go
package main

import (
    "os"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

func main() {
    // Create encoders
    jsonEncoder := zapcore.NewJSONEncoder(zap.NewProductionEncoderConfig())
    consoleEncoder := zapcore.NewConsoleEncoder(zap.NewDevelopmentEncoderConfig())

    // Create write syncers
    fileWriter, _ := os.Create("app.log")
    fileSync := zapcore.AddSync(fileWriter)
    consoleSync := zapcore.AddSync(os.Stdout)

    // Create cores
    jsonCore := zapcore.NewCore(jsonEncoder, fileSync, zapcore.InfoLevel)
    consoleCore := zapcore.NewCore(consoleEncoder, consoleSync, zapcore.DebugLevel)

    // Combine cores with Tee
    core := zapcore.NewTee(jsonCore, consoleCore)

    // Create logger
    logger := zap.New(core)
    defer logger.Sync()

    logger.Info("Application started",
        zap.String("version", "1.0.0"),
        zap.Int("port", 8080),
    )
}
```

**References:**
- https://github.com/uber-go/zap
- https://pkg.go.dev/go.uber.org/zap/zapcore

---

### logrus

**Architecture Pattern:** Logger-owns-Formatter, Hook-based extensibility

**Components:**
- **Logger**: Entry point with configuration
- **Formatter**: Transforms Entry to bytes (TextFormatter, JSONFormatter)
- **Hook**: Event listeners for log levels
- **Output (io.Writer)**: Destination for formatted output

**Relationships:**
```
Logger
  ├─> Formatter (single, owned by logger)
  ├─> Hooks (multiple, called before formatting)
  └─> Output (io.Writer)
```

**Data Flow:**
1. Logger method called
2. Entry created with log data
3. Hooks fired for matching levels (can modify Entry)
4. Entry passed to Formatter
5. Formatter converts Entry to bytes
6. Bytes written to Output (io.Writer)

**Key Characteristics:**
- **Ownership**: Logger owns single Formatter and multiple Hooks
- **Data Structure**: Entry objects with Fields (map[string]interface{})
- **Hooks**: Called before formatting, can send to external services
- **Single Output**: One io.Writer per logger (can use io.MultiWriter)

**Code Example:**
```go
package main

import (
    "os"
    "github.com/sirupsen/logrus"
)

func main() {
    logger := logrus.New()

    // Set formatter
    logger.SetFormatter(&logrus.JSONFormatter{
        TimestampFormat: "2006-01-02 15:04:05",
        PrettyPrint:     true,
    })

    // Set output
    file, _ := os.Create("app.log")
    logger.SetOutput(file)

    // Add hook
    logger.AddHook(&MyHook{})

    logger.WithFields(logrus.Fields{
        "user_id": 42,
        "action":  "login",
    }).Info("User logged in")
}

// Custom hook
type MyHook struct{}

func (h *MyHook) Levels() []logrus.Level {
    return logrus.AllLevels
}

func (h *MyHook) Fire(entry *logrus.Entry) error {
    // Send to external service, modify entry, etc.
    entry.Data["hostname"] = "myserver"
    return nil
}
```

**References:**
- https://github.com/sirupsen/logrus
- https://pkg.go.dev/github.com/sirupsen/logrus

---

### zerolog

**Architecture Pattern:** Context-based with Writer ownership

**Components:**
- **Logger**: Entry point (created from io.Writer)
- **Context**: Configures contextual fields
- **Event**: Represents single log event (chaining API)
- **Writer**: Output destination (io.Writer)
- **Encoder**: Implicit (JSON by default, CBOR optional)

**Relationships:**
```
Logger (owns io.Writer)
  ├─> Context (static fields)
  └─> Event (per log call)
        └─> Encoder (implicit, determined at compile time)
              └─> Writer
```

**Data Flow:**
1. Logger method called (Info(), Error(), etc.)
2. Event returned for that level
3. Fields added to Event via chaining
4. Msg() or Msgf() called on Event
5. Event encoded to JSON/CBOR (zero allocation)
6. Encoded bytes written to Logger's io.Writer

**Key Characteristics:**
- **Ownership**: Logger owns io.Writer directly
- **Data Structure**: Structured fields (type-safe, chaining API)
- **Performance**: Zero-allocation, no reflection
- **Encoding**: JSON default, CBOR via build tag
- **Simplicity**: No separate formatter concept - encoding is implicit

**Code Example:**
```go
package main

import (
    "os"
    "github.com/rs/zerolog"
    "github.com/rs/zerolog/log"
)

func main() {
    // Create logger with writer
    logger := zerolog.New(os.Stdout).With().Timestamp().Logger()

    // For console output (human-readable)
    consoleWriter := zerolog.ConsoleWriter{Out: os.Stdout}
    logger = zerolog.New(consoleWriter).With().Timestamp().Logger()

    // Multi-writer
    file, _ := os.Create("app.log")
    multi := zerolog.MultiLevelWriter(os.Stdout, file)
    logger = zerolog.New(multi).With().Timestamp().Logger()

    // Static context
    logger = logger.With().
        Str("service", "myapp").
        Int("version", 1).
        Logger()

    // Log with event chaining
    logger.Info().
        Str("user_id", "123").
        Int("status", 200).
        Msg("Request processed")
}
```

**References:**
- https://github.com/rs/zerolog
- https://pkg.go.dev/github.com/rs/zerolog

---

## Rust

### tracing

**Architecture Pattern:** Subscriber with composable Layers

**Components:**
- **Span/Event**: Instrumentation primitives
- **Subscriber**: Trait for collecting trace data
- **Registry**: Subscriber that stores span data and exposes to Layers
- **Layer**: Modular behavior that composes with other Layers
- **Formatter**: Configures how events/spans are formatted (part of fmt Layer)

**Relationships:**
```
Application
  └─> Global Subscriber (set once)
        └─> Registry
              ├─> Layer 1 (e.g., fmt Layer with Formatter)
              ├─> Layer 2 (e.g., filter Layer)
              └─> Layer N (e.g., custom Layer)
```

**Data Flow:**
1. Application creates Span or emits Event
2. Global Subscriber receives the data
3. If using Registry + Layers:
   - Registry stores span context
   - Each Layer receives event/span data
   - fmt Layer formats and writes to output
   - Other Layers can filter, modify, or send elsewhere
4. Layers compose behavior

**Key Characteristics:**
- **Ownership**: Registry owns Layers; fmt Layer owns Formatter
- **Data Structure**: Structured spans and events
- **Composability**: Layers stack together for different behaviors
- **Async-aware**: Designed for async Rust applications

**Code Example:**
```rust
use tracing::{info, span, Level};
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

fn main() {
    // Compose layers
    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env())
        .with(
            fmt::layer()
                .with_target(true)
                .with_thread_ids(true)
                .json()  // Use JSON formatter
        )
        .init();

    let span = span!(Level::INFO, "my_span", user_id = 42);
    let _enter = span.enter();

    info!(action = "login", "User logged in");
}

// Multiple layers example
fn multi_layer() {
    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env())
        .with(fmt::layer().json())  // JSON to stdout
        .with(custom_layer())        // Custom layer
        .init();
}
```

**Formatters available in fmt Layer:**
- Compact format
- Pretty format
- JSON format
- Custom via `FormatEvent` trait

**References:**
- https://github.com/tokio-rs/tracing
- https://docs.rs/tracing-subscriber/

---

### log + env_logger

**Architecture Pattern:** Facade + Builder with Formatter

**Components:**
- **log crate**: Facade providing macros (info!, debug!, etc.)
- **Logger**: Actual implementation (provided by env_logger or others)
- **Builder**: Configuration for env_logger
- **Formatter**: Closure that formats log records

**Relationships:**
```
Application (log macros)
  └─> log facade
        └─> env_logger (or other implementation)
              ├─> Builder (configuration)
              ├─> Formatter (closure)
              └─> Target (stdout/stderr/custom)
```

**Data Flow:**
1. Application calls log macro (info!, error!, etc.)
2. log facade creates Record (structured object)
3. Record passed to global Logger (env_logger)
4. env_logger applies filter
5. Formatter closure receives Formatter (Write impl) and Record
6. Formatter writes formatted text to target

**Key Characteristics:**
- **Ownership**: env_logger Builder owns Formatter
- **Data Structure**: log::Record (structured)
- **Facade**: log crate is just an interface
- **Flexibility**: Different logger implementations can be plugged in

**Code Example:**
```rust
use env_logger::Builder;
use log::{info, error, LevelFilter};
use std::io::Write;

fn main() {
    // Custom formatter
    Builder::new()
        .format(|buf, record| {
            writeln!(
                buf,
                "{} [{}] - {}",
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                record.args()
            )
        })
        .filter(None, LevelFilter::Info)
        .target(env_logger::Target::Stdout)
        .init();

    info!("Application started");
    error!("An error occurred");
}

// With env variable control
fn env_init() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .init();
}
```

**References:**
- https://docs.rs/env_logger/
- https://docs.rs/log/

---

### slog

**Architecture Pattern:** Drain-based with Serializers

**Components:**
- **Logger**: Entry point with context
- **Drain**: Responsible for filtering, formatting, and writing
- **Serializer**: Converts key-value data to output format
- **Formatter**: Specific Drain implementation (e.g., FullFormat, CompactFormat)

**Relationships:**
```
Logger (with context)
  └─> Drain (composable)
        ├─> Filter Drain (optional)
        ├─> Async Drain (optional)
        ├─> Duplicate Drain (optional, for multi-output)
        └─> Format Drain + Serializer
              └─> Writer (stdout, file, etc.)
```

**Data Flow:**
1. Logger method called with key-value pairs
2. Record created with structured data
3. Record passed through Drain chain
4. Filter Drains may drop/modify
5. Format Drain serializes using Serializer
6. Serializer converts to JSON, text, etc.
7. Result written to output

**Key Characteristics:**
- **Ownership**: Logger owns Drain; Drains are composable
- **Data Structure**: Structured key-value pairs with type preservation
- **Composability**: Drains chain together (filter, async, duplicate, format)
- **Type-safe**: Serializers preserve type information

**Code Example:**
```rust
use slog::{Drain, Logger, info, o};
use slog_term::{FullFormat, TermDecorator};
use slog_async::Async;
use slog_json::Json;

fn main() {
    // Terminal output with full format
    let decorator = TermDecorator::new().build();
    let drain = FullFormat::new(decorator).build().fuse();
    let drain = Async::new(drain).build().fuse();
    let logger = Logger::root(drain, o!("version" => "1.0"));

    info!(logger, "Application started"; "user_id" => 42);

    // JSON output
    let json_drain = Json::default(std::io::stdout()).fuse();
    let json_logger = Logger::root(json_drain, o!());

    info!(json_logger, "Event occurred"; "action" => "login");

    // Multiple outputs (duplicate drain)
    let file = std::fs::File::create("app.log").unwrap();
    let file_drain = Json::default(file).fuse();
    let stdout_drain = FullFormat::new(TermDecorator::new().build()).build().fuse();
    let drain = slog::Duplicate::new(file_drain, stdout_drain).fuse();
    let multi_logger = Logger::root(drain, o!());
}
```

**References:**
- https://docs.rs/slog/
- https://github.com/slog-rs/slog

---

## C#/.NET

### Serilog

**Architecture Pattern:** Sink-owns-Formatter (with Enrichers)

**Components:**
- **Logger**: Entry point (created via LoggerConfiguration)
- **Sink**: Output destination
- **Formatter**: Formats log events (OutputTemplate, JSON, etc.)
- **Enricher**: Adds properties to log events

**Relationships:**
```
Logger
  ├─> Enrichers (add properties to events)
  ├─> Sink 1 (owns Formatter 1)
  ├─> Sink 2 (owns Formatter 2)
  └─> Sink N (owns Formatter N)
```

**Data Flow:**
1. Logger method called
2. Log event created (structured)
3. Enrichers add properties to event
4. Structured event sent to each Sink
5. Each Sink formats event using its Formatter
6. Sink writes formatted output to destination

**Key Characteristics:**
- **Ownership**: Sinks own Formatters (OutputTemplate or custom)
- **Data Structure**: Structured log events with properties
- **Enrichment**: Enrichers add contextual data before formatting
- **Flexibility**: Each Sink can have different format

**Code Example:**
```csharp
using Serilog;
using Serilog.Formatting.Json;

class Program
{
    static void Main()
    {
        Log.Logger = new LoggerConfiguration()
            // Enrichers
            .Enrich.FromLogContext()
            .Enrich.WithMachineName()
            .Enrich.WithThreadId()
            // Console sink with template formatter
            .WriteTo.Console(
                outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
            // File sink with JSON formatter
            .WriteTo.File(
                new JsonFormatter(),
                "app.log")
            // Database sink
            .WriteTo.MSSqlServer(
                connectionString: "...",
                tableName: "Logs")
            .CreateLogger();

        Log.Information("Application started at {StartTime}", DateTime.Now);
        Log.Information("Processing user {UserId}", 123);

        Log.CloseAndFlush();
    }
}

// With LogContext enrichment
using (LogContext.PushProperty("RequestId", requestId))
{
    Log.Information("Processing request");  // Will include RequestId
}
```

**References:**
- https://serilog.net/
- https://github.com/serilog/serilog

---

### NLog

**Architecture Pattern:** Target-owns-Layout (with LayoutRenderers)

**Components:**
- **Logger**: Entry point
- **Target**: Output destination
- **Layout**: Formats log events (template-based)
- **LayoutRenderer**: Template variable (${message}, ${date}, etc.)
- **Filter**: Filtering rules

**Relationships:**
```
Logger
  ├─> Target 1 (owns Layout 1)
  │     └─> Layout 1 (contains LayoutRenderers)
  ├─> Target 2 (owns Layout 2)
  │     └─> Layout 2 (contains LayoutRenderers)
  └─> Target N (owns Layout N)
        └─> Layout N (contains LayoutRenderers)
```

**Data Flow:**
1. Logger method called
2. Log event created
3. Event passed to Targets based on rules
4. Target passes event to its Layout
5. Layout processes template with LayoutRenderers
6. LayoutRenderers extract values from event
7. Target writes formatted result to destination

**Key Characteristics:**
- **Ownership**: Targets own Layouts; Layouts contain LayoutRenderers
- **Data Structure**: Structured log events
- **Template-based**: Layouts are strings with ${...} placeholders
- **Hierarchical**: Logger → Target → Layout → LayoutRenderers

**Code Example:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<nlog xmlns="http://www.nlog-project.org/schemas/NLog.xsd">
    <targets>
        <!-- Console target with custom layout -->
        <target name="console"
                xsi:type="Console"
                layout="${longdate}|${level:uppercase=true}|${logger}|${message}${exception:format=tostring}" />

        <!-- File target with JSON layout -->
        <target name="jsonfile"
                xsi:type="File"
                fileName="app.log">
            <layout xsi:type="JsonLayout">
                <attribute name="time" layout="${longdate}" />
                <attribute name="level" layout="${level:upperCase=true}"/>
                <attribute name="message" layout="${message}" />
            </layout>
        </target>

        <!-- Database target -->
        <target name="database" xsi:type="Database" connectionString="...">
            <commandText>
                INSERT INTO Logs (Timestamp, Level, Message)
                VALUES (@timestamp, @level, @message)
            </commandText>
            <parameter name="@timestamp" layout="${date}" />
            <parameter name="@level" layout="${level}" />
            <parameter name="@message" layout="${message}" />
        </target>
    </targets>

    <rules>
        <logger name="*" minlevel="Debug" writeTo="console" />
        <logger name="*" minlevel="Info" writeTo="jsonfile,database" />
    </rules>
</nlog>
```

```csharp
using NLog;

class Program
{
    private static readonly Logger logger = LogManager.GetCurrentClassLogger();

    static void Main()
    {
        logger.Info("Application started");
        logger.Error("An error occurred");
    }
}
```

**References:**
- https://nlog-project.org/
- https://github.com/NLog/NLog

---

### log4net

**Architecture Pattern:** Appender-owns-Layout (Log4j heritage)

**Components:**
- **Logger**: Entry point, hierarchical
- **Appender**: Output destination
- **Layout**: Formats log events
- **Filter**: Controls which events are logged

**Relationships:**
```
Logger (hierarchical)
  ├─> Appender 1 (owns Layout 1, owns Filters)
  ├─> Appender 2 (owns Layout 2, owns Filters)
  └─> Appender N (owns Layout N, owns Filters)
```

**Data Flow:**
1. Logger method called
2. Log event created
3. Event passed to Appenders
4. Filters determine if event should be logged
5. Layout formats the event
6. Appender writes to destination

**Key Characteristics:**
- **Ownership**: Appenders own Layouts
- **Data Structure**: Structured log events
- **Hierarchy**: Similar to Log4j (inherited design)
- **Legacy**: .NET port of Log4j concepts

**Code Example:**
```xml
<?xml version="1.0" encoding="utf-8" ?>
<log4net>
    <appender name="ConsoleAppender" type="log4net.Appender.ConsoleAppender">
        <layout type="log4net.Layout.PatternLayout">
            <conversionPattern value="%date [%thread] %-5level %logger - %message%newline" />
        </layout>
    </appender>

    <appender name="FileAppender" type="log4net.Appender.FileAppender">
        <file value="app.log" />
        <layout type="log4net.Layout.XmlLayout" />
        <filter type="log4net.Filter.LevelRangeFilter">
            <levelMin value="INFO" />
            <levelMax value="FATAL" />
        </filter>
    </appender>

    <root>
        <level value="DEBUG" />
        <appender-ref ref="ConsoleAppender" />
        <appender-ref ref="FileAppender" />
    </root>
</log4net>
```

```csharp
using log4net;

class Program
{
    private static readonly ILog logger = LogManager.GetLogger(typeof(Program));

    static void Main()
    {
        log4net.Config.XmlConfigurator.Configure();

        logger.Info("Application started");
        logger.Error("Error occurred", exception);
    }
}
```

**References:**
- https://logging.apache.org/log4net/
- https://blog.elmah.io/log4net-tutorial-the-complete-guide-for-beginners-and-pros/

---

## Ruby

### Ruby Logger (stdlib)

**Architecture Pattern:** Logger-owns-Formatter

**Components:**
- **Logger**: Entry point and configuration
- **Formatter**: Proc that formats log records
- **LogDevice**: Output destination (file, IO object)

**Relationships:**
```
Logger
  ├─> Formatter (single Proc)
  └─> LogDevice (single destination)
```

**Data Flow:**
1. Logger method called
2. Log data collected (severity, time, progname, message)
3. Formatter Proc called with (severity, time, progname, message)
4. Formatter returns formatted string
5. String written to LogDevice

**Key Characteristics:**
- **Ownership**: Logger owns Formatter and LogDevice
- **Data Structure**: Formatter receives discrete parameters (not a structured object)
- **Simplicity**: Single formatter, single output
- **Customization**: Formatter is a Proc (lambda/block)

**Code Example:**
```ruby
require 'logger'

# Basic usage
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Custom formatter
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{progname}: #{msg}\n"
end

logger.info('MyApp') { "Application started" }
logger.error('MyApp') { "Error occurred" }

# Multiple outputs (use broadcast)
file_logger = Logger.new('app.log')
stdout_logger = Logger.new(STDOUT)

class BroadcastLogger
  def initialize(*loggers)
    @loggers = loggers
  end

  [:debug, :info, :warn, :error, :fatal].each do |method|
    define_method(method) do |*args, &block|
      @loggers.each { |logger| logger.send(method, *args, &block) }
    end
  end
end

logger = BroadcastLogger.new(file_logger, stdout_logger)
logger.info { "Logged to both" }
```

**References:**
- https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html

---

### Lograge

**Architecture Pattern:** Request aggregator with pluggable Formatters

**Components:**
- **Lograge**: Rails integration layer
- **Formatter**: Transforms aggregated request data
- **Output**: Underlying Rails logger

**Relationships:**
```
Rails Request
  └─> Lograge (aggregates request data)
        ├─> Formatter (KeyValue, JSON, Logstash, etc.)
        └─> Rails.logger
```

**Data Flow:**
1. Rails request processed
2. Lograge aggregates request data into single event
3. Event hash passed to Formatter
4. Formatter converts to desired format (JSON, key-value, etc.)
5. Formatted string sent to Rails logger
6. Rails logger outputs (can use custom logger)

**Key Characteristics:**
- **Ownership**: Lograge owns Formatter selection
- **Data Structure**: Hash of request data → formatted string
- **Purpose**: Reduces Rails request logs from many lines to one
- **Formatters**: Pluggable (KeyValue, JSON, Logstash, LTSV, etc.)

**Code Example:**
```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true

  # Choose formatter
  config.lograge.formatter = Lograge::Formatters::Json.new
  # OR
  config.lograge.formatter = Lograge::Formatters::KeyValue.new
  # OR
  config.lograge.formatter = Lograge::Formatters::Logstash.new

  # Custom data
  config.lograge.custom_options = lambda do |event|
    {
      user_id: event.payload[:user_id],
      host: event.payload[:host],
      params: event.payload[:params].except('controller', 'action')
    }
  end

  # Custom logger (optional)
  config.lograge.logger = ActiveSupport::Logger.new(Rails.root.join('log', 'lograge.log'))
end
```

**Output example (JSON formatter):**
```json
{"method":"GET","path":"/users","format":"html","controller":"UsersController","action":"index","status":200,"duration":58.33,"view":40.43,"db":15.26,"user_id":123}
```

**References:**
- https://github.com/roidrage/lograge
- https://www.honeybadger.io/blog/ruby-logger-lograge/

---

### Semantic Logger

**Architecture Pattern:** Processor-queue with Appender-owns-Formatter

**Components:**
- **Logger**: Entry point (hierarchical)
- **Processor**: Background thread with queue
- **Appender**: Output destination
- **Formatter**: Formats log entries (per-appender)

**Relationships:**
```
Logger (hierarchical)
  └─> Processor (background thread + queue)
        ├─> Appender 1 (owns Formatter 1)
        ├─> Appender 2 (owns Formatter 2)
        └─> Appender N (owns Formatter N)
```

**Data Flow:**
1. Logger method called
2. Log struct created
3. Log struct pushed to thread-safe Queue
4. Processor thread pulls from queue
5. Processor sends to each Appender
6. Each Appender formats using its Formatter
7. Appender writes to destination

**Key Characteristics:**
- **Ownership**: Appenders own Formatters
- **Data Structure**: Log struct (structured)
- **Async**: Background processor thread avoids blocking
- **Flexibility**: Multiple appenders with different formats

**Code Example:**
```ruby
require 'semantic_logger'

# Add appenders with formatters
SemanticLogger.add_appender(
  io: STDOUT,
  formatter: :color  # Built-in color formatter
)

SemanticLogger.add_appender(
  file_name: 'app.log',
  formatter: :json   # Built-in JSON formatter
)

# Custom formatter
SemanticLogger.add_appender(
  io: STDERR,
  formatter: ->(log, logger) {
    "#{log.time} #{log.level_to_s} #{log.message}"
  }
)

# Custom formatter class
class MyFormatter < SemanticLogger::Formatters::Default
  def call(log, logger)
    "CUSTOM: #{log.message}"
  end
end

SemanticLogger.add_appender(
  file_name: 'custom.log',
  formatter: MyFormatter.new
)

logger = SemanticLogger['MyApp']
logger.info "Application started", user_id: 123

# Structured logging
logger.info(
  message: "User logged in",
  payload: { user_id: 123, ip: '192.168.1.1' },
  metric: 'user.login'
)
```

**References:**
- https://github.com/reidmorrison/semantic_logger
- https://logger.rocketjob.io/

---

## Summary of Patterns

### Architectural Patterns Observed

| Pattern | Libraries | Ownership | Data Structure |
|---------|-----------|-----------|----------------|
| **Handler-owns-Formatter** | Python logging, Log4j, Logback, log4net | Handler/Appender owns Formatter/Layout/Encoder | Structured objects (LogRecord, LogEvent) |
| **Sink-owns-Format** | loguru, Serilog | Sink owns format configuration | Structured with format applied per-sink |
| **Processor-Pipeline** | structlog, Semantic Logger | Logger owns processor chain; formatters are processors | Structured dict/object through pipeline |
| **Facade** | SLF4J | Implementation-dependent | Implementation-dependent |
| **Transport-owns-Format** | winston | Transports can override logger format | Structured info objects |
| **Stream-based** | pino, bunyan | Logger owns serializers; streams are destinations | JSON objects |
| **Core-Composition** | zap | Core composes Encoder + WriteSyncer | Structured fields |
| **Logger-owns-Formatter** | logrus, Ruby Logger, env_logger | Logger owns single Formatter | Structured Entry/Record |
| **Context-based** | zerolog | Logger owns io.Writer directly | Structured fields with chaining |
| **Layer-Composition** | tracing | Registry owns Layers; fmt Layer owns Formatter | Structured spans/events |
| **Drain-Composition** | slog | Logger owns Drain; Drains are composable | Structured key-values |
| **Target-owns-Layout** | NLog | Target owns Layout with LayoutRenderers | Structured events |
| **Aggregator** | Lograge | Aggregator owns Formatter choice | Hash → formatted string |

### Common Themes

#### 1. **Handler/Writer/Appender/Sink Ownership**
Most mature logging libraries follow a pattern where the **output destination owns the formatter**:
- Python logging: Handler owns Formatter
- Log4j/Logback: Appender owns Layout/Encoder
- Serilog/log4net/NLog: Sink/Appender/Target owns Formatter/Layout
- winston: Transport owns Format (with override capability)
- Semantic Logger: Appender owns Formatter

**Rationale**: Different destinations often need different formats (e.g., JSON for files, human-readable for console).

#### 2. **Structured Data Flow**
Nearly all modern libraries pass **structured data** (not formatted strings) between components:
- Python: LogRecord objects
- Java: LogEvent objects
- JavaScript: info objects
- Go: Structured fields
- Rust: Events/Records with fields
- .NET: Structured log events
- Ruby: Log structs/hashes

**Rationale**: Preserves type information, enables multiple formatters, and supports structured logging.

#### 3. **Composition Patterns**

**Hierarchical (Inheritance-based)**:
- Python logging (parent-child propagation)
- Log4j/Logback (logger hierarchy)
- Semantic Logger (hierarchical loggers)

**Compositional (Layer/Drain/Core-based)**:
- tracing (Layers compose via Registry)
- slog (Drains chain together)
- zap (Cores compose via Tee)
- structlog (Processor pipeline)

**Rationale**: Composition provides flexibility for complex logging scenarios (multi-output, filtering, enrichment).

#### 4. **Performance Optimizations**

**Async/Background Processing**:
- pino: Worker threads for transports
- Semantic Logger: Background processor thread
- slog: Async drain wrapper

**Zero-allocation**:
- zap: Reflection-free, zero-allocation
- zerolog: Zero-allocation JSON encoder

**Lazy Evaluation**:
- Most libraries: Message formatting only if level enabled

#### 5. **Facade/Abstraction Layers**
Some ecosystems use logging facades:
- SLF4J (Java): Abstraction over multiple implementations
- log crate (Rust): Facade for logger implementations

**Rationale**: Decouple application code from logging implementation, allow library users to choose their logger.

### Key Architectural Decisions

When designing a logging library, consider:

1. **Who owns the formatter?**
   - Handler/Writer (most common): Allows per-destination formatting
   - Logger: Simpler, but less flexible for multi-output
   - Pipeline: Maximum flexibility, more complex

2. **What data structure flows through the system?**
   - Structured objects (most modern libraries): Preserves information, enables multiple formats
   - Pre-formatted strings (legacy): Simple but inflexible

3. **Single vs. Multiple outputs?**
   - Multiple (most libraries): Core → multiple handlers/sinks
   - Single with composition (Go zap, Rust slog): Explicit multi-output via composition

4. **Synchronous vs. Asynchronous?**
   - Sync (default in most): Simpler, blocking
   - Async (pino, Semantic Logger, slog): Better performance, more complex

5. **Hierarchical vs. Flat?**
   - Hierarchical (Python, Log4j, Semantic Logger): Propagation, inheritance
   - Flat (loguru, zerolog): Simpler, no magic

6. **Configuration approach?**
   - Declarative (XML/JSON/YAML): Log4j, Logback, NLog
   - Programmatic (builder/fluent): Most modern libraries
   - Environment-based (env_logger): Runtime configuration

### Recommendations

For new logging library design:

1. **Use structured data** (not strings) between components
2. **Let handlers/sinks own formatters** for per-destination formatting
3. **Support multiple outputs** from a single logger
4. **Provide composability** (layers, processors, or drains) for complex scenarios
5. **Make async optional** but available for high-performance scenarios
6. **Consider a facade** if the library ecosystem would benefit from abstraction
7. **Optimize hot paths** (level checks, allocation-free where possible)
8. **Support both programmatic and declarative** configuration

---

## References and Further Reading

### Official Documentation

**Python:**
- https://docs.python.org/3/library/logging.html
- https://github.com/Delgan/loguru
- https://www.structlog.org/

**Java:**
- https://www.slf4j.org/
- https://logging.apache.org/log4j/
- https://logback.qos.ch/

**JavaScript:**
- https://github.com/winstonjs/winston
- https://github.com/pinojs/pino
- https://github.com/trentm/node-bunyan

**Go:**
- https://github.com/uber-go/zap
- https://github.com/sirupsen/logrus
- https://github.com/rs/zerolog

**Rust:**
- https://github.com/tokio-rs/tracing
- https://docs.rs/log/
- https://github.com/slog-rs/slog

**C#/.NET:**
- https://serilog.net/
- https://nlog-project.org/
- https://logging.apache.org/log4net/

**Ruby:**
- https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html
- https://github.com/roidrage/lograge
- https://github.com/reidmorrison/semantic_logger

### Articles and Guides

- [Python Logging: An In-Depth Tutorial](https://www.toptal.com/python/in-depth-python-logging)
- [A Complete Guide to Winston Logging in Node.js](https://betterstack.com/community/guides/logging/how-to-install-setup-and-use-winston-and-morgan-to-log-node-js-applications/)
- [A Comprehensive Guide to Zap Logging in Go](https://betterstack.com/community/guides/logging/go/zap/)
- [Custom Logging in Rust Using tracing and tracing-subscriber](https://burgers.io/custom-logging-in-rust-using-tracing)
- [Structured Logging with Serilog in ASP.NET Core](https://codewithmukesh.com/blog/structured-logging-with-serilog-in-aspnet-core/)

---

# Structured Logging Support

Structured logging is the ability to attach key-value pairs, maps, or dictionaries to log messages, making logs machine-readable and easier to query. This document examines structured logging support across popular logging libraries in various programming languages.

## Python

### logging (Standard Library)

**Support**: Partial - via `extra` parameter

**API**:
```python
import logging

logger = logging.getLogger(__name__)
logger.info("User logged in", extra={"user_id": 123, "ip": "192.168.1.1"})
```

**Internal Storage**: Extra fields are added to the `LogRecord` object as attributes.

**Output Format**: Default formatters don't output extra fields. Requires custom formatter:
```python
# Custom formatter needed to show structured data
formatter = logging.Formatter('%(asctime)s - %(message)s - %(user_id)s')
```

**Limitations**:
- Extra fields must be defined in formatter string
- No built-in JSON output
- Easy to accidentally override built-in LogRecord attributes
- Not designed for structured logging from the ground up

**References**: https://docs.python.org/3/library/logging.html

### loguru

**Support**: Yes - via context and structured binding

**API**:
```python
from loguru import logger

# Using bind for persistent context
logger_ctx = logger.bind(user_id=123, request_id="abc-123")
logger_ctx.info("User action performed")

# Inline structured data
logger.info("Payment processed", extra={"amount": 99.99, "currency": "USD"})

# Using serialize for JSON output
logger.add("file.log", serialize=True)
logger.info("Event", user_id=123, action="login")
```

**Internal Storage**: Context variables are stored in a thread-safe manner and merged with log records.

**Output Format**:
- Human-readable by default: `2024-01-10 10:30:45 | INFO | Event | user_id=123 action=login`
- JSON with `serialize=True`: `{"text": "Event", "record": {"extra": {"user_id": 123, "action": "login"}}, ...}`

**Limitations**:
- Serialization format not customizable (predefined JSON structure)
- Extra data goes into nested `record.extra` in JSON

**References**: https://loguru.readthedocs.io/

### structlog

**Support**: Yes - designed specifically for structured logging

**API**:
```python
import structlog

logger = structlog.get_logger()

# Direct key-value pairs
logger.info("user_login", user_id=123, ip="192.168.1.1", successful=True)

# Binding context
logger = logger.bind(request_id="abc-123", user_id=456)
logger.info("request_started")
logger.info("request_completed", duration_ms=250)
```

**Internal Storage**: Events are dictionaries that flow through a processor chain. Each processor can add, remove, or transform fields.

**Output Format**: Highly configurable via processors:
```python
# JSON output
structlog.configure(
    processors=[
        structlog.processors.JSONRenderer()
    ]
)
# Output: {"event": "user_login", "user_id": 123, "ip": "192.168.1.1", "successful": true}

# Key-value output
structlog.configure(
    processors=[
        structlog.processors.KeyValueRenderer()
    ]
)
# Output: event='user_login' user_id=123 ip='192.168.1.1' successful=True
```

**Limitations**:
- Steeper learning curve due to processor chain concept
- Requires explicit configuration for production use

**References**: https://www.structlog.org/

## Java

### Log4j 2

**Support**: Yes - via MapMessage and ThreadContext

**API**:
```java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.message.MapMessage;
import org.apache.logging.log4j.ThreadContext;

Logger logger = LogManager.getLogger();

// Using MapMessage
MapMessage msg = new MapMessage()
    .with("user_id", 123)
    .with("action", "login")
    .with("ip", "192.168.1.1");
logger.info(msg);

// Using ThreadContext (MDC)
ThreadContext.put("request_id", "abc-123");
logger.info("Request processed");
ThreadContext.clearMap();
```

**Internal Storage**:
- MapMessage stores data in a HashMap
- ThreadContext uses ThreadLocal storage

**Output Format**: Configurable via layouts:
```xml
<!-- JSON Layout -->
<JsonLayout compact="true" eventEol="true" properties="true"/>
<!-- Output: {"message":"login","user_id":123,"action":"login","ip":"192.168.1.1"} -->

<!-- Pattern Layout with MDC -->
<PatternLayout pattern="%d %p %c{1.} [%X{request_id}] %m%n"/>
```

**Limitations**:
- MapMessage requires importing and creating message objects
- ThreadContext is thread-local only (issues with async code)
- Complex configuration

**References**: https://logging.apache.org/log4j/2.x/

### Logback

**Support**: Yes - via MDC (Mapped Diagnostic Context) and Markers with structured arguments

**API**:
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import net.logstash.logback.argument.StructuredArguments;

Logger logger = LoggerFactory.getLogger(MyClass.class);

// Using MDC for context
MDC.put("user_id", "123");
MDC.put("request_id", "abc-123");
logger.info("User logged in");
MDC.clear();

// Using logstash encoder's StructuredArguments
import static net.logstash.logback.argument.StructuredArguments.*;
logger.info("Payment processed",
    keyValue("amount", 99.99),
    keyValue("currency", "USD"),
    keyValue("user_id", 123));
```

**Internal Storage**:
- MDC uses ThreadLocal HashMap
- Structured arguments are wrapped objects that implement both structured and string representations

**Output Format**:
```xml
<!-- With logstash-logback-encoder for JSON -->
<encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
<!-- Output: {"@timestamp":"2024-01-10T10:30:45.123Z","message":"Payment processed","amount":99.99,"currency":"USD","user_id":123} -->

<!-- Pattern layout with MDC -->
<pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %X{user_id} - %msg%n</pattern>
```

**Limitations**:
- MDC is thread-local (async issues)
- Best structured logging requires external library (logstash-logback-encoder)
- StructuredArguments appear in message string by default

**References**:
- https://logback.qos.ch/
- https://github.com/logfellow/logstash-logback-encoder

### SLF4J

**Support**: Partial - interface supports fluent API (v2.0+) and MDC

**API**:
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

Logger logger = LoggerFactory.getLogger(MyClass.class);

// Fluent API (SLF4J 2.0+)
logger.atInfo()
      .addKeyValue("user_id", 123)
      .addKeyValue("action", "login")
      .log("User logged in");

// Traditional MDC
MDC.put("request_id", "abc-123");
logger.info("Processing request");
```

**Internal Storage**: Depends on implementation (Logback, Log4j2, etc.). Fluent API builds structured data in a builder object.

**Output Format**: Depends on the underlying implementation and configuration. Structured data output requires compatible backend and formatter.

**Limitations**:
- SLF4J is a facade - actual structured logging depends on implementation
- Fluent API only available in SLF4J 2.0+ (2022)
- Not all backends support fluent API's structured data yet

**References**: https://www.slf4j.org/

## JavaScript/TypeScript

### winston

**Support**: Yes - native structured logging

**API**:
```javascript
const winston = require('winston');

const logger = winston.createLogger({
  format: winston.format.json(),
  transports: [new winston.transports.Console()]
});

// Structured data as second argument
logger.info('User logged in', {
  user_id: 123,
  ip: '192.168.1.1',
  successful: true
});

// Using child loggers for context
const childLogger = logger.child({ request_id: 'abc-123' });
childLogger.info('Request started');
childLogger.info('Request completed', { duration_ms: 250 });
```

**Internal Storage**: Metadata is stored as JavaScript objects that flow through the format pipeline.

**Output Format**:
```javascript
// JSON format
{"level":"info","message":"User logged in","user_id":123,"ip":"192.168.1.1","successful":true}

// Custom format
const customFormat = winston.format.printf(({ level, message, ...metadata }) => {
  return `${level}: ${message} ${JSON.stringify(metadata)}`;
});
```

**Limitations**:
- Message and metadata are separate concepts (can be confusing)
- Format system can be complex to configure

**References**: https://github.com/winstonjs/winston

### pino

**Support**: Yes - optimized for structured JSON logging

**API**:
```javascript
const pino = require('pino');
const logger = pino();

// Structured data as first argument, message as second
logger.info({
  user_id: 123,
  ip: '192.168.1.1',
  successful: true
}, 'User logged in');

// Child loggers for persistent context
const child = logger.child({ request_id: 'abc-123' });
child.info({ endpoint: '/api/users' }, 'Request started');
child.info({ duration_ms: 250 }, 'Request completed');
```

**Internal Storage**: All data stored as flat JSON objects. Optimized for minimal overhead using fast-json-stringify.

**Output Format**: Always JSON (optimized for speed):
```json
{"level":30,"time":1704882645123,"pid":12345,"hostname":"server1","user_id":123,"ip":"192.168.1.1","successful":true,"msg":"User logged in"}
```

**Limitations**:
- JSON-only output (by design for performance)
- Less human-readable for development (use pino-pretty for dev)
- Opinionated structure (level, time, pid, hostname always included)

**References**: https://getpino.io/

### bunyan

**Support**: Yes - JSON-first structured logging

**API**:
```javascript
const bunyan = require('bunyan');
const logger = bunyan.createLogger({ name: 'myapp' });

// Structured data as first argument
logger.info({
  user_id: 123,
  ip: '192.168.1.1',
  successful: true
}, 'User logged in');

// Child loggers for context
const child = logger.child({ request_id: 'abc-123' });
child.info({ endpoint: '/api/users' }, 'Request started');
```

**Internal Storage**: Records are JavaScript objects with required fields (name, hostname, pid, level, msg, time, v).

**Output Format**: Newline-delimited JSON (ndjson):
```json
{"name":"myapp","hostname":"server1","pid":12345,"level":30,"user_id":123,"ip":"192.168.1.1","successful":true,"msg":"User logged in","time":"2024-01-10T10:30:45.123Z","v":0}
```

**Limitations**:
- JSON-only output (use bunyan CLI for pretty-printing)
- Less actively maintained than pino or winston
- Required fields add overhead

**References**: https://github.com/trentm/node-bunyan

## Go

### zap

**Support**: Yes - strongly-typed structured logging

**API**:
```go
import "go.uber.org/zap"

logger, _ := zap.NewProduction()
defer logger.Sync()

// Strongly-typed fields
logger.Info("User logged in",
    zap.Int("user_id", 123),
    zap.String("ip", "192.168.1.1"),
    zap.Bool("successful", true),
)

// With context (sugar logger for easier API)
sugar := logger.Sugar()
sugar.Infow("Payment processed",
    "amount", 99.99,
    "currency", "USD",
    "user_id", 123,
)

// Reusable fields
logger = logger.With(zap.String("request_id", "abc-123"))
logger.Info("Request started")
```

**Internal Storage**: Fields are strongly-typed structs (zap.Field) with optimized encoding to avoid reflection and allocations.

**Output Format**:
```json
// Production encoder (JSON)
{"level":"info","ts":1704882645.123,"caller":"main.go:42","msg":"User logged in","user_id":123,"ip":"192.168.1.1","successful":true}

// Development encoder (console)
2024-01-10T10:30:45.123Z  INFO  main.go:42  User logged in  {"user_id": 123, "ip": "192.168.1.1", "successful": true}
```

**Limitations**:
- Verbose API (need to specify types: zap.Int, zap.String, etc.)
- Sugar logger has some performance overhead
- Learning curve for the two logger types

**References**: https://github.com/uber-go/zap

### logrus

**Support**: Yes - structured logging with fields

**API**:
```go
import "github.com/sirupsen/logrus"

logger := logrus.New()

// Using Fields
logger.WithFields(logrus.Fields{
    "user_id": 123,
    "ip": "192.168.1.1",
    "successful": true,
}).Info("User logged in")

// Chaining context
logger = logger.WithFields(logrus.Fields{
    "request_id": "abc-123",
})
logger.Info("Request started")
logger.WithField("duration_ms", 250).Info("Request completed")
```

**Internal Storage**: Fields stored in map[string]interface{} (uses reflection).

**Output Format**:
```go
// JSON Formatter
logger.SetFormatter(&logrus.JSONFormatter{})
// {"ip":"192.168.1.1","level":"info","msg":"User logged in","successful":true,"time":"2024-01-10T10:30:45Z","user_id":123}

// Text Formatter (default)
logger.SetFormatter(&logrus.TextFormatter{})
// time="2024-01-10T10:30:45Z" level=info msg="User logged in" ip="192.168.1.1" successful=true user_id=123
```

**Limitations**:
- Slower than zap due to reflection and allocations
- No strongly-typed fields
- In maintenance mode (no major new features)

**References**: https://github.com/sirupsen/logrus

### zerolog

**Support**: Yes - zero-allocation structured logging

**API**:
```go
import "github.com/rs/zerolog/log"

// Fluent API
log.Info().
    Int("user_id", 123).
    Str("ip", "192.168.1.1").
    Bool("successful", true).
    Msg("User logged in")

// Context logger
logger := log.With().
    Str("request_id", "abc-123").
    Logger()
logger.Info().Msg("Request started")
logger.Info().Int("duration_ms", 250).Msg("Request completed")

// Disabled log levels have zero allocation
log.Debug().Str("foo", "bar").Msg("Debug message") // No-op if debug disabled
```

**Internal Storage**: Fields are encoded directly to JSON bytes during the fluent API call chain, avoiding intermediate allocations.

**Output Format**: JSON only (optimized for performance):
```json
{"level":"info","user_id":123,"ip":"192.168.1.1","successful":true,"message":"User logged in","time":"2024-01-10T10:30:45Z"}
```

**Limitations**:
- JSON-only output (use console writer for dev)
- Fluent API can be verbose
- Must call Msg() or Msgf() to actually log (easy to forget)

**References**: https://github.com/rs/zerolog

## Rust

### tracing

**Support**: Yes - structured, contextual, async-aware logging

**API**:
```rust
use tracing::{info, info_span};

// Structured fields
info!(
    user_id = 123,
    ip = "192.168.1.1",
    successful = true,
    "User logged in"
);

// Spans for context (async-aware)
let span = info_span!("request", request_id = "abc-123");
let _enter = span.enter();
info!("Request started");
info!(duration_ms = 250, "Request completed");

// Or using instrument macro
#[tracing::instrument]
async fn process_request(request_id: String) {
    info!("Processing");
}
```

**Internal Storage**: Events and spans are collected by subscribers. Fields are stored as strongly-typed key-value pairs with metadata about field names and types.

**Output Format**: Depends on subscriber:
```rust
// With tracing-subscriber JSON formatter
use tracing_subscriber::fmt;
fmt().json().init();
// {"timestamp":"2024-01-10T10:30:45.123Z","level":"INFO","fields":{"message":"User logged in","user_id":123,"ip":"192.168.1.1","successful":true}}

// Human-readable
fmt().init();
// 2024-01-10T10:30:45.123Z  INFO request{request_id="abc-123"}: User logged in user_id=123 ip="192.168.1.1" successful=true
```

**Limitations**:
- Complex ecosystem (tracing vs tracing-subscriber vs tracing-appender)
- Steeper learning curve than simpler loggers
- Requires understanding spans and events

**References**: https://tracing.rs/

### log + env_logger

**Support**: Limited - key-value pairs via log crate 0.4.17+

**API**:
```rust
use log::{info, as_serde};

// Basic structured logging (limited)
info!("User logged in";
    "user_id" => 123,
    "ip" => "192.168.1.1"
);

// Or using third-party crates like slog-scope with log
// Note: env_logger doesn't natively support structured output
```

**Internal Storage**: log crate now supports key-value pairs, but env_logger (the most common consumer) doesn't format them by default.

**Output Format**: env_logger outputs as plain text:
```
[2024-01-10T10:30:45Z INFO  myapp] User logged in
```

**Limitations**:
- log crate is just a facade
- env_logger doesn't support structured output
- Most log consumers don't utilize key-value pairs yet
- Better to use tracing or slog for real structured logging

**References**: https://docs.rs/log/

### slog

**Support**: Yes - strongly-typed structured logging

**API**:
```rust
use slog::{info, o, Drain, Logger};

let drain = slog_json::Json::default(std::io::stderr()).fuse();
let drain = slog_async::Async::new(drain).build().fuse();
let logger = Logger::root(drain, o!());

// Structured fields
info!(logger, "User logged in";
    "user_id" => 123,
    "ip" => "192.168.1.1",
    "successful" => true
);

// Context logger
let logger = logger.new(o!("request_id" => "abc-123"));
info!(logger, "Request started");
info!(logger, "Request completed"; "duration_ms" => 250);
```

**Internal Storage**: Fields are key-value pairs that flow through a drain pipeline. Values are serialized using the Serialize trait.

**Output Format**: Depends on drain:
```json
// JSON drain
{"msg":"User logged in","level":"INFO","ts":"2024-01-10T10:30:45.123Z","user_id":123,"ip":"192.168.1.1","successful":true}

// Terminal drain (colored, formatted)
Jan 10 10:30:45.123 INFO User logged in, user_id: 123, ip: 192.168.1.1, successful: true
```

**Limitations**:
- More complex setup than log/env_logger
- Less ecosystem adoption than tracing
- Drain pipeline concept has learning curve

**References**: https://github.com/slog-rs/slog

## C#/.NET

### Serilog

**Support**: Yes - designed for structured logging

**API**:
```csharp
using Serilog;

var logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateLogger();

// Structured properties via message template
logger.Information("User {UserId} logged in from {IpAddress}", 123, "192.168.1.1");

// Anonymous objects
logger.Information("Payment processed {@Payment}", new {
    Amount = 99.99,
    Currency = "USD",
    UserId = 123
});

// Enrichment for context
logger = logger.ForContext("RequestId", "abc-123");
logger.Information("Request started");

// Using LogContext for ambient context
using (LogContext.PushProperty("RequestId", "abc-123"))
{
    logger.Information("Processing request");
}
```

**Internal Storage**: Properties are extracted from message templates and stored in LogEvent objects. `@` operator destructures objects, `$` stringifies.

**Output Format**:
```csharp
// Console sink (default formatting)
[10:30:45 INF] User 123 logged in from 192.168.1.1

// JSON sink
WriteTo.File(new JsonFormatter(), "log.json")
// {"Timestamp":"2024-01-10T10:30:45.123","Level":"Information","MessageTemplate":"User {UserId} logged in from {IpAddress}","Properties":{"UserId":123,"IpAddress":"192.168.1.1"}}
```

**Limitations**:
- Message template syntax must be learned
- Property names in templates must match parameter order
- Easy to accidentally stringify instead of destructure (@ vs $ vs plain)

**References**: https://serilog.net/

### NLog

**Support**: Yes - structured logging via properties

**API**:
```csharp
using NLog;

var logger = LogManager.GetCurrentClassLogger();

// Structured properties in message template
logger.Info("User {UserId} logged in from {IpAddress}", 123, "192.168.1.1");

// Explicit properties
logger.Info("Payment processed")
    .Property("Amount", 99.99)
    .Property("Currency", "USD")
    .Property("UserId", 123);

// MDC (Mapped Diagnostics Context)
MappedDiagnosticsContext.Set("RequestId", "abc-123");
logger.Info("Processing request");
MappedDiagnosticsContext.Remove("RequestId");

// Scoped context (MDLC - Mapped Diagnostics Logical Context)
using (MappedDiagnosticsLogicalContext.SetScoped("RequestId", "abc-123"))
{
    logger.Info("Request started");
}
```

**Internal Storage**: Properties stored in LogEventInfo object. MDC uses thread-local storage, MDLC uses async-local storage.

**Output Format**:
```xml
<!-- JSON layout -->
<target name="jsonfile" xsi:type="File" fileName="file.json">
  <layout xsi:type="JsonLayout">
    <attribute name="time" layout="${longdate}" />
    <attribute name="level" layout="${level:upperCase=true}"/>
    <attribute name="message" layout="${message}" />
    <attribute name="properties" encode="false">
      <layout type="JsonLayout" includeAllProperties="true" />
    </attribute>
  </layout>
</target>

// Output: {"time":"2024-01-10 10:30:45.1234","level":"INFO","message":"User 123 logged in from 192.168.1.1","properties":{"UserId":123,"IpAddress":"192.168.1.1"}}
```

**Limitations**:
- Configuration can be complex (XML)
- Multiple context types (MDC vs MDLC) can be confusing
- Message template syntax less elegant than Serilog

**References**: https://nlog-project.org/

### log4net

**Support**: Limited - via MDC and custom properties

**API**:
```csharp
using log4net;

var logger = LogManager.GetLogger(typeof(MyClass));

// Basic logging (no direct structured support)
logger.Info("User logged in");

// MDC for context
log4net.ThreadContext.Properties["UserId"] = 123;
log4net.ThreadContext.Properties["IpAddress"] = "192.168.1.1";
logger.Info("User logged in");
log4net.ThreadContext.Properties.Remove("UserId");

// Custom LoggingEvent for structured data
var logEvent = new log4net.Core.LoggingEvent(
    new log4net.Core.LoggingEventData {
        Level = log4net.Core.Level.Info,
        Message = "User logged in",
        Properties = new log4net.Util.PropertiesDictionary {
            ["UserId"] = 123,
            ["IpAddress"] = "192.168.1.1"
        }
    }
);
logger.Logger.Log(logEvent);
```

**Internal Storage**: Properties stored in PropertiesDictionary. ThreadContext uses thread-local storage.

**Output Format**: Requires custom appender for JSON:
```xml
<!-- Using log4net.Ext.Json package -->
<appender name="JsonFileAppender" type="log4net.Appender.FileAppender">
  <file value="log.json" />
  <layout type="log4net.Layout.SerializedLayout, log4net.Ext.Json">
    <renderer type="log4net.ObjectRenderer.JsonDotNetRenderer, log4net.Ext.Json" />
  </layout>
</appender>
```

**Limitations**:
- Not designed for structured logging
- Awkward API for structured data
- Less actively maintained than Serilog/NLog
- Requires external packages for JSON output

**References**: https://logging.apache.org/log4net/

## Ruby

### Logger (Standard Library)

**Support**: No native support - plain text only

**API**:
```ruby
require 'logger'

logger = Logger.new(STDOUT)

# No structured logging - must build strings
logger.info("User logged in") # Plain text only

# Workaround: JSON in message
require 'json'
logger.info(JSON.generate({
  message: "User logged in",
  user_id: 123,
  ip: "192.168.1.1"
}))
```

**Internal Storage**: Only message string and severity are stored.

**Output Format**: Plain text only:
```
I, [2024-01-10T10:30:45.123456 #12345]  INFO -- : User logged in
```

**Limitations**:
- No structured logging support
- Manual JSON serialization required
- No context or MDC support

**References**: https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html

### Lograge

**Support**: Yes - for Rails request logging specifically

**API**:
```ruby
# In Rails config/environments/production.rb
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new

# Custom fields
config.lograge.custom_options = lambda do |event|
  {
    user_id: event.payload[:user_id],
    request_id: event.payload[:request_id]
  }
end

# In controller
logger.info("Custom event", user_id: current_user.id, action: "login")
```

**Internal Storage**: Extracts data from Rails instrumentation events (ActiveSupport::Notifications).

**Output Format**:
```json
{"method":"GET","path":"/users","format":"html","controller":"UsersController","action":"index","status":200,"duration":58.33,"view":40.43,"db":15.26,"user_id":123,"request_id":"abc-123"}
```

**Limitations**:
- Rails-specific (not a general-purpose logger)
- Primarily for request/response logging
- Limited customization outside Rails ecosystem

**References**: https://github.com/roidrage/lograge

### Semantic Logger

**Support**: Yes - comprehensive structured logging

**API**:
```ruby
require 'semantic_logger'

SemanticLogger.default_level = :info
SemanticLogger.add_appender(io: STDOUT, formatter: :json)

logger = SemanticLogger['MyApp']

# Structured payload
logger.info("User logged in",
  user_id: 123,
  ip: "192.168.1.1",
  successful: true
)

# Named tags for context
logger.tagged("RequestID:abc-123") do
  logger.info("Request started")
  logger.info("Request completed", duration_ms: 250)
end

# Named parameters
logger.info(
  message: "Payment processed",
  payload: { amount: 99.99, currency: "USD" },
  metric: "payment/processed"
)
```

**Internal Storage**: Log entries contain message, payload hash, named tags, and metrics. All structured as separate fields.

**Output Format**:
```json
// JSON formatter
{"timestamp":"2024-01-10T10:30:45.123Z","level":"info","name":"MyApp","message":"User logged in","payload":{"user_id":123,"ip":"192.168.1.1","successful":true}}

// Default formatter
2024-01-10 10:30:45.123 I [12345:MyApp] User logged in -- {:user_id=>123, :ip=>"192.168.1.1", :successful=>true}
```

**Limitations**:
- Less widely adopted than standard Logger
- Configuration more complex than simple loggers
- Performance overhead compared to stdlib Logger

**References**: https://logger.rocketjob.io/

## Summary Comparison Table

| Language | Library | Structured Support | API Style | Storage Format | Default Output | Async-Safe | Performance |
|----------|---------|-------------------|-----------|----------------|----------------|------------|-------------|
| **Python** | logging | Partial | `extra={}` | LogRecord attrs | Plain text | Thread-local | Medium |
| | loguru | Yes | `bind()`, kwargs | Thread-safe context | Human/JSON | Yes | Medium |
| | structlog | Yes | kwargs | Dict pipeline | Configurable | Yes | Medium-High |
| **Java** | Log4j 2 | Yes | MapMessage, ThreadContext | HashMap | Configurable | Thread-local | High |
| | Logback | Yes | MDC, StructuredArgs | ThreadLocal map | Plain/JSON* | Thread-local | High |
| | SLF4J | Partial | Fluent API (v2.0+) | Backend-dependent | Backend-dependent | Backend-dependent | Backend-dependent |
| **JS/TS** | winston | Yes | Metadata object | JS Object | JSON | Yes | Medium |
| | pino | Yes | Object-first | Flat JSON | JSON only | Yes | Very High |
| | bunyan | Yes | Object-first | JS Object | JSON only | Yes | High |
| **Go** | zap | Yes | Typed fields | Strongly-typed structs | JSON/Console | Yes | Very High |
| | logrus | Yes | Fields map | map[string]interface{} | JSON/Text | Yes | Medium |
| | zerolog | Yes | Fluent API | Direct JSON encoding | JSON only | Yes | Very High |
| **Rust** | tracing | Yes | Spans + events | Typed key-values | Configurable | Yes (async-aware) | High |
| | log + env_logger | Limited | Key-value pairs | N/A | Plain text | Yes | High |
| | slog | Yes | Typed key-values | Drain pipeline | Configurable | Yes | High |
| **C#/.NET** | Serilog | Yes | Message templates | LogEvent properties | Configurable | Yes (LogContext) | High |
| | NLog | Yes | Templates, Properties | LogEventInfo | Configurable | Yes (MDLC) | High |
| | log4net | Limited | MDC, Properties | PropertiesDictionary | Plain/JSON* | Thread-local | Medium |
| **Ruby** | Logger | No | N/A | N/A | Plain text | Thread-safe | High |
| | Lograge | Yes (Rails) | Event payload | Rails events | JSON | Yes | Medium |
| | Semantic Logger | Yes | Payload hash | Structured fields | JSON/Text | Yes | Medium |

\* Requires additional configuration or external packages

## Key Findings

### Best-in-Class for Structured Logging:
- **Python**: structlog - designed specifically for structured logging with flexible processor pipeline
- **Java**: Log4j 2 with JsonLayout - comprehensive built-in support
- **JavaScript/TypeScript**: pino - optimized for structured JSON with excellent performance
- **Go**: zap - strongly-typed, zero-allocation structured logging
- **Rust**: tracing - async-aware with powerful span context
- **C#/.NET**: Serilog - structured logging as first-class citizen with message templates
- **Ruby**: Semantic Logger - comprehensive structured logging with metrics

### Common Patterns:
1. **Key-Value Pairs**: All modern libraries support attaching key-value data
2. **Context/MDC**: Most provide thread-local or async-local context storage
3. **JSON Output**: Nearly all support JSON formatting for machine parsing
4. **Child Loggers**: Common pattern for maintaining context across multiple log calls
5. **Typed vs Untyped**: Compiled languages (Go, Rust, Java) tend toward typed fields; dynamic languages use maps/dicts

### Performance Considerations:
- **Zero-allocation loggers**: zap (Go), zerolog (Go), pino (JS) optimized for high-throughput
- **Reflection overhead**: logrus (Go), log4net (C#) slower due to reflection
- **Strongly-typed**: Generally faster (zap, tracing) vs reflection-based (logrus, log4net)

### Async Safety:
- **Thread-local issues**: Traditional MDC (Java, older .NET) problematic with async code
- **Async-aware**: Rust's tracing, .NET's MDLC, modern libraries handle async contexts
- **Immutable contexts**: Child loggers (winston, pino, zap.With()) safer for concurrent use

### Adoption Recommendations:
- **New projects**: Choose libraries designed for structured logging (structlog, Serilog, pino, zap, tracing)
- **Legacy systems**: Retrofit with MDC/context features in existing loggers
- **High performance**: Use zero-allocation libraries (zap, zerolog, pino)
- **Development vs Production**: Consider different formatters (human-readable vs JSON)

---

**Document Version:** 2.0  
**Date:** 2025-01-10  
**Author:** Research compiled from official documentation and community resources  

**Changelog:**
- v1.0: Initial research on logger/formatter/writer architecture patterns
- v2.0: Added comprehensive structured logging research section
