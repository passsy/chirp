# Rust Logging Libraries

A comprehensive guide to the most popular logging libraries for Rust, with a focus on colorful console output.

## 1. pretty_env_logger

**Crate:** `pretty_env_logger`
**Install:**
```toml
[dependencies]
pretty_env_logger = "0.5"
log = "0.4"
```

A prettier version of env_logger with colorized output.

### Key Features
- Colorized log levels by default
- Controlled via RUST_LOG environment variable
- Drop-in replacement for env_logger
- Automatic timestamp formatting

### Example
```rust
use log::{debug, error, info, trace, warn};

fn main() {
    pretty_env_logger::init();

    trace!("Trace message");      // Very dim
    debug!("Debug message");      // Dim
    info!("Info message");        // Cyan
    warn!("Warning message");     // Yellow
    error!("Error message");      // Red

    // With structured data
    let user = "alice";
    let count = 42;
    info!("User {} processed {} items", user, count);
}
```

**Run with:**
```bash
RUST_LOG=trace cargo run
RUST_LOG=my_app=debug cargo run
```

---

## 2. env_logger (with Color Feature)

**Crate:** `env_logger`
**Install:**
```toml
[dependencies]
env_logger = "0.11"
log = "0.4"
```

The standard logging implementation with color support.

### Key Features
- Environment variable control (RUST_LOG)
- Customizable formatting
- Color support via termcolor
- Filtering by module path

### Example
```rust
use env_logger::{Builder, Env};
use log::{debug, error, info, warn};

fn main() {
    // Enable colors by default
    Builder::from_env(Env::default().default_filter_or("info"))
        .format_timestamp_secs()
        .init();

    debug!("Debug message");
    info!("Info message");
    warn!("Warning message");
    error!("Error message");
}

// Custom format with colors
fn custom_format() {
    use std::io::Write;

    Builder::new()
        .format(|buf, record| {
            let level_style = buf.default_level_style(record.level());
            writeln!(
                buf,
                "{} [{}] - {}",
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
                level_style.value(record.level()),
                record.args()
            )
        })
        .filter_level(log::LevelFilter::Debug)
        .init();
}
```

---

## 3. tracing + tracing-subscriber

**Crate:** `tracing`, `tracing-subscriber`
**Install:**
```toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["fmt", "env-filter"] }
```

The modern tracing framework for Rust with colorful output.

### Key Features
- Spans and events for structured logging
- Async-aware tracing
- Colored console output
- Integration with tokio and other async runtimes

### Example
```rust
use tracing::{debug, error, info, info_span, warn, Level};
use tracing_subscriber::FmtSubscriber;

fn main() {
    // Colorful subscriber
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::TRACE)
        .with_target(true)
        .with_ansi(true)  // Enable colors
        .pretty()         // Pretty format
        .init();

    // Basic logging
    tracing::trace!("Trace message");
    debug!("Debug message");
    info!("Info message");
    warn!("Warning message");
    error!("Error message");

    // With fields (structured logging)
    info!(user = "alice", items = 42, "Processing request");

    // Spans for context
    let span = info_span!("process_request", user = "alice");
    let _guard = span.enter();

    info!("Starting processing");
    debug!(step = 1, "Step completed");
    info!("Processing complete");
}
```

### With env-filter
```rust
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

fn main() {
    tracing_subscriber::registry()
        .with(fmt::layer().with_ansi(true))
        .with(EnvFilter::from_default_env())
        .init();

    // Control with RUST_LOG=my_app=debug
}
```

---

## 4. fern (Flexible Logging)

**Crate:** `fern`
**Install:**
```toml
[dependencies]
fern = { version = "0.6", features = ["colored"] }
log = "0.4"
colored = "2"
```

A flexible logging configuration library.

### Key Features
- Highly customizable output
- Multiple outputs (console, file, custom)
- Per-module log levels
- Color support via colored feature

### Example
```rust
use fern::colors::{Color, ColoredLevelConfig};
use log::{debug, error, info, warn};

fn setup_logger() -> Result<(), fern::InitError> {
    let colors = ColoredLevelConfig::new()
        .trace(Color::Magenta)
        .debug(Color::Blue)
        .info(Color::Green)
        .warn(Color::Yellow)
        .error(Color::Red);

    fern::Dispatch::new()
        .format(move |out, message, record| {
            out.finish(format_args!(
                "[{} {} {}] {}",
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
                colors.color(record.level()),
                record.target(),
                message
            ))
        })
        .level(log::LevelFilter::Debug)
        .chain(std::io::stdout())
        .apply()?;
    Ok(())
}

fn main() {
    setup_logger().unwrap();

    debug!("Debug message");    // Blue
    info!("Info message");      // Green
    warn!("Warning message");   // Yellow
    error!("Error message");    // Red
}
```

---

## 5. colored (for Custom Loggers)

**Crate:** `colored`
**Install:**
```toml
[dependencies]
colored = "2"
```

A simple library for terminal colors.

### Example
```rust
use colored::*;

fn main() {
    // Simple colored output
    println!("{}", "This is red".red());
    println!("{}", "This is green".green());
    println!("{}", "This is yellow".yellow());
    println!("{}", "This is blue".blue());

    // With styles
    println!("{}", "Bold red".red().bold());
    println!("{}", "Italic blue".blue().italic());
    println!("{}", "Underlined".underline());

    // Background colors
    println!("{}", "White on red".white().on_red());

    // Custom logger
    log_info("Application started");
    log_success("Connected to database");
    log_warn("High memory usage");
    log_error("Connection failed");
}

fn log_info(msg: &str) {
    println!("{} {}", "ℹ INFO:".cyan(), msg);
}

fn log_success(msg: &str) {
    println!("{} {}", "✔ SUCCESS:".green(), msg);
}

fn log_warn(msg: &str) {
    println!("{} {}", "⚠ WARN:".yellow(), msg);
}

fn log_error(msg: &str) {
    println!("{} {}", "✖ ERROR:".red().bold(), msg);
}
```

---

## 6. flexi_logger (Flexible with Colors)

**Crate:** `flexi_logger`
**Install:**
```toml
[dependencies]
flexi_logger = "0.28"
log = "0.4"
```

A flexible and easy-to-configure logger.

### Key Features
- Colored console output
- File rotation
- Multiple output targets
- Runtime reconfiguration

### Example
```rust
use flexi_logger::{colored_default_format, Logger, WriteMode};
use log::{debug, error, info, warn};

fn main() {
    Logger::try_with_str("debug")
        .unwrap()
        .format(colored_default_format)
        .write_mode(WriteMode::Direct)
        .start()
        .unwrap();

    debug!("Debug message");
    info!("Info message");
    warn!("Warning message");
    error!("Error message");
}
```

---

## Quick Comparison

| Library | Colors | Structured | Async | Best For |
|---------|--------|------------|-------|----------|
| pretty_env_logger | ⭐⭐⭐⭐⭐ | ❌ | ❌ | Quick setup |
| env_logger | ⭐⭐⭐⭐ | ❌ | ❌ | Standard apps |
| tracing | ⭐⭐⭐⭐ | ✅ | ✅ | Async apps |
| fern | ⭐⭐⭐⭐⭐ | ❌ | ❌ | Custom configs |
| flexi_logger | ⭐⭐⭐⭐ | ❌ | ❌ | File rotation |

## Recommendation

**For quick development:** Use **pretty_env_logger** - it's the easiest to set up with great colorful output.

**For async applications:** Use **tracing** with **tracing-subscriber** - it's the modern choice for async Rust.

**For custom requirements:** Use **fern** - it provides the most flexibility in configuring colored output.

## Sources

- [pretty_env_logger on crates.io](https://crates.io/crates/pretty_env_logger)
- [env_logger Documentation](https://docs.rs/env_logger/)
- [tracing Documentation](https://docs.rs/tracing/)
- [Rust Cookbook: Logging](https://rust-lang-nursery.github.io/rust-cookbook/development_tools/debugging/config_log.html)
- [GitHub: seanmonstar/pretty-env-logger](https://github.com/seanmonstar/pretty-env-logger)
