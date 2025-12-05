# Elixir Logging Libraries

A comprehensive guide to logging in Elixir, with a focus on colorful console output.

## 1. Built-in Logger (with Colors)

Elixir's built-in Logger supports colorful output by default.

### Key Features
- Built into Elixir core
- Colorized output by default
- Metadata support
- Multiple backends
- Compile-time log level optimization

### Basic Example
```elixir
require Logger

# Basic logging with automatic colors
Logger.debug("Debug message")      # Cyan
Logger.info("Info message")        # Green
Logger.warning("Warning message")  # Yellow
Logger.error("Error message")      # Red

# With metadata
Logger.info("User logged in", user_id: 123, ip: "192.168.1.1")

# With ANSI color option
Logger.info("Custom color message", ansi_color: :blue)
```

### Configuration (config/config.exs)
```elixir
import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id],
  colors: [
    enabled: true,
    debug: :cyan,
    info: :green,
    warn: :yellow,
    error: :red
  ]

# Set log level
config :logger, level: :debug
```

### Custom Colors per Message
```elixir
require Logger

# Use ansi_color option for custom colors
Logger.debug("Debug message", ansi_color: :cyan)
Logger.info("Info message", ansi_color: :green)
Logger.warning("Warning message", ansi_color: :yellow)
Logger.error("Error message", ansi_color: :red)

# Light colors
Logger.info("Light blue", ansi_color: :light_blue)
Logger.info("Light green", ansi_color: :light_green)

# Combine foreground and background
Logger.info("White on red", ansi_color: [:white, :red_background])
```

---

## 2. Manual Color Combination

Combine foreground and background colors manually.

### Example
```elixir
require Logger

defmodule ColorLogger do
  @moduledoc """
  Custom colored logging with combined styles.
  """

  def debug(message) do
    colored_message = IO.ANSI.cyan() <> "🔍 " <> message <> IO.ANSI.reset()
    Logger.debug(colored_message)
  end

  def info(message) do
    colored_message = IO.ANSI.green() <> "ℹ️ " <> message <> IO.ANSI.reset()
    Logger.info(colored_message)
  end

  def success(message) do
    colored_message = IO.ANSI.bright() <> IO.ANSI.green() <> "✅ " <> message <> IO.ANSI.reset()
    Logger.info(colored_message)
  end

  def warning(message) do
    colored_message = IO.ANSI.yellow() <> "⚠️ " <> message <> IO.ANSI.reset()
    Logger.warning(colored_message)
  end

  def error(message) do
    colored_message = IO.ANSI.red() <> "❌ " <> message <> IO.ANSI.reset()
    Logger.error(colored_message)
  end

  def fatal(message) do
    colored_message =
      IO.ANSI.red_background() <>
      IO.ANSI.white() <>
      IO.ANSI.bright() <>
      "💀 " <> message <>
      IO.ANSI.reset()

    Logger.error(colored_message)
  end
end

# Usage
ColorLogger.debug("Loading configuration...")
ColorLogger.info("Server starting on port 4000")
ColorLogger.success("Database connected!")
ColorLogger.warning("High memory usage")
ColorLogger.error("Connection failed")
ColorLogger.fatal("System crash!")
```

---

## 3. Logger_colorful (Erlang Logger Formatter)

**Hex:**
```elixir
# mix.exs
{:logger_colorful, "~> 0.1"}
```

A colorful formatter for Erlang's logger.

### Example
```elixir
# In config/config.exs
config :logger, :default_handler,
  formatter: {:logger_colorful, []}

# Or with options
config :logger, :default_handler,
  formatter: {:logger_colorful, [
    colors: %{
      debug: :cyan,
      info: :green,
      warning: :yellow,
      error: :red
    }
  ]}
```

---

## 4. Log Backend (Carburetor/log)

**Hex:**
```elixir
# mix.exs
{:log, "~> 0.2"}
```

A Logger backend with enhanced filtering and colors.

### Example
```elixir
# Configuration
config :logger,
  backends: [Log.Backend]

config :logger, Log.Backend,
  colors: %{
    debug: IO.ANSI.green(),
    error: [IO.ANSI.red(), IO.ANSI.bright()]
  }
```

---

## 5. IO.ANSI Module (Built-in Colors)

Elixir's built-in ANSI color support.

### Example
```elixir
defmodule ColorPrinter do
  @moduledoc """
  Direct color printing using IO.ANSI.
  """

  # Available colors
  def demo_colors do
    colors = [
      {:black, IO.ANSI.black()},
      {:red, IO.ANSI.red()},
      {:green, IO.ANSI.green()},
      {:yellow, IO.ANSI.yellow()},
      {:blue, IO.ANSI.blue()},
      {:magenta, IO.ANSI.magenta()},
      {:cyan, IO.ANSI.cyan()},
      {:white, IO.ANSI.white()},
      {:light_red, IO.ANSI.light_red()},
      {:light_green, IO.ANSI.light_green()},
      {:light_yellow, IO.ANSI.light_yellow()},
      {:light_blue, IO.ANSI.light_blue()},
      {:light_magenta, IO.ANSI.light_magenta()},
      {:light_cyan, IO.ANSI.light_cyan()}
    ]

    Enum.each(colors, fn {name, code} ->
      IO.puts(code <> "This is #{name}" <> IO.ANSI.reset())
    end)
  end

  # Styled output
  def bold(text), do: IO.ANSI.bright() <> text <> IO.ANSI.reset()
  def italic(text), do: IO.ANSI.italic() <> text <> IO.ANSI.reset()
  def underline(text), do: IO.ANSI.underline() <> text <> IO.ANSI.reset()

  # Background colors
  def on_red(text), do: IO.ANSI.red_background() <> text <> IO.ANSI.reset()
  def on_green(text), do: IO.ANSI.green_background() <> text <> IO.ANSI.reset()

  # Custom logger
  def log_info(msg), do: IO.puts(IO.ANSI.blue() <> "[INFO] #{msg}" <> IO.ANSI.reset())
  def log_error(msg), do: IO.puts(IO.ANSI.red() <> "[ERROR] #{msg}" <> IO.ANSI.reset())
end
```

---

## 6. Custom Colored Logger Module

Build a comprehensive colored logger.

### Example
```elixir
defmodule FancyLogger do
  @moduledoc """
  A fancy colored logger with emojis and formatting.
  """

  require Logger

  @colors %{
    trace: IO.ANSI.light_black(),
    debug: IO.ANSI.cyan(),
    info: IO.ANSI.blue(),
    success: IO.ANSI.green(),
    warning: IO.ANSI.yellow(),
    error: IO.ANSI.red(),
    fatal: IO.ANSI.red_background() <> IO.ANSI.white()
  }

  @emojis %{
    trace: "🔍",
    debug: "🐛",
    info: "ℹ️",
    success: "✅",
    warning: "⚠️",
    error: "❌",
    fatal: "💀"
  }

  def trace(message, metadata \\ []) do
    log(:trace, message, metadata)
  end

  def debug(message, metadata \\ []) do
    log(:debug, message, metadata)
  end

  def info(message, metadata \\ []) do
    log(:info, message, metadata)
  end

  def success(message, metadata \\ []) do
    log(:success, message, metadata)
  end

  def warning(message, metadata \\ []) do
    log(:warning, message, metadata)
  end

  def error(message, metadata \\ []) do
    log(:error, message, metadata)
  end

  def fatal(message, metadata \\ []) do
    log(:fatal, message, metadata)
  end

  defp log(level, message, metadata) do
    color = @colors[level]
    emoji = @emojis[level]
    timestamp = format_timestamp()
    level_str = level |> Atom.to_string() |> String.upcase() |> String.pad_trailing(7)

    meta_str =
      if Enum.empty?(metadata) do
        ""
      else
        " " <> inspect(metadata)
      end

    output =
      color <>
      "[#{timestamp}] #{emoji} [#{level_str}] #{message}#{meta_str}" <>
      IO.ANSI.reset()

    IO.puts(output)
  end

  defp format_timestamp do
    {{_y, _m, _d}, {h, m, s}} = :calendar.local_time()
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s])
    |> IO.iodata_to_binary()
  end

  # Box logging
  def box(message) do
    len = String.length(message)
    border = String.duplicate("═", len + 4)

    IO.puts(IO.ANSI.green() <> "╔#{border}╗")
    IO.puts("║  #{message}  ║")
    IO.puts("╚#{border}╝" <> IO.ANSI.reset())
  end

  # Step logging
  def step(current, total, message) do
    color = IO.ANSI.cyan()
    IO.puts("#{color}[STEP #{current}/#{total}] 📋 #{message}#{IO.ANSI.reset()}")
  end
end

# Usage
FancyLogger.trace("Trace message")
FancyLogger.debug("Loading configuration...")
FancyLogger.info("Server starting on port 4000")
FancyLogger.success("Database connected!")
FancyLogger.warning("High memory usage", memory_mb: 512)
FancyLogger.error("Connection failed", reason: :timeout)
FancyLogger.fatal("System crash!")

FancyLogger.step(1, 3, "Initializing...")
FancyLogger.step(2, 3, "Processing...")
FancyLogger.step(3, 3, "Finalizing...")

FancyLogger.box("Application Ready!")
```

---

## 7. Ink (Pretty Printing)

**Hex:**
```elixir
# mix.exs
{:ink, "~> 1.0"}
```

A pretty printer for Elixir terms with colors.

### Example
```elixir
# Pretty print data structures with colors
Ink.puts(%{user: "alice", items: [1, 2, 3]})

# Colorize specific output
Ink.puts("Error!", color: :red)
Ink.puts("Success!", color: :green)
```

---

## Quick Comparison

| Library | Colors | Built-in | Features | Best For |
|---------|--------|----------|----------|----------|
| Logger | ⭐⭐⭐⭐ | ✅ | Metadata, levels | All apps |
| IO.ANSI | ⭐⭐⭐⭐⭐ | ✅ | Full control | Custom loggers |
| logger_colorful | ⭐⭐⭐⭐ | ❌ | Erlang logger | OTP 21+ |
| Custom | ⭐⭐⭐⭐⭐ | N/A | Full control | Specific needs |

## Recommendation

**For most apps:** Use the **built-in Logger** with color configuration - it's powerful and well-integrated.

**For custom output:** Use **IO.ANSI** to build your own styled logger.

**For maximum control:** Create a **custom logger module** with the patterns shown above.

## Configuration Tips

### Enable Colors in IEx
```elixir
# In .iex.exs
IEx.configure(colors: [enabled: true])
```

### Check Color Support
```elixir
# Check if ANSI is supported
IO.ANSI.enabled?()

# Force enable
Application.put_env(:elixir, :ansi_enabled, true)
```

### Disable Colors
```elixir
# In config
config :logger, :console,
  colors: [enabled: false]

# Or via environment
# export NO_COLOR=1
```

## Sources

- [Elixir Logger Documentation](https://hexdocs.pm/logger/Logger.html)
- [IO.ANSI Documentation](https://hexdocs.pm/elixir/IO.ANSI.html)
- [Logger Colorful (Elixir Forum)](https://elixirforum.com/t/logger-colorful-colouring-formatter-for-the-erlangs-logger/33638)
- [Elixir Streams: Log with Colors](https://www.elixirstreams.com/tips/log-output-with-colors)
