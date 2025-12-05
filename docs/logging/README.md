# Logging Libraries Research

A comprehensive collection of logging libraries across 20 programming languages, with a special focus on libraries that provide **colorful, fancy console output** with colors, emojis, and beautiful formatting.

## Languages Covered

| Language | File | Top Recommendation |
|----------|------|-------------------|
| [JavaScript/Node.js](./javascript.md) | javascript.md | Consola, Signale |
| [Python](./python.md) | python.md | Loguru, Rich |
| [Java](./java.md) | java.md | Logback with colors |
| [C#/.NET](./csharp.md) | csharp.md | Serilog, Spectre.Console |
| [Go](./go.md) | go.md | Zerolog, Charm Log |
| [Rust](./rust.md) | rust.md | pretty_env_logger, tracing |
| [PHP](./php.md) | php.md | Monolog + Bramus formatter |
| [Ruby](./ruby.md) | ruby.md | Semantic Logger, TTY::Logger |
| [Swift](./swift.md) | swift.md | CocoaLumberjack, XCGLogger |
| [Kotlin](./kotlin.md) | kotlin.md | Timber, Napier |
| [TypeScript](./typescript.md) | typescript.md | tslog, Consola |
| [C++](./cpp.md) | cpp.md | spdlog |
| [Dart/Flutter](./dart.md) | dart.md | logger, talker |
| [Scala](./scala.md) | scala.md | Airframe-Log, Scribe |
| [R](./r.md) | r.md | logger + crayon, cli |
| [Perl](./perl.md) | perl.md | Log::Log4perl |
| [Shell/Bash](./shell.md) | shell.md | Custom ANSI, Gum |
| [Objective-C](./objective-c.md) | objective-c.md | CocoaLumberjack |
| [Elixir](./elixir.md) | elixir.md | Built-in Logger |
| [Lua](./lua.md) | lua.md | LuaLogging + ansicolors |

## Highlights: Most Beautiful Loggers

These libraries stand out for their exceptionally beautiful and fancy output:

### Best Overall Fancy Output
- **Python: Rich** - Markdown rendering, tables, progress bars, emojis
- **JavaScript: Consola** - Elegant box output, spinners, prompts
- **JavaScript: Signale** - 19 built-in log types with emojis
- **Go: Charm Log** - Beautiful defaults from the Charm.sh team
- **C#: Spectre.Console** - Tables, trees, progress bars (not a logger but perfect for CLI)
- **Ruby: TTY::Logger** - Beautiful icons and formatting

### Best for Development/Debugging
- **Python: Icecream** - Auto-prints variable names with values
- **Dart: logger** - Pretty boxes with emojis
- **Dart: talker** - Built-in Flutter UI log viewer

### Most Colorful Console Output
- **Node.js: Chalk** - Build any colorful output you want
- **Rust: pretty_env_logger** - Colorful by default
- **Go: Zerolog** - ConsoleWriter with colors
- **Scala: Airframe-Log** - ANSI colors built-in

## Common Patterns

Most colorful loggers share these features:

1. **Level-based colors:**
   - Debug: Cyan/Blue
   - Info: Green
   - Warning: Yellow
   - Error: Red
   - Fatal/Critical: Red background or bold red

2. **Emojis for quick recognition:**
   - 🔍 Trace/Debug
   - ℹ️ Info
   - ✅ Success
   - ⚠️ Warning
   - ❌ Error
   - 💀 Fatal

3. **Structured output:**
   - Timestamps
   - Log levels
   - Source file/line numbers
   - Contextual metadata

## Environment Considerations

### Respecting User Preferences
Many modern loggers support the `NO_COLOR` environment variable standard:
```bash
export NO_COLOR=1  # Disables colors
```

### Terminal Compatibility
- Most Unix terminals support ANSI colors
- Windows: Use Windows Terminal, PowerShell 7+, or enable ANSI mode
- IDEs: Check for plugin support (e.g., Grep Console for JetBrains)

## Quick Start Examples

### Python (Loguru)
```python
from loguru import logger
logger.info("Beautiful logs out of the box!")
```

### JavaScript (Consola)
```javascript
import { consola } from 'consola'
consola.success('It works!')
```

### Go (Charm Log)
```go
import "github.com/charmbracelet/log"
log.Info("Hello, world!")
```

### Dart (logger)
```dart
import 'package:logger/logger.dart';
final logger = Logger();
logger.i('Pretty logs!');
```

---

*This research was compiled focusing on libraries that provide excellent developer experience through colorful, informative, and beautiful console output.*
