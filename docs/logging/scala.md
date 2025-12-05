# Scala Logging Libraries

A comprehensive guide to the most popular logging libraries for Scala, with a focus on colorful console output.

## 1. Airframe-Log (Colorful Logging)

**sbt:**
```scala
libraryDependencies += "org.wvlet.airframe" %% "airframe-log" % "24.1.0"
```

A modern logging library with built-in color support.

### Key Features
- ANSI colored logging by default
- Source code location display
- Scala.js support
- No configuration files needed

### Example
```scala
import wvlet.log.LogSupport
import wvlet.log.Logger

// Using LogSupport trait
class MyApp extends LogSupport {
  def run(): Unit = {
    trace("Trace message")
    debug("Debug message")      // Cyan
    info("Info message")        // Green
    warn("Warning message")     // Yellow
    error("Error message")      // Red

    // With formatted strings
    val user = "alice"
    val count = 42
    info(s"User $user processed $count items")

    // With exception
    try {
      throw new RuntimeException("Something went wrong")
    } catch {
      case e: Exception =>
        error("Error occurred", e)
    }
  }
}

// Direct logger usage
object Main extends App {
  val logger = Logger("MyApp")

  logger.info("Application starting")
  logger.debug("Loading configuration")
  logger.warn("Using default settings")
}

// Configure log level
Logger.setDefaultLogLevel(wvlet.log.LogLevel.DEBUG)
```

### Custom Formatter
```scala
import wvlet.log._

// Enable source code location
Logger.setDefaultFormatter(LogFormatter.SourceCodeLogFormatter)

// Or use colored formatter
Logger.setDefaultFormatter(LogFormatter.TSVLogFormatter)
```

---

## 2. Scribe

**sbt:**
```scala
libraryDependencies += "com.outr" %% "scribe" % "3.13.0"
```
**GitHub Stars:** ~500+

The fastest logging library for Scala, built from scratch.

### Key Features
- Fastest JVM logging library
- Programmatic configuration
- Colorful console output
- SLF4J compatible

### Example
```scala
import scribe._

object MyApp extends App {
  // Basic logging
  scribe.trace("Trace message")
  scribe.debug("Debug message")
  scribe.info("Info message")
  scribe.warn("Warning message")
  scribe.error("Error message")

  // With context
  scribe.info(s"User alice logged in")

  // With exception
  try {
    throw new RuntimeException("Error!")
  } catch {
    case e: Exception =>
      scribe.error("An error occurred", e)
  }
}

// Custom configuration
object ConfiguredApp extends App {
  scribe.Logger.root
    .clearHandlers()
    .withHandler(
      minimumLevel = Some(Level.Debug),
      formatter = scribe.format.Formatter.colored
    )
    .replace()

  scribe.info("Configured logger")
}
```

### With Colors
```scala
import scribe._
import scribe.format._

// Enable colored output
scribe.Logger.root
  .clearHandlers()
  .withHandler(formatter = Formatter.colored)
  .replace()

scribe.info("This will be colored!")
```

---

## 3. scala-logging (with Logback)

**sbt:**
```scala
libraryDependencies ++= Seq(
  "com.typesafe.scala-logging" %% "scala-logging" % "3.9.5",
  "ch.qos.logback" % "logback-classic" % "1.4.11"
)
```
**GitHub Stars:** ~900+

A Scala wrapper around SLF4J.

### Key Features
- Thin wrapper around SLF4J
- Lazy message evaluation
- Works with any SLF4J backend

### Example
```scala
import com.typesafe.scalalogging.LazyLogging
import com.typesafe.scalalogging.Logger

class MyService extends LazyLogging {
  def process(): Unit = {
    logger.trace("Trace message")
    logger.debug("Debug message")
    logger.info("Info message")
    logger.warn("Warning message")
    logger.error("Error message")

    // Lazy evaluation
    logger.debug(s"Expensive computation: ${expensiveOperation()}")

    // With exception
    try {
      throw new RuntimeException("Error!")
    } catch {
      case e: Exception =>
        logger.error("Error occurred", e)
    }
  }

  def expensiveOperation(): String = "result"
}

// Or using StrictLogging for eager initialization
class AnotherService extends com.typesafe.scalalogging.StrictLogging {
  def run(): Unit = {
    logger.info("Running service")
  }
}
```

### Logback Configuration with Colors (logback.xml)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} %highlight(%-5level) %cyan(%logger{36}) - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="DEBUG">
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

---

## 4. Log4cats (for Cats Effect)

**sbt:**
```scala
libraryDependencies += "org.typelevel" %% "log4cats-slf4j" % "2.6.0"
```

Functional logging for Cats Effect.

### Example
```scala
import org.typelevel.log4cats.Logger
import org.typelevel.log4cats.slf4j.Slf4jLogger
import cats.effect._

object MyApp extends IOApp.Simple {
  implicit val logger: Logger[IO] = Slf4jLogger.getLogger[IO]

  def run: IO[Unit] = for {
    _ <- logger.debug("Debug message")
    _ <- logger.info("Info message")
    _ <- logger.warn("Warning message")
    _ <- logger.error("Error message")
    result <- processData
    _ <- logger.info(s"Result: $result")
  } yield ()

  def processData: IO[String] = IO.pure("data")
}
```

---

## 5. Custom Colorful Logger

Build your own colorful logger for Scala.

### Example
```scala
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

object ColorLogger {
  // ANSI color codes
  private val RESET = "\u001B[0m"
  private val RED = "\u001B[31m"
  private val GREEN = "\u001B[32m"
  private val YELLOW = "\u001B[33m"
  private val BLUE = "\u001B[34m"
  private val MAGENTA = "\u001B[35m"
  private val CYAN = "\u001B[36m"
  private val BOLD = "\u001B[1m"

  private val formatter = DateTimeFormatter.ofPattern("HH:mm:ss.SSS")

  def trace(message: String): Unit = log(MAGENTA, "TRACE", "🔍", message)
  def debug(message: String): Unit = log(CYAN, "DEBUG", "🐛", message)
  def info(message: String): Unit = log(GREEN, "INFO", "ℹ️", message)
  def success(message: String): Unit = log(s"$BOLD$GREEN", "SUCCESS", "✅", message)
  def warn(message: String): Unit = log(YELLOW, "WARN", "⚠️", message)
  def error(message: String): Unit = log(RED, "ERROR", "❌", message)
  def fatal(message: String): Unit = log(s"$BOLD$RED", "FATAL", "💀", message)

  def error(message: String, throwable: Throwable): Unit = {
    error(message)
    println(s"$RED${throwable.getMessage}$RESET")
    throwable.getStackTrace.foreach(line => println(s"$RED  at $line$RESET"))
  }

  private def log(color: String, level: String, emoji: String, message: String): Unit = {
    val timestamp = LocalDateTime.now().format(formatter)
    println(s"$color[$timestamp] $emoji [$level] $message$RESET")
  }
}

// Usage
object Main extends App {
  ColorLogger.trace("Trace message")
  ColorLogger.debug("Loading configuration...")
  ColorLogger.info("Server starting on port 8080")
  ColorLogger.success("Database connected")
  ColorLogger.warn("High memory usage")
  ColorLogger.error("Connection failed")
  ColorLogger.fatal("System crash!")

  try {
    throw new RuntimeException("Something went wrong!")
  } catch {
    case e: Exception =>
      ColorLogger.error("An error occurred", e)
  }
}
```

### Trait-based Logger
```scala
trait ColorLogging {
  private val name = getClass.getSimpleName

  protected def logDebug(message: String): Unit =
    println(s"\u001B[36m[DEBUG][$name] $message\u001B[0m")

  protected def logInfo(message: String): Unit =
    println(s"\u001B[32m[INFO][$name] $message\u001B[0m")

  protected def logWarn(message: String): Unit =
    println(s"\u001B[33m[WARN][$name] $message\u001B[0m")

  protected def logError(message: String): Unit =
    println(s"\u001B[31m[ERROR][$name] $message\u001B[0m")
}

class MyService extends ColorLogging {
  def process(): Unit = {
    logDebug("Processing started")
    logInfo("Processing item")
    logWarn("Retrying operation")
    logError("Operation failed")
  }
}
```

---

## 6. Fansi (Terminal Colors)

**sbt:**
```scala
libraryDependencies += "com.lihaoyi" %% "fansi" % "0.4.0"
```

A library for creating ANSI-colored strings.

### Example
```scala
import fansi._

object FansiExample extends App {
  // Basic colors
  println(Color.Red("Red text"))
  println(Color.Green("Green text"))
  println(Color.Yellow("Yellow text"))
  println(Color.Blue("Blue text"))

  // Styles
  println(Bold.On("Bold text"))
  println(Underlined.On("Underlined"))

  // Combinations
  println(Bold.On(Color.Red("Bold red")))
  println(Color.White(Back.Red(" White on red ")))

  // Build custom logger
  def info(msg: String): Unit =
    println(Color.Blue("ℹ️ [INFO] ") ++ Str(msg))

  def success(msg: String): Unit =
    println(Bold.On(Color.Green("✅ [SUCCESS] ")) ++ Str(msg))

  def warn(msg: String): Unit =
    println(Color.Yellow("⚠️ [WARN] ") ++ Str(msg))

  def error(msg: String): Unit =
    println(Bold.On(Color.Red("❌ [ERROR] ")) ++ Str(msg))

  info("Application starting")
  success("Connected to database")
  warn("High memory usage")
  error("Connection timeout")
}
```

---

## Quick Comparison

| Library | Colors | Functional | Performance | Best For |
|---------|--------|------------|-------------|----------|
| Airframe-Log | ⭐⭐⭐⭐⭐ | ❌ | Fast | Easy colored logging |
| Scribe | ⭐⭐⭐⭐ | ❌ | Fastest | High-performance |
| scala-logging | ⭐⭐⭐⭐ | ❌ | Fast | SLF4J users |
| Log4cats | ⭐⭐⭐ | ✅ | Medium | Cats Effect apps |
| Fansi | ⭐⭐⭐⭐⭐ | ❌ | N/A | Custom loggers |

## Recommendation

**For easy colored logging:** Use **Airframe-Log** - it has the best out-of-box color support.

**For high-performance:** Use **Scribe** - it's the fastest pure Scala logger.

**For existing SLF4J projects:** Use **scala-logging** with **Logback** - configure colors via logback.xml.

**For Cats Effect apps:** Use **Log4cats** - it integrates well with the FP ecosystem.

## Sources

- [Airframe-Log Documentation](https://wvlet.org/airframe/docs/airframe-log)
- [Scribe GitHub](https://github.com/outr/scribe)
- [scala-logging GitHub](https://github.com/lightbend-labs/scala-logging)
- [Baeldung: Logging in Scala](https://www.baeldung.com/scala/scala-logging)
- [Fansi GitHub](https://github.com/com-lihaoyi/fansi)
