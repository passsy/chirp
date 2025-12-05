# PHP Logging Libraries

A comprehensive guide to the most popular logging libraries for PHP, with a focus on colorful console output.

## 1. Monolog (with Colored Line Formatter)

**Composer:**
```bash
composer require monolog/monolog
composer require bramus/monolog-colored-line-formatter
```
**GitHub Stars:** ~21k+

Monolog is the most popular PHP logging library, PSR-3 compliant.

### Key Features
- PSR-3 compliant
- Multiple handlers (file, console, email, databases)
- Formatters and processors
- Color support via external formatter

### Example with Colors
```php
<?php
require 'vendor/autoload.php';

use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Bramus\Monolog\Formatter\ColoredLineFormatter;

// Create logger
$log = new Logger('app');

// Add colored console handler
$handler = new StreamHandler('php://stdout', Logger::DEBUG);
$handler->setFormatter(new ColoredLineFormatter());
$log->pushHandler($handler);

// Log messages with colors
$log->debug('Debug message');     // Default
$log->info('Info message');       // Green
$log->notice('Notice message');   // Cyan
$log->warning('Warning message'); // Yellow
$log->error('Error message');     // Red
$log->critical('Critical!');      // Red background
$log->alert('Alert!');            // Red background
$log->emergency('Emergency!');    // Red background

// With context
$log->info('User logged in', ['user' => 'alice', 'ip' => '192.168.1.1']);

// With exception
try {
    throw new Exception('Something went wrong');
} catch (Exception $e) {
    $log->error('Error occurred', ['exception' => $e]);
}
```

### Custom Color Scheme
```php
<?php
use Bramus\Monolog\Formatter\ColorSchemes\ColorSchemeInterface;
use Bramus\Ansi\ControlSequences\EscapeSequences\Enums\SGR;

class CustomColorScheme implements ColorSchemeInterface
{
    public function getColorizeArray(): array
    {
        return [
            Logger::DEBUG => [SGR::COLOR_FG_CYAN],
            Logger::INFO => [SGR::COLOR_FG_GREEN],
            Logger::NOTICE => [SGR::COLOR_FG_BLUE],
            Logger::WARNING => [SGR::COLOR_FG_YELLOW, SGR::STYLE_BOLD],
            Logger::ERROR => [SGR::COLOR_FG_RED],
            Logger::CRITICAL => [SGR::COLOR_FG_WHITE, SGR::COLOR_BG_RED],
            Logger::ALERT => [SGR::COLOR_FG_WHITE, SGR::COLOR_BG_RED, SGR::STYLE_BLINK],
            Logger::EMERGENCY => [SGR::COLOR_FG_WHITE, SGR::COLOR_BG_RED, SGR::STYLE_BOLD],
        ];
    }
}

$formatter = new ColoredLineFormatter(new CustomColorScheme());
```

---

## 2. Symfony Console Logger

**Composer:**
```bash
composer require symfony/console
```

Symfony's ConsoleLogger provides colorful logging that respects verbosity levels.

### Key Features
- Automatic color based on log level
- Respects console verbosity flags
- Integrated with Symfony framework
- Timestamped output

### Example
```php
<?php
use Symfony\Component\Console\Logger\ConsoleLogger;
use Symfony\Component\Console\Output\ConsoleOutput;
use Psr\Log\LogLevel;

// Create console output
$output = new ConsoleOutput(ConsoleOutput::VERBOSITY_DEBUG);

// Create logger
$logger = new ConsoleLogger($output);

// Logging with colors
$logger->debug('Debug message');      // Hidden by default
$logger->info('Info message');        // Green
$logger->notice('Notice message');    // Yellow
$logger->warning('Warning message');  // Yellow
$logger->error('Error message');      // Red
$logger->critical('Critical!');       // Red
$logger->alert('Alert!');             // Red
$logger->emergency('Emergency!');     // Red

// With context
$logger->info('Processing request', ['method' => 'GET', 'path' => '/api']);
```

### Verbosity Mapping
| Log Level | Verbosity Required |
|-----------|-------------------|
| emergency, alert, critical, error | VERBOSITY_QUIET |
| warning | VERBOSITY_NORMAL |
| notice, info | VERBOSITY_VERBOSE |
| debug | VERBOSITY_VERY_VERBOSE |

---

## 3. CLImate (Console Styling)

**Composer:**
```bash
composer require league/climate
```

CLImate is a PHP library for beautiful CLI output.

### Key Features
- Colorful output
- Progress bars and tables
- Input handling
- Art and animations

### Example
```php
<?php
require 'vendor/autoload.php';

use League\CLImate\CLImate;

$climate = new CLImate;

// Colored output
$climate->red('This is red text');
$climate->green('This is green text');
$climate->yellow('This is yellow text');
$climate->blue('This is blue text');

// With backgrounds
$climate->backgroundRed()->white('White on red');
$climate->backgroundGreen()->black('Black on green');

// Bold and underline
$climate->bold()->red('Bold red text');
$climate->underline('Underlined text');

// Log-like methods
$climate->info('Info message');      // Cyan
$climate->comment('Comment');        // Yellow
$climate->whisper('Whisper');        // Gray
$climate->shout('SHOUT!');           // Red bold
$climate->error('Error message');    // Red

// With formatting
$climate->out('<green>Success:</green> Operation completed');
$climate->out('<red>Error:</red> Something went wrong');

// Tables
$climate->table([
    ['Level' => 'INFO', 'Count' => 1523],
    ['Level' => 'WARN', 'Count' => 45],
    ['Level' => 'ERROR', 'Count' => 3],
]);

// Progress bar
$progress = $climate->progress()->total(100);
for ($i = 0; $i <= 100; $i++) {
    $progress->current($i);
    usleep(10000);
}
```

---

## 4. PHP-Console (Simple Colored Logger)

A simple approach using ANSI codes directly.

### Example
```php
<?php

class ColorLogger
{
    const RESET = "\033[0m";
    const RED = "\033[31m";
    const GREEN = "\033[32m";
    const YELLOW = "\033[33m";
    const BLUE = "\033[34m";
    const MAGENTA = "\033[35m";
    const CYAN = "\033[36m";
    const WHITE = "\033[37m";

    const BOLD = "\033[1m";
    const BG_RED = "\033[41m";
    const BG_GREEN = "\033[42m";

    public function debug(string $message): void
    {
        $this->log(self::CYAN, 'DEBUG', $message);
    }

    public function info(string $message): void
    {
        $this->log(self::GREEN, 'INFO', $message);
    }

    public function warning(string $message): void
    {
        $this->log(self::YELLOW, 'WARN', $message);
    }

    public function error(string $message): void
    {
        $this->log(self::RED, 'ERROR', $message);
    }

    public function success(string $message): void
    {
        $this->log(self::GREEN . self::BOLD, '✔ SUCCESS', $message);
    }

    public function critical(string $message): void
    {
        echo self::BG_RED . self::WHITE . self::BOLD;
        echo "[CRITICAL] " . $message;
        echo self::RESET . PHP_EOL;
    }

    private function log(string $color, string $level, string $message): void
    {
        $timestamp = date('Y-m-d H:i:s');
        echo $color . "[{$timestamp}] [{$level}] " . self::RESET . $message . PHP_EOL;
    }
}

// Usage
$logger = new ColorLogger();
$logger->debug('Loading configuration...');
$logger->info('Server started on port 8080');
$logger->success('Database connected');
$logger->warning('High memory usage detected');
$logger->error('Failed to connect to API');
$logger->critical('System failure!');
```

---

## 5. PHP-Console-Color

**Composer:**
```bash
composer require php-console-color/php-console-color
```

A simple library for console colors.

### Example
```php
<?php
use JakubOnderka\PhpConsoleColor\ConsoleColor;

$consoleColor = new ConsoleColor();

echo $consoleColor->apply('red', 'Red text') . PHP_EOL;
echo $consoleColor->apply('green', 'Green text') . PHP_EOL;
echo $consoleColor->apply('yellow', 'Yellow text') . PHP_EOL;
echo $consoleColor->apply('blue', 'Blue text') . PHP_EOL;

// Multiple styles
echo $consoleColor->apply(['bold', 'red'], 'Bold red') . PHP_EOL;
echo $consoleColor->apply(['white', 'bg_red'], 'White on red') . PHP_EOL;

// Check if colors are supported
if ($consoleColor->isSupported()) {
    echo $consoleColor->apply('green', '✔ Colors supported!');
}
```

---

## 6. Analog (Simple PSR-3 Logger)

**Composer:**
```bash
composer require analog/analog
```

A minimal PSR-3 logger with various handlers.

### Example
```php
<?php
use Analog\Analog;
use Analog\Handler\Stderr;

// Setup with stderr (supports colors in terminal)
Analog::handler(Stderr::init());

// Log messages
Analog::debug('Debug message');
Analog::info('Info message');
Analog::notice('Notice message');
Analog::warning('Warning message');
Analog::error('Error message');
Analog::critical('Critical message');
Analog::alert('Alert message');
Analog::emergency('Emergency message');
```

---

## Quick Comparison

| Library | Colors | PSR-3 | Features | Best For |
|---------|--------|-------|----------|----------|
| Monolog + Bramus | ⭐⭐⭐⭐ | ✅ | Many handlers | Production apps |
| Symfony Console | ⭐⭐⭐⭐ | ✅ | Verbosity | Symfony apps |
| CLImate | ⭐⭐⭐⭐⭐ | ❌ | Tables, progress | CLI tools |
| Custom ANSI | ⭐⭐⭐⭐⭐ | ❌ | Full control | Simple apps |

## Recommendation

**For production apps:** Use **Monolog** with the **Bramus Colored Line Formatter** - it's the standard and most flexible.

**For Symfony projects:** Use **Symfony Console Logger** - it integrates perfectly with the framework.

**For beautiful CLI tools:** Use **CLImate** - it provides the most features for console output.

## Sources

- [Monolog GitHub](https://github.com/Seldaek/monolog)
- [Bramus Monolog Colored Line Formatter](https://github.com/bramus/monolog-colored-line-formatter)
- [Symfony Console Logger](https://symfony.com/doc/current/logging/monolog_console.html)
- [CLImate Documentation](https://climate.thephpleague.com/)
