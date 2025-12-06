# Kotlin Logging Libraries

A comprehensive guide to the most popular logging libraries for Kotlin (JVM and Android), with a focus on colorful console output.

## 1. Timber (Android)

**Gradle:**
```kotlin
implementation("com.jakewharton.timber:timber:5.0.1")
```
**GitHub Stars:** ~10k+

Timber is Jake Wharton's popular logging library for Android.

### Key Features
- Automatic tag generation from class name
- "Trees" for controlling log output
- Easy to enable/disable for debug/release
- Extensible with custom trees

### Example
```kotlin
import timber.log.Timber

// Initialize in Application class
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
    }
}

// Usage - no tag needed!
Timber.d("Debug message")
Timber.i("Info message")
Timber.w("Warning message")
Timber.e("Error message")

// With formatting
Timber.d("User %s logged in with %d items", "alice", 42)

// With exception
try {
    throw RuntimeException("Something went wrong")
} catch (e: Exception) {
    Timber.e(e, "Error occurred")
}

// With custom tag
Timber.tag("CustomTag").d("Message with custom tag")
```

### Custom Colorful Tree
```kotlin
class ColorDebugTree : Timber.DebugTree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        val color = when (priority) {
            Log.VERBOSE -> "\u001B[37m"  // White
            Log.DEBUG -> "\u001B[36m"    // Cyan
            Log.INFO -> "\u001B[32m"     // Green
            Log.WARN -> "\u001B[33m"     // Yellow
            Log.ERROR -> "\u001B[31m"    // Red
            else -> "\u001B[0m"
        }
        val reset = "\u001B[0m"
        super.log(priority, tag, "$color$message$reset", t)
    }
}
```

---

## 2. Napier (Kotlin Multiplatform)

**Gradle:**
```kotlin
implementation("io.github.aakira:napier:2.7.1")
```
**GitHub Stars:** ~600+

Napier is a logging library for Kotlin Multiplatform.

### Key Features
- Kotlin Multiplatform support (Android, iOS, JVM, JS)
- Automatic platform-specific output
- Antilog for crash reporting integration
- Debug and release configurations

### Example
```kotlin
import io.github.aakira.napier.Napier
import io.github.aakira.napier.DebugAntilog

// Initialize
Napier.base(DebugAntilog())

// Basic logging
Napier.v("Verbose message")
Napier.d("Debug message")
Napier.i("Info message")
Napier.w("Warning message")
Napier.e("Error message")
Napier.wtf("What a Terrible Failure")

// With tag
Napier.d("Message", tag = "MyTag")

// With exception
try {
    throw RuntimeException("Error!")
} catch (e: Exception) {
    Napier.e("Error occurred", e)
}

// With formatting
Napier.d { "Lazy message: ${expensiveComputation()}" }
```

### iOS Setup
```swift
// In iOS code
NapierProxyKt.debugBuild()
```

---

## 3. kotlin-logging

**Gradle:**
```kotlin
implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
implementation("ch.qos.logback:logback-classic:1.4.11")
```
**GitHub Stars:** ~2.5k+

A lightweight logging facade for Kotlin.

### Key Features
- Thin wrapper around SLF4J
- Lazy message evaluation
- Idiomatic Kotlin API
- Works with any SLF4J backend

### Example
```kotlin
import mu.KotlinLogging

private val logger = KotlinLogging.logger {}

class MyClass {
    fun doSomething() {
        logger.debug { "Debug message" }
        logger.info { "Info message" }
        logger.warn { "Warning message" }
        logger.error { "Error message" }

        // With exception
        try {
            throw RuntimeException("Error!")
        } catch (e: Exception) {
            logger.error(e) { "Error occurred" }
        }

        // Lazy evaluation - only computed if level is enabled
        logger.debug { "Expensive computation: ${expensiveOperation()}" }
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

## 4. TimberKt (Kotlin Extensions for Timber)

**Gradle:**
```kotlin
implementation("com.github.ajalt:timberkt:1.5.1")
```

Kotlin-friendly extensions for Timber.

### Key Features
- Lambda-based API for lazy evaluation
- More idiomatic Kotlin syntax
- Built on top of Timber

### Example
```kotlin
import com.github.ajalt.timberkt.Timber
import com.github.ajalt.timberkt.d
import com.github.ajalt.timberkt.e
import com.github.ajalt.timberkt.i
import com.github.ajalt.timberkt.w

// Initialize
Timber.plant(Timber.DebugTree())

// Lambda syntax - only evaluated if logging is enabled
d { "Debug message" }
i { "Info message" }
w { "Warning message" }
e { "Error message" }

// With exception
try {
    throw RuntimeException("Error!")
} catch (e: Exception) {
    e(e) { "Error occurred" }
}

// Lazy evaluation
d { "User: ${fetchUser()}" }  // fetchUser() only called if DEBUG enabled
```

---

## 5. Kermit (Kotlin Multiplatform)

**Gradle:**
```kotlin
implementation("co.touchlab:kermit:2.0.2")
```
**GitHub Stars:** ~700+

A Kotlin Multiplatform logging library from Touchlab.

### Key Features
- Kotlin Multiplatform (Android, iOS, JVM, JS, Native)
- Crashlytics integration
- Configurable log writers
- Tag-based logging

### Example
```kotlin
import co.touchlab.kermit.Logger
import co.touchlab.kermit.Severity

// Basic logging
Logger.d { "Debug message" }
Logger.i { "Info message" }
Logger.w { "Warning message" }
Logger.e { "Error message" }

// With tag
Logger.withTag("Network").i { "Request started" }

// Create tagged logger
val logger = Logger.withTag("MyClass")
logger.d { "Debug from MyClass" }

// With exception
try {
    throw RuntimeException("Error!")
} catch (e: Exception) {
    Logger.e(e) { "Error occurred" }
}

// Configuration
Logger.setMinSeverity(Severity.Debug)
Logger.setTag("AppName")
```

---

## 6. Custom Colored Logger

Create your own colorful logger for JVM/Android terminal output.

### Example
```kotlin
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

object ColorLogger {
    // ANSI color codes
    private const val RESET = "\u001B[0m"
    private const val RED = "\u001B[31m"
    private const val GREEN = "\u001B[32m"
    private const val YELLOW = "\u001B[33m"
    private const val BLUE = "\u001B[34m"
    private const val MAGENTA = "\u001B[35m"
    private const val CYAN = "\u001B[36m"
    private const val BOLD = "\u001B[1m"

    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss.SSS")

    fun debug(message: String) = log(CYAN, "DEBUG", "🔍", message)
    fun info(message: String) = log(BLUE, "INFO", "ℹ️", message)
    fun success(message: String) = log(GREEN, "SUCCESS", "✅", message)
    fun warn(message: String) = log(YELLOW, "WARN", "⚠️", message)
    fun error(message: String) = log(RED, "ERROR", "❌", message)
    fun fatal(message: String) = log("$BOLD$RED", "FATAL", "💀", message)

    private fun log(color: String, level: String, emoji: String, message: String) {
        val timestamp = LocalDateTime.now().format(timeFormatter)
        println("$color[$timestamp] $emoji [$level] $message$RESET")
    }

    fun error(message: String, throwable: Throwable) {
        error(message)
        println("$RED${throwable.stackTraceToString()}$RESET")
    }
}

// Usage
fun main() {
    ColorLogger.debug("Loading configuration...")
    ColorLogger.info("Server starting on port 8080")
    ColorLogger.success("Database connected")
    ColorLogger.warn("High memory usage detected")
    ColorLogger.error("Connection timeout")

    try {
        throw RuntimeException("Something went wrong!")
    } catch (e: Exception) {
        ColorLogger.error("An error occurred", e)
    }
}
```

### Android Logcat with Emojis
```kotlin
object EmojiLogger {
    private const val TAG = "MyApp"

    fun d(message: String) = Log.d(TAG, "🔍 $message")
    fun i(message: String) = Log.i(TAG, "ℹ️ $message")
    fun w(message: String) = Log.w(TAG, "⚠️ $message")
    fun e(message: String) = Log.e(TAG, "❌ $message")
    fun success(message: String) = Log.i(TAG, "✅ $message")
    fun network(message: String) = Log.d(TAG, "🌐 $message")
    fun database(message: String) = Log.d(TAG, "💾 $message")
}

// Usage
EmojiLogger.network("Fetching user data...")
EmojiLogger.success("User data loaded")
EmojiLogger.database("Saving to cache")
```

---

## Quick Comparison

| Library | Colors | Platform | Features | Best For |
|---------|--------|----------|----------|----------|
| Timber | ⭐⭐⭐ | Android | Simple, popular | Android apps |
| Napier | ⭐⭐⭐ | Multiplatform | KMP support | Cross-platform |
| kotlin-logging | ⭐⭐⭐⭐ | JVM | SLF4J wrapper | JVM backend |
| Kermit | ⭐⭐⭐ | Multiplatform | Crashlytics | KMP with crashes |
| Custom | ⭐⭐⭐⭐⭐ | Any | Full control | Specific needs |

## Recommendation

**For Android:** Use **Timber** - it's the de facto standard with excellent developer experience.

**For Kotlin Multiplatform:** Use **Napier** or **Kermit** - both provide great KMP support.

**For JVM backend:** Use **kotlin-logging** with **Logback** - it provides colored console output via Logback configuration.

## Sources

- [Timber GitHub](https://github.com/JakeWharton/timber)
- [Napier GitHub](https://github.com/AAkira/Napier)
- [kotlin-logging GitHub](https://github.com/MicroUtils/kotlin-logging)
- [Kermit GitHub](https://github.com/touchlab/Kermit)
- [TimberKt GitHub](https://github.com/ajalt/timberkt)
