# Default Console Logging Formats

This document shows the default console output format for each logging library mentioned in the architecture research.

## Python

### Python logging (stdlib)

**Default Console Format:**

```
WARNING:root:This is a warning message
ERROR:root:This is an error message
```

**With basic configuration:**

```
2024-01-10 10:30:45,123 - my_app - INFO - This is a test
```

**Custom format pattern example:**

```python
'%(asctime)s - %(name)s - %(levelname)s - %(message)s'
# Output: 2024-01-10 10:30:45,123 - my_app - INFO - This is a test
```

### loguru

**Default Console Format:**

```
2024-01-10 10:30:45.123 | INFO     | __main__:<module>:1 - Hello World
```

**Custom format example:**

```python
"{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} - {message}"
# Output: 2024-01-10 10:30:45 | INFO | __main__:main:15 - Hello World
```

### structlog

**Default Console Format (ConsoleRenderer):**

```
2024-01-10T10:30:45.123456Z [info     ] user_login                     user_id=123 ip=192.168.1.1
```

**KeyValueRenderer:**

```
event='user_login' user_id=123 ip='192.168.1.1' successful=True
```

## Java

### SLF4J

**Note:** SLF4J is a facade. Format depends on the implementation (Logback, Log4j, etc.)

### Log4j

**Default Console Format (PatternLayout):**

```
10:30:45.123 [main] INFO  com.example.MyApp - Processing started
```

**Pattern example:**

```xml
%d{HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n
# Output: 10:30:45.123 [main] INFO  com.example.MyApp - Processing started
```

### Logback

**Default Console Format:**

```
10:30:45.123 [main] INFO  com.example.MyApp - Execution started
```

**Pattern example:**

```xml
%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n
# Output: 10:30:45.123 [main] INFO  com.example.MyApp - Execution started
```

## JavaScript/TypeScript

### winston

**Default Console Format (simple):**

```
{"level":"info","message":"Application started","userId":123}
```

**Custom printf format:**

```javascript
`${timestamp} [${label}] ${level}: ${message}`
// Output: 2024-01-10T10:30:45.123Z [my-app] info: Application started
```

### pino

**Default Console Format (JSON):**

```json
{"level":30,"time":1704882645123,"pid":12345,"hostname":"server1","msg":"Request received"}
```

**With pino-pretty (development):**

```
[1704882645123] INFO (12345 on server1): Request received
```

### bunyan

**Default Console Format (JSON):**

```json
{"name":"myapp","hostname":"server1","pid":12345,"level":30,"msg":"Request started","time":"2024-01-10T10:30:45.123Z","v":0}
```

**With bunyan CLI (pretty):**

```
[2024-01-10T10:30:45.123Z]  INFO: myapp/12345 on server1: Request started
```

## Go

### zap

**Development Console Format:**

```
2024-01-10T10:30:45.123Z  INFO  main.go:42  Application started  {"version": "1.0.0", "port": 8080}
```

**Production Console Format (JSON):**

```json
{"level":"info","ts":1704882645.123,"caller":"main.go:42","msg":"Application started","version":"1.0.0","port":8080}
```

### logrus

**Default Text Format:**

```
time="2024-01-10T10:30:45Z" level=info msg="User logged in" ip="192.168.1.1" successful=true user_id=123
```

**JSON Format:**

```json
{"ip":"192.168.1.1","level":"info","msg":"User logged in","successful":true,"time":"2024-01-10T10:30:45Z","user_id":123}
```

### zerolog

**Default Console Format (JSON):**

```json
{"level":"info","user_id":123,"ip":"192.168.1.1","successful":true,"message":"User logged in","time":"2024-01-10T10:30:45Z"}
```

**ConsoleWriter (human-readable):**

```
10:30 AM INF User logged in ip=192.168.1.1 successful=true user_id=123
```

## Rust

### tracing

**Default Format (compact):**

```
2024-01-10T10:30:45.123Z  INFO request{request_id="abc-123"}: User logged in user_id=123 ip="192.168.1.1"
```

**Pretty Format:**

```
  2024-01-10T10:30:45.123456Z  INFO request{request_id="abc-123"}: User logged in
    at src/main.rs:42
    in request with request_id="abc-123"

  with user_id: 123
       ip: "192.168.1.1"
```

**JSON Format:**

```json
{"timestamp":"2024-01-10T10:30:45.123Z","level":"INFO","fields":{"message":"User logged in","user_id":123,"ip":"192.168.1.1"}}
```

### log + env_logger

**Default Format:**

```
[2024-01-10T10:30:45Z INFO  myapp] Application started
```

**Custom format example:**

```rust
format: "{} [{}] - {}"
// Output: 2024-01-10 10:30:45 [INFO] - Application started
```

### slog

**Terminal Format (FullFormat):**

```
Jan 10 10:30:45.123 INFO User logged in, user_id: 123, ip: 192.168.1.1, successful: true
```

**JSON Format:**

```json
{"msg":"User logged in","level":"INFO","ts":"2024-01-10T10:30:45.123Z","user_id":123,"ip":"192.168.1.1","successful":true}
```

## C#/.NET

### Serilog

**Default Console Format:**

```
[10:30:45 INF] Application started at 2024-01-10 10:30:45
```

**With template:**

```
[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}
// Output: [10:30:45 INF] Application started at 2024-01-10 10:30:45
```

**Structured properties display:**

```
[10:30:45 INF] User 123 logged in from 192.168.1.1
```

### NLog

**Default Console Format:**

```
2024-01-10 10:30:45.1234|INFO|MyNamespace.Program|Application started
```

**Custom layout example:**

```
${longdate}|${level:uppercase=true}|${logger}|${message}${exception:format=tostring}
// Output: 2024-01-10 10:30:45.1234|INFO|MyNamespace.Program|Application started
```

### log4net

**Default Console Format:**

```
2024-01-10 10:30:45,123 [1] INFO  Program - Application started
```

**Pattern example:**

```
%date [%thread] %-5level %logger - %message%newline
// Output: 2024-01-10 10:30:45,123 [1] INFO  Program - Application started
```

## Ruby

### Logger (stdlib)

**Default Format:**

```
I, [2024-01-10T10:30:45.123456 #12345]  INFO -- : Application started
```

**Format explanation:**

- `I` = Severity (I=INFO, D=DEBUG, W=WARN, E=ERROR, F=FATAL)
- `[timestamp #pid]`
- `SEVERITY`
- `--` (progname separator)
- `:` (message separator)
- message

**Custom format:**

```ruby
proc { |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{progname}: #{msg}\n"
}
# Output: 2024-01-10 10:30:45 [INFO] MyApp: Application started
```

### Lograge

**Default Format (Rails request logging):**

```json
{"method":"GET","path":"/users","format":"html","controller":"UsersController","action":"index","status":200,"duration":58.33,"view":40.43,"db":15.26}
```

**KeyValue format:**

```
method=GET path=/users format=html controller=UsersController action=index status=200 duration=58.33 view=40.43 db=15.26
```

### Semantic Logger

**Default Color Format:**

```
2024-01-10 10:30:45.123 I [12345:MyApp] Application started
```

**Default Format (structured):**

```
2024-01-10 10:30:45.123 I [12345:MyApp] User logged in -- {:user_id=>123, :ip=>"192.168.1.1", :successful=>true}
```

**JSON Format:**

```json
{"timestamp":"2024-01-10T10:30:45.123Z","level":"info","name":"MyApp","message":"User logged in","payload":{"user_id":123,"ip":"192.168.1.1","successful":true}}
```

## Summary: Common Console Format Patterns

### Timestamp Formats

- **ISO 8601**: `2024-01-10T10:30:45.123Z` (tracing, zerolog, pino, bunyan)
- **Human-readable**: `2024-01-10 10:30:45.123` (Python, Serilog, Semantic Logger)
- **Time only**: `10:30:45.123` (Log4j, Logback, NLog)
- **Unix timestamp**: `1704882645.123` (zap production)

### Level Display

- **Uppercase**: `INFO`, `ERROR`, `WARN` (most libraries)
- **Lowercase**: `info`, `error`, `warn` (winston, loguru, zerolog console)
- **Padded**: `INFO `, `ERROR` (for alignment)
- **Short form**: `INF`, `ERR`, `WRN` (Serilog, some Rust formatters)
- **Single letter**: `I`, `E`, `W` (Ruby Logger)

### Component Identification

- **Logger name**: Java packages (`com.example.MyApp`)
- **Module/file**: `main.go:42` (Go)
- **Thread/process**: `[main]`, `pid:12345`
- **Function/line**: `__main__:<module>:1` (loguru)

### Message and Fields Separator

- **Dash separator**: `- message` (Python logging)
- **Colon separator**: `: message` (bunyan CLI, Ruby Logger)
- **Space only**: `message` (most loggers)
- **Key-value pairs**: `key=value key2=value2` (logrus, structlog KeyValue)
- **JSON inline**: `{"key": "value"}` (zap development)
- **Hash notation**: `{:key=>value}` (Ruby)

### Color Support

- **ANSI colors**: loguru, Semantic Logger `:color`, zerolog ConsoleWriter
- **No color by default**: Most production formats use plain text
