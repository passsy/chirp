# R Logging Libraries

A comprehensive guide to the most popular logging libraries for R, with a focus on colorful console output.

## 1. logger (with crayon)

**CRAN:**
```r
install.packages("logger")
install.packages("crayon")  # For colors
```
**GitHub Stars:** ~600+

A modern, flexible logging package inspired by Python's logging and futile.logger.

### Key Features
- Colorized console output via crayon
- Multiple log levels
- Namespace-based loggers
- Various appenders (console, file, cloud)

### Example
```r
library(logger)
library(crayon)

# Basic logging (colors automatic in terminal)
log_trace("Trace message")
log_debug("Debug message")
log_info("Info message")
log_warn("Warning message")
log_error("Error message")
log_fatal("Fatal message")

# Enable debug level
log_threshold(DEBUG)

# With formatting
user <- "alice"
count <- 42
log_info("User {user} processed {count} items")

# Custom colorful formatter
colorful_formatter <- function(level, msg, namespace, .logcall, .topcall, .topenv) {
  color_fn <- switch(level,
    "TRACE" = crayon::silver,
    "DEBUG" = crayon::cyan,
    "INFO" = crayon::green,
    "WARN" = crayon::yellow,
    "ERROR" = crayon::red,
    "FATAL" = function(x) crayon::bold(crayon::red(x)),
    identity
  )
  paste0(color_fn(paste0("[", level, "] ", msg)))
}

log_formatter(colorful_formatter)
log_info("This is colorful!")
```

### Namespace-based Logging
```r
library(logger)

# Create named loggers
log_threshold(DEBUG, namespace = "database")
log_threshold(INFO, namespace = "api")

log_info("Database connected", namespace = "database")
log_debug("Query executed", namespace = "database")
log_info("Request received", namespace = "api")
```

---

## 2. futile.logger

**CRAN:**
```r
install.packages("futile.logger")
```
**GitHub Stars:** ~300+

A logging utility based on log4j.

### Key Features
- Hierarchical logger namespaces
- Multiple appenders
- Pattern layouts
- Package-level logging

### Example
```r
library(futile.logger)

# Set log level
flog.threshold(DEBUG)

# Basic logging
flog.trace("Trace message")
flog.debug("Debug message")
flog.info("Info message")
flog.warn("Warning message")
flog.error("Error message")
flog.fatal("Fatal message")

# With formatting
flog.info("User %s logged in with %d items", "alice", 42)

# Custom layout
flog.layout(layout.format('[~l] ~m'))

# Logger namespaces
flog.threshold(DEBUG, name = "mypackage")
flog.info("Package log", name = "mypackage")
```

### Adding Colors with crayon
```r
library(futile.logger)
library(crayon)

# Custom colored appender
colored_appender <- function(line) {
  level <- regmatches(line, regexpr("\\[(\\w+)\\]", line))
  colored <- switch(level,
    "[DEBUG]" = cyan(line),
    "[INFO]" = green(line),
    "[WARN]" = yellow(line),
    "[ERROR]" = red(line),
    "[FATAL]" = bold(red(line)),
    line
  )
  cat(colored, "\n")
}

flog.appender(colored_appender)
flog.info("Colorful message!")
```

---

## 3. crayon (Terminal Colors)

**CRAN:**
```r
install.packages("crayon")
```

ANSI terminal colors for R.

### Key Features
- Full ANSI color support
- Chainable styles
- 256 colors and RGB support
- Auto-detects color support

### Example
```r
library(crayon)

# Basic colors
cat(red("Red text\n"))
cat(green("Green text\n"))
cat(yellow("Yellow text\n"))
cat(blue("Blue text\n"))
cat(magenta("Magenta text\n"))
cat(cyan("Cyan text\n"))

# Styles
cat(bold("Bold text\n"))
cat(italic("Italic text\n"))
cat(underline("Underlined\n"))

# Combinations
cat(bold(red("Bold red\n")))
cat(bgRed(white("White on red\n")))

# Custom logger function
log_info <- function(msg) cat(blue(paste0("ℹ️ [INFO] ", msg, "\n")))
log_success <- function(msg) cat(green(bold(paste0("✅ [SUCCESS] ", msg, "\n"))))
log_warn <- function(msg) cat(yellow(paste0("⚠️ [WARN] ", msg, "\n")))
log_error <- function(msg) cat(red(bold(paste0("❌ [ERROR] ", msg, "\n"))))

log_info("Processing data...")
log_success("Analysis complete!")
log_warn("Some values missing")
log_error("Failed to save results")

# Check color support
has_color()
num_colors()
```

---

## 4. cli (Command Line Interface Tools)

**CRAN:**
```r
install.packages("cli")
```
**GitHub Stars:** ~500+

Modern CLI tools with beautiful output.

### Key Features
- Semantic output functions
- Progress bars
- Spinners
- Themes and styling

### Example
```r
library(cli)

# Semantic logging
cli_alert_info("Info message")
cli_alert_success("Success message")
cli_alert_warning("Warning message")
cli_alert_danger("Error message")

# Headers
cli_h1("Main Section")
cli_h2("Subsection")

# Bullet lists
cli_ul(c("Item 1", "Item 2", "Item 3"))

# Progress bar
cli_progress_bar("Processing", total = 100)
for (i in 1:100) {
  Sys.sleep(0.01)
  cli_progress_update()
}
cli_progress_done()

# Formatted output
name <- "Alice"
count <- 42
cli_alert_info("User {.val {name}} processed {.val {count}} items")

# Themes
cli_div(theme = list(.alert = list(color = "cyan")))
cli_alert("Custom themed alert")
cli_end()

# Inline styles
cli_text("This is {.strong bold} and {.emph italic}")
cli_text("File: {.file data.csv}")
cli_text("Function: {.fun process_data}")
```

---

## 5. log4r

**CRAN:**
```r
install.packages("log4r")
```

A log4j-style logging package.

### Example
```r
library(log4r)

# Create logger
logger <- logger(threshold = "DEBUG")

# Basic logging
debug(logger, "Debug message")
info(logger, "Info message")
warn(logger, "Warning message")
error(logger, "Error message")
fatal(logger, "Fatal message")

# Custom appender with colors
library(crayon)

colored_console <- function(level, ...) {
  msg <- paste0(...)
  colored <- switch(level,
    "DEBUG" = cyan(msg),
    "INFO" = green(msg),
    "WARN" = yellow(msg),
    "ERROR" = red(msg),
    "FATAL" = bold(red(msg)),
    msg
  )
  cat(colored, "\n")
}

# Use custom appender
custom_logger <- logger(
  threshold = "DEBUG",
  appenders = list(colored_console)
)

info(custom_logger, "Colorful log message")
```

---

## 6. Custom Colorful Logger

Build your own simple colorful logger.

### Example
```r
# Custom color logger
ColorLogger <- function() {
  # ANSI color codes
  RESET <- "\033[0m"
  RED <- "\033[31m"
  GREEN <- "\033[32m"
  YELLOW <- "\033[33m"
  BLUE <- "\033[34m"
  MAGENTA <- "\033[35m"
  CYAN <- "\033[36m"
  BOLD <- "\033[1m"

  timestamp <- function() {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  }

  log_msg <- function(color, level, emoji, msg) {
    cat(sprintf("%s[%s] %s [%s] %s%s\n",
      color, timestamp(), emoji, level, msg, RESET))
  }

  list(
    trace = function(msg) log_msg(MAGENTA, "TRACE", "🔍", msg),
    debug = function(msg) log_msg(CYAN, "DEBUG", "🐛", msg),
    info = function(msg) log_msg(BLUE, "INFO", "ℹ️", msg),
    success = function(msg) log_msg(GREEN, "SUCCESS", "✅", msg),
    warn = function(msg) log_msg(YELLOW, "WARN", "⚠️", msg),
    error = function(msg) log_msg(RED, "ERROR", "❌", msg),
    fatal = function(msg) log_msg(paste0(BOLD, RED), "FATAL", "💀", msg)
  )
}

# Usage
log <- ColorLogger()

log$trace("Trace message")
log$debug("Loading data...")
log$info("Processing started")
log$success("Analysis complete!")
log$warn("Missing values detected")
log$error("Failed to connect")
log$fatal("Critical system failure!")
```

### R6 Class Logger
```r
library(R6)
library(crayon)

Logger <- R6Class("Logger",
  public = list(
    name = NULL,

    initialize = function(name = "APP") {
      self$name <- name
    },

    debug = function(msg) {
      cat(cyan(sprintf("[%s] [DEBUG] [%s] %s\n",
        Sys.time(), self$name, msg)))
    },

    info = function(msg) {
      cat(green(sprintf("[%s] [INFO] [%s] %s\n",
        Sys.time(), self$name, msg)))
    },

    warn = function(msg) {
      cat(yellow(sprintf("[%s] [WARN] [%s] %s\n",
        Sys.time(), self$name, msg)))
    },

    error = function(msg) {
      cat(red(bold(sprintf("[%s] [ERROR] [%s] %s\n",
        Sys.time(), self$name, msg))))
    }
  )
)

# Usage
logger <- Logger$new("MyApp")
logger$debug("Debug message")
logger$info("Info message")
logger$warn("Warning message")
logger$error("Error message")
```

---

## Quick Comparison

| Library | Colors | Features | Best For |
|---------|--------|----------|----------|
| logger | ⭐⭐⭐⭐ | Modern, flexible | General use |
| futile.logger | ⭐⭐⭐ | log4j-style | Java developers |
| crayon | ⭐⭐⭐⭐⭐ | Colors only | Custom loggers |
| cli | ⭐⭐⭐⭐⭐ | Rich output | CLI tools |
| log4r | ⭐⭐⭐ | Simple | Basic logging |

## Recommendation

**For general logging:** Use **logger** with **crayon** - it's modern and flexible.

**For beautiful CLI output:** Use **cli** - it provides semantic output and progress bars.

**For simple color needs:** Use **crayon** directly - build your own logger.

## Sources

- [logger Package Documentation](https://daroczig.github.io/logger/)
- [logger on CRAN](https://cran.r-project.org/web/packages/logger/)
- [futile.logger on CRAN](https://cran.r-project.org/package=futile.logger)
- [crayon on CRAN](https://cran.r-project.org/package=crayon)
- [cli Package](https://cli.r-lib.org/)
