# Go Logging Libraries

A comprehensive guide to the most popular logging libraries for Go/Golang, with a focus on colorful console output.

## 1. Zerolog (with Console Writer)

**Install:**
```bash
go get github.com/rs/zerolog
```
**GitHub Stars:** ~10k+

Zerolog is currently the fastest structured logging framework for Go.

### Key Features
- Zero allocation in hot paths
- Human-friendly colorized console output
- JSON structured output for production
- Contextual logging

### Example
```go
package main

import (
    "os"
    "time"

    "github.com/rs/zerolog"
    "github.com/rs/zerolog/log"
)

func main() {
    // Pretty colorized output for development
    log.Logger = log.Output(zerolog.ConsoleWriter{
        Out:        os.Stderr,
        TimeFormat: time.RFC3339,
        NoColor:    false, // Enable colors
    })

    // Basic logging
    log.Trace().Msg("Trace message")
    log.Debug().Msg("Debug message")        // Dim
    log.Info().Msg("Info message")          // Green
    log.Warn().Msg("Warning message")       // Yellow
    log.Error().Msg("Error message")        // Red
    log.Fatal().Msg("Fatal message")        // Red + exits

    // With fields
    log.Info().
        Str("user", "alice").
        Int("items", 42).
        Msg("Processing request")

    // With error
    err := fmt.Errorf("connection failed")
    log.Error().Err(err).Msg("Database error")

    // Contextual logger
    logger := log.With().
        Str("service", "api").
        Str("version", "1.0.0").
        Logger()

    logger.Info().Msg("Service started")
}
```

### Custom Colors
```go
output := zerolog.ConsoleWriter{
    Out:        os.Stderr,
    TimeFormat: time.Kitchen,
    FormatLevel: func(i interface{}) string {
        return strings.ToUpper(fmt.Sprintf("| %-6s|", i))
    },
    FormatMessage: func(i interface{}) string {
        return fmt.Sprintf("***%s***", i)
    },
}
```

---

## 2. Zap (with Development Mode)

**Install:**
```bash
go get go.uber.org/zap
```
**GitHub Stars:** ~22k+

Zap is Uber's high-performance structured logging library.

### Key Features
- Blazing fast performance
- Development and production modes
- Colored output in development mode
- Sugar mode for convenience

### Example
```go
package main

import (
    "go.uber.org/zap"
)

func main() {
    // Development logger with colors
    logger, _ := zap.NewDevelopment()
    defer logger.Sync()

    sugar := logger.Sugar()

    // Basic logging
    sugar.Debug("Debug message")          // Purple/Magenta
    sugar.Info("Info message")            // Blue
    sugar.Warn("Warning message")         // Yellow
    sugar.Error("Error message")          // Red

    // With fields
    sugar.Infow("User logged in",
        "user", "alice",
        "ip", "192.168.1.1",
    )

    // Formatted logging
    sugar.Infof("Processing %d items", 42)

    // Structured logger (faster)
    logger.Info("Structured log",
        zap.String("user", "alice"),
        zap.Int("count", 42),
    )
}
```

### Custom Development Config
```go
config := zap.NewDevelopmentConfig()
config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
logger, _ := config.Build()
```

---

## 3. Logrus (with Colors)

**Install:**
```bash
go get github.com/sirupsen/logrus
```
**GitHub Stars:** ~24k+

Logrus is a structured logger for Go with colorful output (though now in maintenance mode).

### Key Features
- Structured logging
- Multiple formatters
- Hooks for extending functionality
- Colored console output

### Example
```go
package main

import (
    log "github.com/sirupsen/logrus"
)

func main() {
    // Enable colors
    log.SetFormatter(&log.TextFormatter{
        ForceColors:   true,
        FullTimestamp: true,
    })

    // Basic logging
    log.Trace("Trace message")
    log.Debug("Debug message")
    log.Info("Info message")           // Blue
    log.Warn("Warning message")        // Yellow
    log.Error("Error message")         // Red

    // With fields
    log.WithFields(log.Fields{
        "user":  "alice",
        "items": 42,
    }).Info("Processing request")

    // Contextual logger
    logger := log.WithFields(log.Fields{
        "service": "api",
    })
    logger.Info("Service started")
}
```

---

## 4. Charm Log

**Install:**
```bash
go get github.com/charmbracelet/log
```
**GitHub Stars:** ~2k+

Charm Log is a beautiful, customizable logging library from the Charm.sh team.

### Key Features
- Beautiful colorful output by default
- Multiple output formats (text, JSON, Logfmt)
- Compatible with standard library logger
- Highly customizable

### Example
```go
package main

import (
    "os"

    "github.com/charmbracelet/log"
)

func main() {
    // Default logger with beautiful colors
    log.Debug("Debug message")
    log.Info("Info message")
    log.Warn("Warning message")
    log.Error("Error message")

    // With fields
    log.Info("Processing", "user", "alice", "items", 42)

    // Custom logger
    logger := log.NewWithOptions(os.Stderr, log.Options{
        ReportCaller:    true,
        ReportTimestamp: true,
        TimeFormat:      "15:04:05",
        Prefix:          "🚀 ",
    })

    logger.Info("Custom logger message")
    logger.Error("Something went wrong", "error", "connection refused")

    // With emojis in prefix
    successLog := log.NewWithOptions(os.Stdout, log.Options{
        Prefix: "✅ ",
    })
    successLog.Info("Operation completed")

    errorLog := log.NewWithOptions(os.Stderr, log.Options{
        Prefix: "❌ ",
    })
    errorLog.Error("Operation failed")
}
```

---

## 5. Slog (Standard Library - Go 1.21+)

**Install:** Built into Go 1.21+

Slog is the new structured logging package in the Go standard library.

### Key Features
- Part of the standard library
- Structured logging
- Customizable handlers
- Third-party colorful handlers available

### Example
```go
package main

import (
    "log/slog"
    "os"
)

func main() {
    // Text handler (default, no colors)
    logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelDebug,
    }))

    logger.Debug("Debug message")
    logger.Info("Info message")
    logger.Warn("Warning message")
    logger.Error("Error message")

    // With attributes
    logger.Info("User logged in",
        slog.String("user", "alice"),
        slog.Int("port", 8080),
    )

    // With groups
    logger.Info("Request processed",
        slog.Group("request",
            slog.String("method", "GET"),
            slog.String("path", "/api/users"),
        ),
    )
}
```

### With tint (Colorful slog handler)
```bash
go get github.com/lmittmann/tint
```

```go
package main

import (
    "log/slog"
    "os"
    "time"

    "github.com/lmittmann/tint"
)

func main() {
    // Colorful slog handler
    logger := slog.New(tint.NewHandler(os.Stderr, &tint.Options{
        Level:      slog.LevelDebug,
        TimeFormat: time.Kitchen,
    }))

    slog.SetDefault(logger)

    slog.Debug("Debug message")     // Gray
    slog.Info("Info message")       // Default
    slog.Warn("Warning message")    // Yellow
    slog.Error("Error message")     // Red
}
```

---

## 6. Color Package (for Custom Loggers)

**Install:**
```bash
go get github.com/fatih/color
```
**GitHub Stars:** ~7k+

A package for adding colors to your Go programs.

### Example
```go
package main

import (
    "fmt"
    "time"

    "github.com/fatih/color"
)

func main() {
    // Define colors
    info := color.New(color.FgCyan).SprintFunc()
    success := color.New(color.FgGreen).SprintFunc()
    warning := color.New(color.FgYellow).SprintFunc()
    errorC := color.New(color.FgRed).SprintFunc()

    // Simple colored output
    fmt.Println(info("ℹ"), "Info message")
    fmt.Println(success("✔"), "Success message")
    fmt.Println(warning("⚠"), "Warning message")
    fmt.Println(errorC("✖"), "Error message")

    // Bold and background
    bold := color.New(color.Bold, color.FgRed).SprintFunc()
    fmt.Println(bold("Bold red text"))

    bg := color.New(color.FgWhite, color.BgRed).SprintFunc()
    fmt.Println(bg(" CRITICAL "), "Critical error!")
}

// Custom Logger
type ColorLogger struct{}

func (l *ColorLogger) Info(msg string) {
    c := color.New(color.FgCyan)
    c.Printf("[%s] ℹ INFO: %s\n", time.Now().Format("15:04:05"), msg)
}

func (l *ColorLogger) Success(msg string) {
    c := color.New(color.FgGreen)
    c.Printf("[%s] ✔ SUCCESS: %s\n", time.Now().Format("15:04:05"), msg)
}

func (l *ColorLogger) Warn(msg string) {
    c := color.New(color.FgYellow)
    c.Printf("[%s] ⚠ WARN: %s\n", time.Now().Format("15:04:05"), msg)
}

func (l *ColorLogger) Error(msg string) {
    c := color.New(color.FgRed)
    c.Printf("[%s] ✖ ERROR: %s\n", time.Now().Format("15:04:05"), msg)
}
```

---

## Quick Comparison

| Library | Speed | Fancy Output | Structured | Best For |
|---------|-------|--------------|------------|----------|
| Zerolog | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | High-performance |
| Zap | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | High-performance |
| Logrus | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | Legacy projects |
| Charm Log | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | Beautiful CLI |
| Slog | ⭐⭐⭐⭐ | ⭐⭐ | ✅ | Standard lib |

## Recommendation

**For high-performance APIs:** Use **Zerolog** - it's the fastest with great colorful console output.

**For beautiful CLI tools:** Use **Charm Log** - it has the most beautiful default output.

**For new projects:** Consider **Slog** with **tint** - it's the standard library solution with colors.

**For existing projects using Logrus:** Keep using it, but consider migrating to Zerolog or Zap for new code.

## Sources

- [Better Stack: Best Go Logging Libraries](https://betterstack.com/community/guides/logging/best-golang-logging-libraries/)
- [Charm Blog: The Charm Logger](https://charm.land/blog/the-charm-logger/)
- [Keploy: Adding Color to Go Logging](https://keploy.io/blog/technology/adding-colour-to-the-log-output-of-logging-libraries-in-go)
- [Uptrace: Golang Logging Libraries](https://uptrace.dev/blog/golang-logging)
