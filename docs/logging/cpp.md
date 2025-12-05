# C++ Logging Libraries

A comprehensive guide to the most popular logging libraries for C++, with a focus on colorful console output.

## 1. spdlog

**Install:**
```bash
# vcpkg
vcpkg install spdlog

# Conan
conan install spdlog/1.12.0@

# apt (Ubuntu/Debian)
sudo apt install libspdlog-dev

# brew (macOS)
brew install spdlog
```
**GitHub Stars:** ~23k+

The most popular C++ logging library with excellent color support.

### Key Features
- Very fast performance
- Header-only option
- Colorful console output
- Multiple sinks (file, rotating, daily)
- Async logging support

### Example
```cpp
#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>

int main() {
    // Create color console logger
    auto console = spdlog::stdout_color_mt("console");

    // Set log level
    console->set_level(spdlog::level::debug);

    // Set pattern with colors
    console->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] [%n] %v");

    // Basic logging with colors
    console->trace("Trace message");      // No color
    console->debug("Debug message");      // Cyan
    console->info("Info message");        // Green
    console->warn("Warning message");     // Yellow
    console->error("Error message");      // Red
    console->critical("Critical error");  // Bold red

    // With arguments
    console->info("User {} logged in", "alice");
    console->info("Processing {} items", 42);

    // Default logger
    spdlog::set_default_logger(console);
    spdlog::info("Using default logger");

    return 0;
}
```

### Custom Colors
```cpp
#include <spdlog/spdlog.h>
#include <spdlog/sinks/stdout_color_sinks.h>

int main() {
    auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();

    // Custom colors for each level
    console_sink->set_color(spdlog::level::trace, console_sink->white);
    console_sink->set_color(spdlog::level::debug, console_sink->cyan);
    console_sink->set_color(spdlog::level::info, console_sink->green);
    console_sink->set_color(spdlog::level::warn, console_sink->yellow_bold);
    console_sink->set_color(spdlog::level::err, console_sink->red_bold);
    console_sink->set_color(spdlog::level::critical, console_sink->bold_on_red);

    auto logger = std::make_shared<spdlog::logger>("custom", console_sink);
    spdlog::register_logger(logger);

    logger->info("Custom colored logger");

    return 0;
}
```

---

## 2. glog (Google Logging)

**Install:**
```bash
# vcpkg
vcpkg install glog

# apt (Ubuntu/Debian)
sudo apt install libgoogle-glog-dev

# brew (macOS)
brew install glog
```
**GitHub Stars:** ~7k+

Google's logging library with crash handling.

### Key Features
- Crash signal handling
- Conditional logging
- Log severity levels
- Log to file and console

### Example
```cpp
#include <glog/logging.h>

int main(int argc, char* argv[]) {
    // Initialize Google Logging
    google::InitGoogleLogging(argv[0]);

    // Log to stderr for colorful output
    FLAGS_logtostderr = true;
    FLAGS_colorlogtostderr = true;

    // Basic logging
    LOG(INFO) << "Info message";       // Default color
    LOG(WARNING) << "Warning message"; // Yellow
    LOG(ERROR) << "Error message";     // Red

    // Conditional logging
    int count = 42;
    LOG_IF(INFO, count > 10) << "Count is greater than 10";

    // Every N occurrences
    for (int i = 0; i < 100; i++) {
        LOG_EVERY_N(INFO, 10) << "Log every 10 iterations: " << i;
    }

    // With stream formatting
    LOG(INFO) << "User: " << "alice" << ", Items: " << 42;

    // Debug logging (only in debug builds)
    DLOG(INFO) << "Debug-only message";

    // Verbose logging
    VLOG(1) << "Verbose level 1";
    VLOG(2) << "Verbose level 2";

    return 0;
}
```

---

## 3. plog

**Install:**
```bash
# Header-only, just download
git clone https://github.com/SergiusTheBest/plog.git
```
**GitHub Stars:** ~2k+

A portable, simple, and extensible C++ logging library.

### Key Features
- Header-only
- Small and portable
- Colorful console output
- Cross-platform

### Example
```cpp
#include <plog/Log.h>
#include <plog/Initializers/RollingFileInitializer.h>
#include <plog/Initializers/ConsoleInitializer.h>
#include <plog/Appenders/ColorConsoleAppender.h>
#include <plog/Formatters/TxtFormatter.h>

int main() {
    // Initialize with color console
    static plog::ColorConsoleAppender<plog::TxtFormatter> consoleAppender;
    plog::init(plog::debug, &consoleAppender);

    // Basic logging with colors
    PLOG_VERBOSE << "Verbose message";
    PLOG_DEBUG << "Debug message";
    PLOG_INFO << "Info message";
    PLOG_WARNING << "Warning message";
    PLOG_ERROR << "Error message";
    PLOG_FATAL << "Fatal message";

    // With formatting
    PLOG_INFO << "User: " << "alice" << ", Items: " << 42;

    // Conditional
    int count = 42;
    PLOG_INFO_IF(count > 10) << "Count is " << count;

    return 0;
}
```

---

## 4. Boost.Log (with Console Formatting)

**Install:**
```bash
# vcpkg
vcpkg install boost-log

# apt (Ubuntu/Debian)
sudo apt install libboost-log-dev
```

Boost's comprehensive logging library.

### Example
```cpp
#include <boost/log/trivial.hpp>
#include <boost/log/expressions.hpp>
#include <boost/log/utility/setup/console.hpp>
#include <boost/log/utility/setup/common_attributes.hpp>

namespace logging = boost::log;

int main() {
    // Setup console logging
    logging::add_console_log(
        std::cout,
        logging::keywords::format = "[%TimeStamp%] [%Severity%] %Message%"
    );

    logging::add_common_attributes();
    logging::core::get()->set_filter(
        logging::trivial::severity >= logging::trivial::debug
    );

    // Basic logging
    BOOST_LOG_TRIVIAL(trace) << "Trace message";
    BOOST_LOG_TRIVIAL(debug) << "Debug message";
    BOOST_LOG_TRIVIAL(info) << "Info message";
    BOOST_LOG_TRIVIAL(warning) << "Warning message";
    BOOST_LOG_TRIVIAL(error) << "Error message";
    BOOST_LOG_TRIVIAL(fatal) << "Fatal message";

    return 0;
}
```

---

## 5. rang (Terminal Colors)

**Install:**
```bash
# Header-only, just download
# https://github.com/agauniyal/rang

# Or with vcpkg
vcpkg install rang
```
**GitHub Stars:** ~1.5k+

A minimal, header-only library for terminal colors.

### Key Features
- Header-only
- Very simple API
- Cross-platform
- Great for custom loggers

### Example
```cpp
#include "rang.hpp"
#include <iostream>
#include <iomanip>
#include <ctime>

// Basic colors
int main() {
    using namespace rang;

    std::cout << fg::red << "Red text" << style::reset << std::endl;
    std::cout << fg::green << "Green text" << style::reset << std::endl;
    std::cout << fg::yellow << "Yellow text" << style::reset << std::endl;
    std::cout << fg::blue << "Blue text" << style::reset << std::endl;

    // With styles
    std::cout << style::bold << fg::red << "Bold red" << style::reset << std::endl;
    std::cout << style::underline << "Underlined" << style::reset << std::endl;

    // Background colors
    std::cout << bg::red << fg::white << " White on red " << style::reset << std::endl;

    return 0;
}

// Custom Logger with rang
class ColorLogger {
public:
    void debug(const std::string& msg) {
        log(rang::fg::cyan, "DEBUG", "🔍", msg);
    }

    void info(const std::string& msg) {
        log(rang::fg::blue, "INFO", "ℹ️", msg);
    }

    void success(const std::string& msg) {
        log(rang::fg::green, "SUCCESS", "✅", msg);
    }

    void warn(const std::string& msg) {
        log(rang::fg::yellow, "WARN", "⚠️", msg);
    }

    void error(const std::string& msg) {
        log(rang::fg::red, "ERROR", "❌", msg);
    }

private:
    void log(rang::fg color, const std::string& level,
             const std::string& emoji, const std::string& msg) {
        auto now = std::time(nullptr);
        std::cout << rang::fg::gray << "[" << std::put_time(std::localtime(&now), "%H:%M:%S") << "] "
                  << rang::style::reset
                  << color << emoji << " [" << level << "] "
                  << rang::style::reset
                  << msg << std::endl;
    }
};

// Usage
int main() {
    ColorLogger logger;
    logger.debug("Loading configuration...");
    logger.info("Server starting on port 8080");
    logger.success("Database connected");
    logger.warn("High memory usage");
    logger.error("Connection failed");
    return 0;
}
```

---

## 6. Custom ANSI Logger

Build your own simple colorful logger.

### Example
```cpp
#include <iostream>
#include <string>
#include <chrono>
#include <iomanip>

class SimpleColorLogger {
public:
    // ANSI color codes
    static constexpr const char* RESET = "\033[0m";
    static constexpr const char* RED = "\033[31m";
    static constexpr const char* GREEN = "\033[32m";
    static constexpr const char* YELLOW = "\033[33m";
    static constexpr const char* BLUE = "\033[34m";
    static constexpr const char* MAGENTA = "\033[35m";
    static constexpr const char* CYAN = "\033[36m";
    static constexpr const char* BOLD = "\033[1m";
    static constexpr const char* BG_RED = "\033[41m";

    void debug(const std::string& msg) {
        log(CYAN, "DEBUG", msg);
    }

    void info(const std::string& msg) {
        log(GREEN, "INFO", msg);
    }

    void warn(const std::string& msg) {
        log(YELLOW, "WARN", msg);
    }

    void error(const std::string& msg) {
        log(RED, "ERROR", msg);
    }

    void critical(const std::string& msg) {
        std::cout << BG_RED << BOLD << "[" << getTimestamp() << "] [CRITICAL] " << msg << RESET << std::endl;
    }

private:
    std::string getTimestamp() {
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss;
        ss << std::put_time(std::localtime(&time), "%H:%M:%S");
        return ss.str();
    }

    void log(const char* color, const std::string& level, const std::string& msg) {
        std::cout << color << "[" << getTimestamp() << "] [" << level << "] " << msg << RESET << std::endl;
    }
};

int main() {
    SimpleColorLogger logger;

    logger.debug("Debug message");
    logger.info("Info message");
    logger.warn("Warning message");
    logger.error("Error message");
    logger.critical("Critical error!");

    return 0;
}
```

---

## Quick Comparison

| Library | Colors | Performance | Features | Best For |
|---------|--------|-------------|----------|----------|
| spdlog | ⭐⭐⭐⭐⭐ | Fast | Full-featured | Production |
| glog | ⭐⭐⭐⭐ | Fast | Crash handling | Google style |
| plog | ⭐⭐⭐⭐ | Fast | Header-only | Portability |
| Boost.Log | ⭐⭐⭐ | Medium | Comprehensive | Boost users |
| rang | ⭐⭐⭐⭐⭐ | N/A | Colors only | Custom loggers |

## Recommendation

**For most projects:** Use **spdlog** - it's fast, popular, and has excellent color support.

**For Google-style projects:** Use **glog** - it has crash handling and good logging patterns.

**For minimal dependencies:** Use **plog** or **rang** - both are header-only and easy to integrate.

## Sources

- [spdlog GitHub](https://github.com/gabime/spdlog)
- [glog GitHub](https://github.com/google/glog)
- [plog GitHub](https://github.com/SergiusTheBest/plog)
- [rang GitHub](https://github.com/agauniyal/rang)
- [C++ Logging Libraries Comparison](https://c-and-beyond.hashnode.dev/top-c-logging-libraries-compared-how-to-choose-the-best-one-part-0)
