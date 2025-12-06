# Swift Logging Libraries

A comprehensive guide to the most popular logging libraries for Swift, with a focus on colorful console output.

## 1. XCGLogger

**Swift Package Manager:**
```swift
.package(url: "https://github.com/DaveWoodCom/XCGLogger.git", from: "7.0.0")
```
**GitHub Stars:** ~3.9k

The original debug log framework for Swift.

### Key Features
- Multiple log levels
- Colored console output
- File, function, and line number in logs
- Multiple destinations (console, file, custom)
- Customizable formatters

### Example
```swift
import XCGLogger

// Create logger
let log = XCGLogger.default

// Setup with colors
log.setup(
    level: .debug,
    showLogIdentifier: false,
    showFunctionName: true,
    showThreadName: true,
    showLevel: true,
    showFileNames: true,
    showLineNumbers: true,
    showDate: true,
    writeToFile: nil
)

// Basic logging
log.verbose("Verbose message")    // Purple
log.debug("Debug message")        // Blue
log.info("Info message")          // Green
log.notice("Notice message")      // Gray
log.warning("Warning message")    // Yellow
log.error("Error message")        // Red
log.severe("Severe message")      // Red bold
log.alert("Alert message")        // Red background
log.emergency("Emergency!")       // Red background

// With custom data
log.info("User logged in", userInfo: ["username": "alice", "ip": "192.168.1.1"])

// Conditional logging
log.debug("Debug only in debug builds", functionName: #function, fileName: #file, lineNumber: #line)
```

### Custom Color Configuration
```swift
import XCGLogger

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

// Create colored console destination
let consoleDestination = ConsoleDestination(identifier: XCGLogger.Constants.baseConsoleDestinationIdentifier)
consoleDestination.outputLevel = .debug
consoleDestination.showLogIdentifier = false
consoleDestination.showFunctionName = true
consoleDestination.showThreadName = false
consoleDestination.showLevel = true
consoleDestination.showFileName = true
consoleDestination.showLineNumber = true
consoleDestination.showDate = true

log.add(destination: consoleDestination)
```

---

## 2. SwiftLog (Apple's Official Logging API)

**Swift Package Manager:**
```swift
.package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
```

Apple's official logging API for server-side Swift.

### Key Features
- Standard logging API
- Multiple backends
- Metadata support
- Production-ready

### Example
```swift
import Logging

// Create a logger
var logger = Logger(label: "com.example.myapp")
logger.logLevel = .debug

// Basic logging
logger.trace("Trace message")
logger.debug("Debug message")
logger.info("Info message")
logger.notice("Notice message")
logger.warning("Warning message")
logger.error("Error message")
logger.critical("Critical message")

// With metadata
logger[metadataKey: "request-id"] = "abc123"
logger.info("Processing request")

// One-off metadata
logger.info("User action", metadata: ["user": "alice", "action": "login"])
```

### With swift-log-console-colors (Colorful Backend)
```swift
// Add package: https://github.com/nneuberger1/swift-log-console-colors

import Logging
import LoggingConsoleColors

// Bootstrap with colors
LoggingSystem.bootstrap { label in
    var handler = ColorStreamLogHandler.standardOutput(label: label)
    handler.logLevel = .debug
    return handler
}

var logger = Logger(label: "com.example.app")
logger.debug("Debug message")   // Colored output!
logger.info("Info message")
logger.error("Error message")
```

---

## 3. CocoaLumberjack

**Swift Package Manager:**
```swift
.package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0")
```
**CocoaPods:**
```ruby
pod 'CocoaLumberjack/Swift'
```
**GitHub Stars:** ~13k+

The most popular logging framework for Apple platforms.

### Key Features
- Extremely fast (faster than NSLog)
- Multiple loggers
- Async logging
- Color support via Xcode plugin
- File logging with rotation

### Example
```swift
import CocoaLumberjack

// Configure DDLog
DDLog.add(DDOSLogger.sharedInstance) // Uses os_log
DDLog.add(DDTTYLogger.sharedInstance!) // Xcode console

// Set log level
dynamicLogLevel = .verbose

// Basic logging
DDLogVerbose("Verbose message")
DDLogDebug("Debug message")
DDLogInfo("Info message")
DDLogWarn("Warning message")
DDLogError("Error message")

// With context
DDLogInfo("User logged in", context: 1)

// Conditional logging
#if DEBUG
DDLogDebug("Debug-only message")
#endif
```

### Color Configuration
```swift
import CocoaLumberjack

// For terminal output (when not in Xcode)
if let ttyLogger = DDTTYLogger.sharedInstance {
    ttyLogger.colorsEnabled = true

    // Custom colors
    ttyLogger.setForegroundColor(DDMakeColor(255, 0, 0), backgroundColor: nil, for: .error)
    ttyLogger.setForegroundColor(DDMakeColor(255, 165, 0), backgroundColor: nil, for: .warning)
    ttyLogger.setForegroundColor(DDMakeColor(0, 255, 0), backgroundColor: nil, for: .info)
    ttyLogger.setForegroundColor(DDMakeColor(0, 255, 255), backgroundColor: nil, for: .debug)

    DDLog.add(ttyLogger)
}
```

---

## 4. os.log / Logger (Apple's Built-in)

**Built into iOS 14+ / macOS 11+**

Apple's native unified logging system.

### Key Features
- Native to Apple platforms
- Great performance
- Privacy controls
- Integrates with Console.app

### Example
```swift
import os.log

// Create logger (iOS 14+)
let logger = Logger(subsystem: "com.example.myapp", category: "network")

// Basic logging
logger.trace("Trace message")
logger.debug("Debug message")
logger.info("Info message")
logger.notice("Notice message")
logger.warning("Warning message")
logger.error("Error message")
logger.critical("Critical message")

// With privacy controls
let username = "alice"
logger.info("User logged in: \(username, privacy: .private)")
logger.info("Request count: \(42, privacy: .public)")

// Legacy os_log (iOS 10+)
import os

let log = OSLog(subsystem: "com.example.myapp", category: "general")
os_log("Info message", log: log, type: .info)
os_log("Error: %{public}@", log: log, type: .error, "Something failed")
```

---

## 5. Pulse (Visual Logging)

**Swift Package Manager:**
```swift
.package(url: "https://github.com/kean/Pulse", from: "4.0.0")
```
**GitHub Stars:** ~6k+

A powerful logging system with a built-in UI.

### Key Features
- Beautiful in-app log viewer
- Network request logging
- Share logs easily
- Remote logging support

### Example
```swift
import Pulse
import Logging

// Bootstrap Pulse as SwiftLog backend
LoggingSystem.bootstrap(PersistentLogHandler.init)

let logger = Logger(label: "com.example.app")

logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")

// View logs in-app
import PulseUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationLink("View Logs") {
            ConsoleView()
        }
    }
}
```

---

## 6. Custom Colored Logger

Create your own simple colored logger for terminal output.

### Example
```swift
import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARN"
    case error = "ERROR"
}

struct ColorLogger {
    // ANSI color codes
    static let reset = "\u{001B}[0m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let bold = "\u{001B}[1m"

    static func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = URL(fileURLWithPath: file).lastPathComponent

        let color: String
        let emoji: String

        switch level {
        case .debug:
            color = cyan
            emoji = "🔍"
        case .info:
            color = blue
            emoji = "ℹ️"
        case .success:
            color = green
            emoji = "✅"
        case .warning:
            color = yellow
            emoji = "⚠️"
        case .error:
            color = red
            emoji = "❌"
        }

        print("\(color)[\(timestamp)] \(emoji) [\(level.rawValue)] \(filename):\(line) - \(message)\(reset)")
    }

    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(.debug, message, file: file, line: line)
    }

    static func info(_ message: String, file: String = #file, line: Int = #line) {
        log(.info, message, file: file, line: line)
    }

    static func success(_ message: String, file: String = #file, line: Int = #line) {
        log(.success, message, file: file, line: line)
    }

    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        log(.warning, message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #file, line: Int = #line) {
        log(.error, message, file: file, line: line)
    }
}

// Usage
ColorLogger.debug("Loading configuration...")
ColorLogger.info("Server starting on port 8080")
ColorLogger.success("Connected to database")
ColorLogger.warning("High memory usage")
ColorLogger.error("Connection timeout")
```

---

## Quick Comparison

| Library | Colors | Platform | Features | Best For |
|---------|--------|----------|----------|----------|
| XCGLogger | ⭐⭐⭐⭐ | All | Full-featured | General use |
| SwiftLog | ⭐⭐⭐ | All | Standard API | Server-side |
| CocoaLumberjack | ⭐⭐⭐⭐ | Apple | Fast, mature | Production |
| os.log | ⭐⭐⭐ | Apple | Native | Apple apps |
| Pulse | ⭐⭐⭐⭐⭐ | Apple | Visual UI | Debugging |

## Recommendation

**For iOS/macOS apps:** Use **CocoaLumberjack** or **os.log** - they're battle-tested and performant.

**For server-side Swift:** Use **SwiftLog** with a colorful backend like swift-log-console-colors.

**For debugging:** Use **Pulse** - it has an amazing in-app log viewer.

**Note:** Xcode's console has limited color support. Colors work best when running from Terminal.

## Sources

- [XCGLogger GitHub](https://github.com/DaveWoodCom/XCGLogger)
- [Swift Package Index: XCGLogger](https://swiftpackageindex.com/DaveWoodCom/XCGLogger)
- [CocoaLumberjack GitHub](https://github.com/CocoaLumberjack/CocoaLumberjack)
- [swift-log GitHub](https://github.com/apple/swift-log)
- [swift-log-console-colors GitHub](https://github.com/nneuberger1/swift-log-console-colors)
- [Bugfender: Swift Logging Techniques](https://bugfender.com/blog/swift-logging/)
