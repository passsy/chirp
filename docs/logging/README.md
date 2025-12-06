# Logging Libraries Research

A comprehensive collection of logging libraries across 20 programming languages, with a special focus on libraries that provide **colorful, fancy console output** with colors, emojis, and beautiful formatting.

## Languages Covered

| Language | Top Recommendations |
|----------|---------------------|
| [JavaScript/Node.js](./javascript.md) | [Consola](https://www.npmjs.com/package/consola) · [Signale](https://www.npmjs.com/package/signale) · [Pino](https://www.npmjs.com/package/pino) |
| [Python](./python.md) | [Loguru](https://pypi.org/project/loguru/) · [Rich](https://pypi.org/project/rich/) · [Structlog](https://pypi.org/project/structlog/) |
| [Java](./java.md) | [Logback](https://logback.qos.ch/) · [Log4j2](https://logging.apache.org/log4j/2.x/) |
| [C#/.NET](./csharp.md) | [Serilog](https://www.nuget.org/packages/Serilog) · [Spectre.Console](https://www.nuget.org/packages/Spectre.Console) |
| [Go](./go.md) | [Zerolog](https://pkg.go.dev/github.com/rs/zerolog) · [Charm Log](https://pkg.go.dev/github.com/charmbracelet/log) · [Zap](https://pkg.go.dev/go.uber.org/zap) |
| [Rust](./rust.md) | [pretty_env_logger](https://crates.io/crates/pretty_env_logger) · [tracing](https://crates.io/crates/tracing) · [env_logger](https://crates.io/crates/env_logger) |
| [PHP](./php.md) | [Monolog](https://packagist.org/packages/monolog/monolog) |
| [Ruby](./ruby.md) | [Semantic Logger](https://rubygems.org/gems/semantic_logger) · [TTY::Logger](https://rubygems.org/gems/tty-logger) |
| [Swift](./swift.md) | [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) · [XCGLogger](https://github.com/DaveWoodCom/XCGLogger) · [Pulse](https://github.com/kean/Pulse) |
| [Kotlin](./kotlin.md) | [Timber](https://github.com/JakeWharton/timber) · [Napier](https://github.com/AAkira/Napier) · [Kermit](https://github.com/touchlab/Kermit) |
| [TypeScript](./typescript.md) | [tslog](https://www.npmjs.com/package/tslog) · [Consola](https://www.npmjs.com/package/consola) |
| [C++](./cpp.md) | [spdlog](https://github.com/gabime/spdlog) |
| [Dart/Flutter](./dart.md) | [logger](https://pub.dev/packages/logger) · [talker](https://pub.dev/packages/talker) · [ChalkDart](https://pub.dev/packages/chalkdart) |
| [Scala](./scala.md) | [Airframe-Log](https://wvlet.org/airframe/docs/airframe-log) · [Scribe](https://github.com/outr/scribe) |
| [R](./r.md) | [logger](https://cran.r-project.org/package=logger) · [cli](https://cran.r-project.org/package=cli) |
| [Perl](./perl.md) | [Log::Log4perl](https://metacpan.org/pod/Log::Log4perl) |
| [Shell/Bash](./shell.md) | [Gum](https://github.com/charmbracelet/gum) |
| [Objective-C](./objective-c.md) | [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) |
| [Elixir](./elixir.md) | [Logger](https://hexdocs.pm/logger/Logger.html) (built-in) |
| [Lua](./lua.md) | [LuaLogging](https://luarocks.org/modules/lunarmodules/lualogging) · [ansicolors](https://luarocks.org/modules/kikito/ansicolors) |

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
