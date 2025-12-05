# Python Logging Libraries

A comprehensive guide to the most popular logging libraries for Python, with a focus on colorful and fancy console output.

## 1. Loguru

**Package:** `loguru`
**GitHub Stars:** ~21k
**Install:** `pip install loguru`

Loguru is the most popular third-party logging framework for Python, designed to make logging painless.

### Key Features
- Zero configuration needed - just import and use
- Automatic colorized output by default
- Automatic file rotation and retention
- Exception catching with traceback
- Supports `NO_COLOR` and `FORCE_COLOR` environment variables

### Example
```python
from loguru import logger

# Basic usage - colors are automatic!
logger.debug("Debug message")       # Blue
logger.info("Info message")         # Default/White
logger.success("Success message")   # Green
logger.warning("Warning message")   # Yellow
logger.error("Error message")       # Red
logger.critical("Critical message") # Red background

# With context
logger.info("User {name} logged in", name="Alice")

# Exception logging with full traceback
try:
    1 / 0
except Exception:
    logger.exception("An error occurred")

# Configure output format
logger.add(
    "app.log",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
    rotation="10 MB",
    retention="10 days"
)

# Custom levels with colors
logger.level("CUSTOM", no=15, color="<magenta><bold>")
logger.log("CUSTOM", "This is a custom level!")
```

---

## 2. Rich

**Package:** `rich`
**GitHub Stars:** ~50k+
**Install:** `pip install rich`

Rich is a Python library for beautiful terminal output, including a powerful logging handler.

### Key Features
- Beautiful, syntax-highlighted tracebacks
- Markdown rendering in terminal
- Progress bars, tables, and panels
- Full emoji support
- Works on Windows, macOS, and Linux

### Example
```python
from rich.console import Console
from rich.logging import RichHandler
import logging

# Setup Rich logging handler
logging.basicConfig(
    level=logging.DEBUG,
    format="%(message)s",
    handlers=[RichHandler(rich_tracebacks=True)]
)

log = logging.getLogger("rich")

log.debug("Debug message with [bold]markup[/bold]")
log.info("Info message")
log.warning("Warning message")
log.error("Error message")
log.critical("Critical message")

# Direct console usage for extra fancy output
console = Console()
console.print("[bold red]Alert![/bold red] Something went wrong")
console.print(":rocket: Deploying...", style="bold green")
console.print("Status: [green]OK[/green] | Errors: [red]0[/red]")

# Beautiful exception tracebacks
try:
    raise ValueError("Something went wrong!")
except Exception:
    console.print_exception(show_locals=True)
```

---

## 3. Structlog

**Package:** `structlog`
**GitHub Stars:** ~3k+
**Install:** `pip install structlog`

Structlog produces structured logs in JSON or human-readable colored format.

### Key Features
- Structured logging with bound context
- Colorized console output for development
- JSON output for production
- Integrates with standard library logging

### Example
```python
import structlog

# Configure for colorful development output
structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.dev.ConsoleRenderer(colors=True)
    ]
)

log = structlog.get_logger()

# Basic logging with colors
log.debug("Debug message")
log.info("Info message")
log.warning("Warning message")
log.error("Error message")

# Structured logging - binds context to all future logs
log = log.bind(user="alice", request_id="abc123")
log.info("Processing request")
log.info("Request completed", status=200)

# Output includes all bound context:
# 2024-01-15 10:30:00 [info] Processing request    user=alice request_id=abc123
# 2024-01-15 10:30:01 [info] Request completed     user=alice request_id=abc123 status=200
```

---

## 4. Colorlog

**Package:** `colorlog`
**Install:** `pip install colorlog`

Colorlog adds colors to the Python standard library's logging module.

### Key Features
- Drop-in replacement for standard logging
- Customizable colors per log level
- Works with existing logging configurations

### Example
```python
import colorlog
import logging

handler = colorlog.StreamHandler()
handler.setFormatter(colorlog.ColoredFormatter(
    '%(log_color)s%(levelname)-8s%(reset)s %(blue)s%(message)s',
    log_colors={
        'DEBUG':    'cyan',
        'INFO':     'green',
        'WARNING':  'yellow',
        'ERROR':    'red',
        'CRITICAL': 'red,bg_white',
    },
    secondary_log_colors={},
    style='%'
))

logger = colorlog.getLogger('example')
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)

logger.debug('Debug message')
logger.info('Info message')
logger.warning('Warning message')
logger.error('Error message')
logger.critical('Critical message')
```

---

## 5. Colorama

**Package:** `colorama`
**GitHub Stars:** ~3k+
**Install:** `pip install colorama`

Colorama makes ANSI escape sequences work on Windows and provides colored terminal text.

### Key Features
- Cross-platform (especially Windows support)
- Simple API
- Works with standard print and logging

### Example
```python
from colorama import init, Fore, Back, Style

init(autoreset=True)  # Auto-reset colors after each print

# Simple colored output
print(Fore.RED + 'This is red text')
print(Fore.GREEN + 'This is green text')
print(Fore.YELLOW + 'This is yellow text')
print(Fore.BLUE + 'This is blue text')

# With backgrounds
print(Back.RED + Fore.WHITE + 'White on red background')

# With styles
print(Style.BRIGHT + Fore.CYAN + 'Bright cyan text')
print(Style.DIM + 'Dimmed text')

# Custom logger with colorama
import logging

class ColoredFormatter(logging.Formatter):
    COLORS = {
        'DEBUG': Fore.CYAN,
        'INFO': Fore.GREEN,
        'WARNING': Fore.YELLOW,
        'ERROR': Fore.RED,
        'CRITICAL': Back.RED + Fore.WHITE,
    }

    def format(self, record):
        color = self.COLORS.get(record.levelname, '')
        record.msg = f"{color}{record.msg}{Style.RESET_ALL}"
        return super().format(record)

logger = logging.getLogger('colorful')
handler = logging.StreamHandler()
handler.setFormatter(ColoredFormatter('%(levelname)s: %(message)s'))
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)
```

---

## 6. Icecream

**Package:** `icecream`
**GitHub Stars:** ~8k+
**Install:** `pip install icecream`

Icecream is a debugging tool that's sweeter than print().

### Key Features
- Automatically prints variable names and values
- Colorful, formatted output
- Shows file, function, and line number
- Easy to enable/disable

### Example
```python
from icecream import ic

# Instead of print debugging
x = 42
y = "hello"
my_list = [1, 2, 3]

# Just wrap in ic()
ic(x)           # ic| x: 42
ic(y)           # ic| y: 'hello'
ic(my_list)     # ic| my_list: [1, 2, 3]

# Multiple values
ic(x, y)        # ic| x: 42, y: 'hello'

# In expressions
ic(x + 10)      # ic| x + 10: 52

# With context (file and line)
ic.configureOutput(includeContext=True)
ic(x)           # ic| script.py:15 in main() - x: 42

# Custom prefix with emojis
ic.configureOutput(prefix='🍦 ')
ic(x)           # 🍦 x: 42

# Disable for production
ic.disable()
ic(x)           # (no output)
```

---

## Quick Comparison

| Library | Setup | Fancy Output | Structured | Best For |
|---------|-------|--------------|------------|----------|
| Loguru | ⭐ Easy | ⭐⭐⭐⭐⭐ | ✅ | General logging |
| Rich | Medium | ⭐⭐⭐⭐⭐ | ❌ | Beautiful CLI apps |
| Structlog | Medium | ⭐⭐⭐⭐ | ✅ | Microservices |
| Colorlog | Easy | ⭐⭐⭐ | ❌ | Existing projects |
| Colorama | Easy | ⭐⭐⭐ | ❌ | Windows support |
| Icecream | ⭐ Easy | ⭐⭐⭐⭐ | ❌ | Debugging |

## Recommendation

**For new projects:** Use **Loguru** - it's the simplest to set up and provides excellent colorful output out of the box.

**For beautiful CLI tools:** Use **Rich** - it provides the most stunning terminal output with emojis, tables, and progress bars.

**For production microservices:** Use **Structlog** - it provides structured logging that's easy to parse in log aggregation systems.

## Sources

- [Better Stack: Best Python Logging Libraries](https://betterstack.com/community/guides/logging/best-python-logging-libraries/)
- [Loguru GitHub](https://github.com/Delgan/loguru)
- [Rich GitHub](https://github.com/Textualize/rich)
- [Structlog Documentation](https://www.structlog.org/)
- [Better Stack: Loguru Guide](https://betterstack.com/community/guides/logging/loguru/)
