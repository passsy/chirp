# Java Logging Libraries

A comprehensive guide to the most popular logging libraries for Java, with a focus on colorful console output.

## 1. Logback (with Color Support)

**Maven:**
```xml
<dependency>
    <groupId>ch.qos.logback</groupId>
    <artifactId>logback-classic</artifactId>
    <version>1.4.11</version>
</dependency>
```
**GitHub Stars:** ~3k+

Logback is the default logging framework in Spring Boot and the successor to Log4j.

### Key Features
- Built-in color support with pattern converters
- Auto-reloading of configuration files
- Automatic removal of old log archives
- Fast performance

### Colorful Configuration (logback.xml)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} %highlight(%-5level) [%thread] %cyan(%logger{36}) - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="DEBUG">
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

### Example Usage
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class MyApp {
    private static final Logger logger = LoggerFactory.getLogger(MyApp.class);

    public static void main(String[] args) {
        logger.trace("Trace message");   // Default color
        logger.debug("Debug message");   // Default color
        logger.info("Info message");     // Blue
        logger.warn("Warning message");  // Yellow
        logger.error("Error message");   // Red
    }
}
```

### Available Color Converters
- `%highlight()` - Colors based on log level
- `%cyan()`, `%red()`, `%green()`, `%yellow()`, `%blue()`, `%magenta()`, `%white()`
- `%boldRed()`, `%boldGreen()`, etc.

---

## 2. Log4j2 (with Color Support)

**Maven:**
```xml
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <version>2.22.0</version>
</dependency>
```
**GitHub Stars:** ~3k+

Log4j2 is the successor to Log4j, offering significant performance improvements.

### Key Features
- Asynchronous logging for high performance
- Plugin architecture
- Built-in color support with ANSI styling
- Garbage-free in steady state

### Colorful Configuration (log4j2.xml)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="%d{HH:mm:ss.SSS} %highlight{%-5level}{FATAL=red blink, ERROR=red, WARN=yellow bold, INFO=green, DEBUG=cyan, TRACE=blue} [%t] %style{%logger{36}}{cyan} - %msg%n"/>
        </Console>
    </Appenders>
    <Loggers>
        <Root level="debug">
            <AppenderRef ref="Console"/>
        </Root>
    </Loggers>
</Configuration>
```

### Example Usage
```java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class MyApp {
    private static final Logger logger = LogManager.getLogger(MyApp.class);

    public static void main(String[] args) {
        logger.trace("Trace message");
        logger.debug("Debug message");   // Cyan
        logger.info("Info message");     // Green
        logger.warn("Warning message");  // Yellow bold
        logger.error("Error message");   // Red
        logger.fatal("Fatal message");   // Red blink
    }
}
```

---

## 3. SLF4J (Simple Logging Facade)

**Maven:**
```xml
<dependency>
    <groupId>org.slf4j</groupId>
    <artifactId>slf4j-api</artifactId>
    <version>2.0.9</version>
</dependency>
```

SLF4J is a logging facade that abstracts the underlying logging framework.

### Key Features
- Framework-independent API
- Switch logging implementations without code changes
- Parameterized logging messages
- Works with Logback, Log4j2, or other implementations

### Example Usage
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class MyApp {
    private static final Logger logger = LoggerFactory.getLogger(MyApp.class);

    public static void main(String[] args) {
        String user = "Alice";
        int count = 42;

        // Parameterized logging (efficient - no string concatenation if level is disabled)
        logger.info("User {} logged in", user);
        logger.debug("Processing {} items", count);
        logger.error("Failed to process request for user {}", user, new RuntimeException("Test"));
    }
}
```

---

## 4. Java Color Logging Library

**Maven:**
```xml
<dependency>
    <groupId>de.mindmill.logging</groupId>
    <artifactId>java-color-logging</artifactId>
    <version>1.2</version>
</dependency>
```

A convenience library with Spring Boot-inspired ANSI colors for console output.

### Key Features
- Pre-configured with SLF4J and Logback
- Spring Boot-inspired color scheme
- Ready to use out of the box

---

## 5. ANSI Console (Custom Colors)

For full control over colors, you can use ANSI escape codes directly.

### Example with ANSI Colors
```java
public class ColorLogger {
    // ANSI color codes
    public static final String RESET = "\u001B[0m";
    public static final String RED = "\u001B[31m";
    public static final String GREEN = "\u001B[32m";
    public static final String YELLOW = "\u001B[33m";
    public static final String BLUE = "\u001B[34m";
    public static final String PURPLE = "\u001B[35m";
    public static final String CYAN = "\u001B[36m";
    public static final String WHITE = "\u001B[37m";

    // Bold colors
    public static final String BOLD_RED = "\u001B[1;31m";
    public static final String BOLD_GREEN = "\u001B[1;32m";

    // Background colors
    public static final String BG_RED = "\u001B[41m";
    public static final String BG_GREEN = "\u001B[42m";

    public static void info(String message) {
        System.out.println(GREEN + "ℹ INFO: " + message + RESET);
    }

    public static void warn(String message) {
        System.out.println(YELLOW + "⚠ WARN: " + message + RESET);
    }

    public static void error(String message) {
        System.out.println(RED + "✖ ERROR: " + message + RESET);
    }

    public static void success(String message) {
        System.out.println(BOLD_GREEN + "✔ SUCCESS: " + message + RESET);
    }

    public static void debug(String message) {
        System.out.println(CYAN + "🔍 DEBUG: " + message + RESET);
    }

    public static void main(String[] args) {
        info("Application started");
        debug("Loading configuration...");
        success("Configuration loaded");
        warn("Using deprecated API");
        error("Connection failed!");
    }
}
```

---

## 6. Jansi (Cross-Platform ANSI Support)

**Maven:**
```xml
<dependency>
    <groupId>org.fusesource.jansi</groupId>
    <artifactId>jansi</artifactId>
    <version>2.4.1</version>
</dependency>
```

Jansi provides ANSI escape sequence support for Windows.

### Example
```java
import org.fusesource.jansi.Ansi;
import org.fusesource.jansi.AnsiConsole;

import static org.fusesource.jansi.Ansi.ansi;

public class JansiExample {
    public static void main(String[] args) {
        AnsiConsole.systemInstall();

        System.out.println(ansi().fg(Ansi.Color.GREEN).a("Green text").reset());
        System.out.println(ansi().fg(Ansi.Color.RED).bold().a("Bold red text").reset());
        System.out.println(ansi().bg(Ansi.Color.YELLOW).fg(Ansi.Color.BLACK).a("Black on yellow").reset());

        // With emojis
        System.out.println(ansi().fg(Ansi.Color.GREEN).a("✔ Success!").reset());
        System.out.println(ansi().fg(Ansi.Color.RED).a("✖ Error!").reset());
        System.out.println(ansi().fg(Ansi.Color.YELLOW).a("⚠ Warning!").reset());

        AnsiConsole.systemUninstall();
    }
}
```

---

## Quick Comparison

| Library | Colors | Performance | Structured | Best For |
|---------|--------|-------------|------------|----------|
| Logback | ⭐⭐⭐⭐ | Fast | ✅ | Spring Boot apps |
| Log4j2 | ⭐⭐⭐⭐ | Very Fast | ✅ | High-performance |
| SLF4J | N/A | N/A | ✅ | Abstraction layer |
| Jansi | ⭐⭐⭐⭐⭐ | Fast | ❌ | Windows support |
| Custom ANSI | ⭐⭐⭐⭐⭐ | Fast | ❌ | Full control |

## Recommendation

**For Spring Boot:** Use **Logback** (it's the default) with the `%highlight()` pattern converter.

**For high-performance apps:** Use **Log4j2** with async appenders.

**For cross-platform CLI:** Use **Jansi** for proper Windows ANSI support.

## Sources

- [Better Stack: Best Java Logging Libraries](https://betterstack.com/community/guides/logging/best-java-logging-libraries/)
- [Sematext: Java Logging Frameworks Comparison](https://sematext.com/blog/java-logging-frameworks/)
- [GitHub: java-color-logging](https://github.com/mindmill/java-color-logging)
- [Logback Color Support](https://logback.qos.ch/manual/layouts.html#coloring)
