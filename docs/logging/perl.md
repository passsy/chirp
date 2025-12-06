# Perl Logging Libraries

A comprehensive guide to the most popular logging libraries for Perl, with a focus on colorful console output.

## 1. Log::Log4perl with ScreenColoredLevels

**CPAN:**
```bash
cpan Log::Log4perl
```

The most popular Perl logging framework, inspired by log4j.

### Key Features
- Colorized output per log level
- Hierarchical logger namespaces
- Multiple appenders
- Pattern layouts
- Configuration files or code

### Example with Colored Output
```perl
use strict;
use warnings;
use Log::Log4perl qw(:easy);

# Initialize with colored console
Log::Log4perl->init(\<<'EOT');
log4perl.rootLogger = DEBUG, Screen

log4perl.appender.Screen = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = [%d] [%p] %m%n

# Custom colors
log4perl.appender.Screen.color.TRACE = yellow
log4perl.appender.Screen.color.DEBUG = cyan
log4perl.appender.Screen.color.INFO = green
log4perl.appender.Screen.color.WARN = blue
log4perl.appender.Screen.color.ERROR = magenta
log4perl.appender.Screen.color.FATAL = red
EOT

# Create logger
my $logger = get_logger();

# Basic logging
$logger->trace("Trace message");   # Yellow
$logger->debug("Debug message");   # Cyan
$logger->info("Info message");     # Green
$logger->warn("Warning message");  # Blue
$logger->error("Error message");   # Magenta
$logger->fatal("Fatal message");   # Red

# With formatting
my $user = "alice";
my $count = 42;
$logger->info("User $user processed $count items");
```

### Colored Pattern Layout
```perl
use Log::Log4perl qw(:easy);

Log::Log4perl->init(\<<'EOT');
log4perl.rootLogger = DEBUG, ColorConsole

log4perl.appender.ColorConsole = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.ColorConsole.layout = Log::Log4perl::Layout::ColoredPatternLayout
log4perl.appender.ColorConsole.layout.ConversionPattern = %d %p{1} %c - %m%n

# Color individual parts of the pattern
log4perl.appender.ColorConsole.layout.ColorMap.d = cyan
log4perl.appender.ColorConsole.layout.ColorMap.p = bold
log4perl.appender.ColorConsole.layout.ColorMap.c = blue
EOT

my $logger = get_logger("MyApp");
$logger->info("Colorful pattern!");
```

---

## 2. Log::Any with ANSIColor

**CPAN:**
```bash
cpan Log::Any
cpan Log::Any::Plugin::ANSIColor
```

A logging facade that works with various backends.

### Key Features
- Backend-agnostic API
- ANSIColor plugin for colors
- Works with Log::Log4perl, etc.

### Example
```perl
use strict;
use warnings;
use Log::Any qw($log);
use Log::Any::Adapter;
use Log::Any::Plugin;

# Use Screen adapter with colors
Log::Any::Adapter->set('Screen');
Log::Any::Plugin->add('ANSIColor');

# Basic logging with colors
$log->trace("Trace message");
$log->debug("Debug message");
$log->info("Info message");
$log->warning("Warning message");
$log->error("Error message");
$log->critical("Critical message");

# With context
$log->info("User logged in", { user => "alice", ip => "192.168.1.1" });
```

### Custom Color Scheme
```perl
use Log::Any::Plugin;

Log::Any::Plugin->add('ANSIColor', colors => {
    trace    => 'white',
    debug    => 'cyan',
    info     => 'green',
    notice   => 'bright_green',
    warning  => 'yellow',
    error    => 'red',
    critical => 'bold red',
    alert    => 'bold red on_white',
    emergency => 'bold white on_red',
});
```

---

## 3. Log::Any::Adapter::Screen

**CPAN:**
```bash
cpan Log::Any::Adapter::Screen
```

A Log::Any adapter with built-in color support.

### Example
```perl
use strict;
use warnings;
use Log::Any qw($log);
use Log::Any::Adapter;

# Configure with colors
Log::Any::Adapter->set('Screen',
    colored => 1,
    colors => {
        trace   => 'yellow',
        debug   => 'cyan',
        info    => 'green',
        notice  => 'bright_green',
        warning => 'bold blue',
        error   => 'magenta',
        critical => 'red',
    }
);

$log->debug("Debug message");
$log->info("Info message");
$log->warning("Warning message");
$log->error("Error message");
```

---

## 4. Term::ANSIColor (for Custom Loggers)

**CPAN:** (Core module, usually pre-installed)
```bash
cpan Term::ANSIColor
```

ANSI color support for terminal output.

### Key Features
- Core Perl module
- Full ANSI color support
- Simple API

### Example
```perl
use strict;
use warnings;
use Term::ANSIColor qw(:constants colored);

# Basic colors
print RED, "Red text", RESET, "\n";
print GREEN, "Green text", RESET, "\n";
print YELLOW, "Yellow text", RESET, "\n";
print BLUE, "Blue text", RESET, "\n";

# Using colored()
print colored("Red text\n", "red");
print colored("Bold green\n", "bold green");
print colored("White on red\n", "white on_red");

# Custom logger
sub log_debug { print colored("[DEBUG] $_[0]\n", "cyan") }
sub log_info  { print colored("[INFO] $_[0]\n", "green") }
sub log_warn  { print colored("[WARN] $_[0]\n", "yellow") }
sub log_error { print colored("[ERROR] $_[0]\n", "bold red") }

log_debug("Loading configuration...");
log_info("Server starting on port 8080");
log_warn("High memory usage");
log_error("Connection failed");
```

---

## 5. Log::Log4Cli

**CPAN:**
```bash
cpan Log::Log4Cli
```
**GitHub Stars:** ~20

Lightweight logger for command line tools.

### Key Features
- Minimal dependencies
- Colorful output
- Simple API
- Good for CLI tools

### Example
```perl
use strict;
use warnings;
use Log::Log4Cli;

# Basic logging
log_trace("Trace message");
log_debug("Debug message");
log_info("Info message");
log_warn("Warning message");
log_error("Error message");

# Custom colors
$Log::Log4Cli::COLORS->{DEBUG} = 'cyan';
$Log::Log4Cli::COLORS->{INFO}  = 'green';
$Log::Log4Cli::COLORS->{WARN}  = 'yellow';
$Log::Log4Cli::COLORS->{ERROR} = 'red';

# Set log level
use Log::Log4Cli ':levels';
$Log::Log4Cli::LEVEL = LOG_DEBUG;

log_debug("Now visible!");
```

---

## 6. Custom Colorful Logger

Build your own simple colorful logger.

### Example
```perl
use strict;
use warnings;
use Term::ANSIColor qw(colored);
use POSIX qw(strftime);

package ColorLogger;

our $LEVEL = 'DEBUG';
my %LEVELS = (
    TRACE => 0,
    DEBUG => 1,
    INFO  => 2,
    WARN  => 3,
    ERROR => 4,
    FATAL => 5,
);

my %COLORS = (
    TRACE => 'white',
    DEBUG => 'cyan',
    INFO  => 'green',
    WARN  => 'yellow',
    ERROR => 'red',
    FATAL => 'bold red on_white',
);

my %EMOJIS = (
    TRACE => '🔍',
    DEBUG => '🐛',
    INFO  => 'ℹ️',
    WARN  => '⚠️',
    ERROR => '❌',
    FATAL => '💀',
);

sub _log {
    my ($level, $message) = @_;
    return if $LEVELS{$level} < $LEVELS{$LEVEL};

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $emoji = $EMOJIS{$level};
    my $color = $COLORS{$level};

    print colored("[$timestamp] $emoji [$level] $message\n", $color);
}

sub trace { _log('TRACE', $_[0]) }
sub debug { _log('DEBUG', $_[0]) }
sub info  { _log('INFO', $_[0]) }
sub warn  { _log('WARN', $_[0]) }
sub error { _log('ERROR', $_[0]) }
sub fatal { _log('FATAL', $_[0]) }

sub success {
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    print colored("[$timestamp] ✅ [SUCCESS] $_[0]\n", 'bold green');
}

1;

# Usage
package main;

ColorLogger::debug("Loading configuration...");
ColorLogger::info("Server starting on port 8080");
ColorLogger::success("Database connected!");
ColorLogger::warn("High memory usage detected");
ColorLogger::error("Connection timeout");
ColorLogger::fatal("System crash!");
```

### Object-Oriented Logger
```perl
use strict;
use warnings;
use Term::ANSIColor qw(colored);

package MyLogger;

sub new {
    my ($class, %args) = @_;
    return bless {
        name  => $args{name} // 'App',
        level => $args{level} // 'DEBUG',
    }, $class;
}

sub debug { shift->_log('DEBUG', 'cyan', @_) }
sub info  { shift->_log('INFO', 'green', @_) }
sub warn  { shift->_log('WARN', 'yellow', @_) }
sub error { shift->_log('ERROR', 'red', @_) }

sub _log {
    my ($self, $level, $color, $message) = @_;
    my $timestamp = localtime();
    print colored("[$timestamp] [$level] [$self->{name}] $message\n", $color);
}

1;

# Usage
package main;

my $logger = MyLogger->new(name => 'MyApp');
$logger->debug("Debug message");
$logger->info("Info message");
$logger->warn("Warning message");
$logger->error("Error message");
```

---

## Quick Comparison

| Library | Colors | Features | Best For |
|---------|--------|----------|----------|
| Log::Log4perl | ⭐⭐⭐⭐⭐ | Full-featured | Enterprise |
| Log::Any | ⭐⭐⭐⭐ | Backend-agnostic | Libraries |
| Log::Log4Cli | ⭐⭐⭐⭐ | Lightweight | CLI tools |
| Term::ANSIColor | ⭐⭐⭐⭐⭐ | Colors only | Custom loggers |

## Recommendation

**For enterprise apps:** Use **Log::Log4perl** with **ScreenColoredLevels** - it's the most feature-rich.

**For libraries:** Use **Log::Any** with **ANSIColor** plugin - it's backend-agnostic.

**For CLI tools:** Use **Log::Log4Cli** - it's lightweight and colorful.

**For simple needs:** Use **Term::ANSIColor** to build your own logger.

## Windows Note

For Windows support, you may need Win32::Console::ANSI:
```perl
use Win32::Console::ANSI;  # Before Term::ANSIColor
use Term::ANSIColor;
```

## Sources

- [Log::Log4perl::Appender::ScreenColoredLevels](https://metacpan.org/pod/Log::Log4perl::Appender::ScreenColoredLevels)
- [Log::Any::Plugin::ANSIColor](https://metacpan.org/pod/Log::Any::Plugin::ANSIColor)
- [Log::Log4perl Documentation](https://metacpan.org/pod/Log::Log4perl)
- [Term::ANSIColor](https://metacpan.org/pod/Term::ANSIColor)
- [Log::Log4Cli](https://github.com/mr-mixas/Log-Log4Cli.pm)
