# C# / .NET Logging Libraries

A comprehensive guide to the most popular logging libraries for C# and .NET, with a focus on colorful console output.

## 1. Serilog (with Colored Console Sink)

**NuGet:**
```bash
dotnet add package Serilog
dotnet add package Serilog.Sinks.Console
```
**GitHub Stars:** ~7k+

Serilog is a diagnostic logging library with structured logging support.

### Key Features
- Structured logging with message templates
- Colorized console output via Console sink
- Wide variety of sinks (file, database, cloud, etc.)
- Easy configuration

### Example
```csharp
using Serilog;

// Configure with colorful console output
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    .WriteTo.Console(
        outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}",
        theme: Serilog.Sinks.SystemConsole.Themes.AnsiConsoleTheme.Code)
    .CreateLogger();

// Usage
Log.Debug("Debug message");           // Gray
Log.Information("Info message");       // White
Log.Warning("Warning message");        // Yellow
Log.Error("Error message");            // Red
Log.Fatal("Fatal message");            // Red background

// Structured logging
var user = "Alice";
var count = 42;
Log.Information("User {User} processed {Count} items", user, count);

// With exception
try
{
    throw new Exception("Something went wrong!");
}
catch (Exception ex)
{
    Log.Error(ex, "An error occurred");
}

Log.CloseAndFlush();
```

### Custom Color Theme
```csharp
using Serilog.Sinks.SystemConsole.Themes;

var customTheme = new AnsiConsoleTheme(new Dictionary<ConsoleThemeStyle, string>
{
    [ConsoleThemeStyle.Text] = "\x1b[38;5;0015m",
    [ConsoleThemeStyle.SecondaryText] = "\x1b[38;5;0007m",
    [ConsoleThemeStyle.TertiaryText] = "\x1b[38;5;0008m",
    [ConsoleThemeStyle.LevelVerbose] = "\x1b[38;5;0007m",
    [ConsoleThemeStyle.LevelDebug] = "\x1b[38;5;0007m",
    [ConsoleThemeStyle.LevelInformation] = "\x1b[38;5;0046m",  // Green
    [ConsoleThemeStyle.LevelWarning] = "\x1b[38;5;0226m",      // Yellow
    [ConsoleThemeStyle.LevelError] = "\x1b[38;5;0196m",        // Red
    [ConsoleThemeStyle.LevelFatal] = "\x1b[38;5;0196m\x1b[48;5;0015m",  // Red on white
});
```

---

## 2. NLog (with Colored Console Target)

**NuGet:**
```bash
dotnet add package NLog
```
**GitHub Stars:** ~6k+

NLog is a flexible and widely-used logging framework.

### Key Features
- Highly configurable via XML or code
- Multiple targets (file, console, database, email)
- Rich formatting options
- High performance

### Configuration (nlog.config)
```xml
<?xml version="1.0" encoding="utf-8" ?>
<nlog xmlns="http://www.nlog-project.org/schemas/NLog.xsd"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

    <targets>
        <target name="coloredConsole" xsi:type="ColoredConsole"
                layout="${time} ${level:uppercase=true:padding=-5} ${message} ${exception}">
            <highlight-row condition="level == LogLevel.Debug" foregroundColor="DarkGray"/>
            <highlight-row condition="level == LogLevel.Info" foregroundColor="Green"/>
            <highlight-row condition="level == LogLevel.Warn" foregroundColor="Yellow"/>
            <highlight-row condition="level == LogLevel.Error" foregroundColor="Red"/>
            <highlight-row condition="level == LogLevel.Fatal" foregroundColor="White" backgroundColor="Red"/>
        </target>
    </targets>

    <rules>
        <logger name="*" minlevel="Debug" writeTo="coloredConsole"/>
    </rules>
</nlog>
```

### Example
```csharp
using NLog;

class Program
{
    private static readonly Logger Logger = LogManager.GetCurrentClassLogger();

    static void Main()
    {
        Logger.Trace("Trace message");
        Logger.Debug("Debug message");      // Dark gray
        Logger.Info("Info message");        // Green
        Logger.Warn("Warning message");     // Yellow
        Logger.Error("Error message");      // Red
        Logger.Fatal("Fatal message");      // White on red

        // With structured data
        Logger.Info("User {user} logged in from {ip}", "Alice", "192.168.1.1");

        // With exception
        try
        {
            throw new InvalidOperationException("Test error");
        }
        catch (Exception ex)
        {
            Logger.Error(ex, "An error occurred");
        }
    }
}
```

---

## 3. Microsoft.Extensions.Logging (with Colored Console)

**NuGet:**
```bash
dotnet add package Microsoft.Extensions.Logging.Console
```

The default logging framework in .NET Core / ASP.NET Core.

### Key Features
- Built into .NET
- Provider-based architecture
- Easy integration with dependency injection
- Can use Serilog or NLog as backend

### Example
```csharp
using Microsoft.Extensions.Logging;

// Create logger factory with console
using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder
        .SetMinimumLevel(LogLevel.Debug)
        .AddSimpleConsole(options =>
        {
            options.ColorBehavior = Microsoft.Extensions.Logging.Console.LoggerColorBehavior.Enabled;
            options.SingleLine = true;
            options.TimestampFormat = "HH:mm:ss ";
        });
});

var logger = loggerFactory.CreateLogger<Program>();

logger.LogDebug("Debug message");
logger.LogInformation("Information message");
logger.LogWarning("Warning message");
logger.LogError("Error message");
logger.LogCritical("Critical message");

// With structured logging
logger.LogInformation("User {User} performed {Action}", "Alice", "login");
```

---

## 4. Spectre.Console (Beautiful Console Output)

**NuGet:**
```bash
dotnet add package Spectre.Console
```
**GitHub Stars:** ~8k+

Spectre.Console is a library for beautiful console applications.

### Key Features
- Rich text with markup
- Tables, trees, and progress bars
- Emojis and color support
- Not a logging library, but perfect for CLI output

### Example
```csharp
using Spectre.Console;

// Rich text with colors
AnsiConsole.MarkupLine("[green]Success![/] Operation completed.");
AnsiConsole.MarkupLine("[yellow]Warning:[/] Resource usage is high.");
AnsiConsole.MarkupLine("[red]Error:[/] Connection failed!");

// With emojis
AnsiConsole.MarkupLine(":check_mark: [green]Tests passed[/]");
AnsiConsole.MarkupLine(":warning: [yellow]Deprecation warning[/]");
AnsiConsole.MarkupLine(":cross_mark: [red]Build failed[/]");

// Styled text
AnsiConsole.MarkupLine("[bold blue]INFO[/] Server starting...");
AnsiConsole.MarkupLine("[italic grey]DEBUG[/] Loading configuration...");

// Tables
var table = new Table();
table.AddColumn("Level");
table.AddColumn("Count");
table.AddRow("[green]INFO[/]", "1523");
table.AddRow("[yellow]WARN[/]", "45");
table.AddRow("[red]ERROR[/]", "3");
AnsiConsole.Write(table);

// Custom logger using Spectre
public static class SpectreLogger
{
    public static void Info(string message) =>
        AnsiConsole.MarkupLine($"[blue][[INFO]][/] {message}");

    public static void Success(string message) =>
        AnsiConsole.MarkupLine($"[green][[SUCCESS]][/] :check_mark: {message}");

    public static void Warn(string message) =>
        AnsiConsole.MarkupLine($"[yellow][[WARN]][/] :warning: {message}");

    public static void Error(string message) =>
        AnsiConsole.MarkupLine($"[red][[ERROR]][/] :cross_mark: {message}");
}
```

---

## 5. log4net (with Colored Console Appender)

**NuGet:**
```bash
dotnet add package log4net
```

The .NET port of the popular Java log4j framework.

### Configuration
```xml
<log4net>
    <appender name="ColoredConsoleAppender" type="log4net.Appender.ColoredConsoleAppender">
        <mapping>
            <level value="ERROR"/>
            <foreColor value="Red, HighIntensity"/>
        </mapping>
        <mapping>
            <level value="WARN"/>
            <foreColor value="Yellow"/>
        </mapping>
        <mapping>
            <level value="INFO"/>
            <foreColor value="Green"/>
        </mapping>
        <mapping>
            <level value="DEBUG"/>
            <foreColor value="Cyan"/>
        </mapping>
        <layout type="log4net.Layout.PatternLayout">
            <conversionPattern value="%date [%thread] %-5level %logger - %message%newline"/>
        </layout>
    </appender>

    <root>
        <level value="DEBUG"/>
        <appender-ref ref="ColoredConsoleAppender"/>
    </root>
</log4net>
```

---

## 6. Pastel (Simple ANSI Colors)

**NuGet:**
```bash
dotnet add package Pastel
```

A micro-library for adding ANSI colors to console output.

### Example
```csharp
using Pastel;
using System.Drawing;

// Basic colors
Console.WriteLine("This is red".Pastel(Color.Red));
Console.WriteLine("This is green".Pastel(Color.Green));
Console.WriteLine("This is blue".Pastel(Color.Blue));

// Hex colors
Console.WriteLine("Custom color".Pastel("#FF8800"));

// With background
Console.WriteLine("White on red".Pastel(Color.White).PastelBg(Color.Red));

// Build a simple logger
public static class ColorLog
{
    public static void Info(string msg) =>
        Console.WriteLine($"{"[INFO]".Pastel(Color.Cyan)} {msg}");

    public static void Success(string msg) =>
        Console.WriteLine($"{"[SUCCESS]".Pastel(Color.Green)} {msg}");

    public static void Warn(string msg) =>
        Console.WriteLine($"{"[WARN]".Pastel(Color.Yellow)} {msg}");

    public static void Error(string msg) =>
        Console.WriteLine($"{"[ERROR]".Pastel(Color.Red)} {msg}");
}

// Usage
ColorLog.Info("Starting application...");
ColorLog.Success("Connected to database");
ColorLog.Warn("High memory usage");
ColorLog.Error("Connection timeout");
```

---

## Quick Comparison

| Library | Colors | Structured | Performance | Best For |
|---------|--------|------------|-------------|----------|
| Serilog | ⭐⭐⭐⭐ | ✅ | Fast | Modern apps |
| NLog | ⭐⭐⭐⭐ | ✅ | Fast | Enterprise |
| MS Logging | ⭐⭐⭐ | ✅ | Fast | ASP.NET Core |
| Spectre.Console | ⭐⭐⭐⭐⭐ | ❌ | Fast | CLI tools |
| Pastel | ⭐⭐⭐⭐⭐ | ❌ | Fast | Simple coloring |

## Recommendation

**For ASP.NET Core:** Use **Serilog** with the Console sink - it has excellent structured logging and colorful output.

**For beautiful CLI tools:** Use **Spectre.Console** - it provides stunning terminal output with tables, progress bars, and emojis.

**For enterprise apps:** Use **NLog** - it's highly configurable and battle-tested.

## Sources

- [Better Stack: Best .NET Logging Libraries](https://betterstack.com/community/guides/logging/best-dotnet-logging-libraries/)
- [Serilog GitHub](https://github.com/serilog/serilog)
- [Spectre.Console GitHub](https://github.com/spectreconsole/spectre.console)
- [NLog Colored Console](https://github.com/NLog/NLog/wiki/ColoredConsole-target)
- [Stackify: Serilog Tutorial](https://stackify.com/serilog-tutorial-net-logging/)
