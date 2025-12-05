# Objective-C Logging Libraries

A comprehensive guide to the most popular logging libraries for Objective-C, with a focus on colorful console output.

## 1. CocoaLumberjack

**CocoaPods:**
```ruby
pod 'CocoaLumberjack'
```
**GitHub Stars:** ~13k+

The most popular logging framework for Apple platforms.

### Key Features
- Faster than NSLog
- Multiple loggers (console, file, custom)
- Color support via XcodeColors
- Log levels and filtering
- Asynchronous logging

### Example
```objective-c
#import <CocoaLumberjack/CocoaLumberjack.h>

// Define log level
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;

@implementation MyClass

- (void)setupLogging {
    // Add console logger (TTY = Xcode console)
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    // Add file logger
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hours
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    [DDLog addLogger:fileLogger];
}

- (void)doSomething {
    DDLogVerbose(@"Verbose message");
    DDLogDebug(@"Debug message");
    DDLogInfo(@"Info message");
    DDLogWarn(@"Warning message");
    DDLogError(@"Error message");

    // With formatting
    NSString *user = @"alice";
    NSInteger count = 42;
    DDLogInfo(@"User %@ processed %ld items", user, (long)count);
}

@end
```

### Color Configuration
```objective-c
#import <CocoaLumberjack/CocoaLumberjack.h>

- (void)setupColoredLogging {
    DDTTYLogger *ttyLogger = [DDTTYLogger sharedInstance];

    // Enable colors
    [ttyLogger setColorsEnabled:YES];

    // Custom colors for each level
    [ttyLogger setForegroundColor:[UIColor cyanColor]
                  backgroundColor:nil
                          forFlag:DDLogFlagDebug];

    [ttyLogger setForegroundColor:[UIColor greenColor]
                  backgroundColor:nil
                          forFlag:DDLogFlagInfo];

    [ttyLogger setForegroundColor:[UIColor yellowColor]
                  backgroundColor:nil
                          forFlag:DDLogFlagWarning];

    [ttyLogger setForegroundColor:[UIColor redColor]
                  backgroundColor:nil
                          forFlag:DDLogFlagError];

    [DDLog addLogger:ttyLogger];
}
```

### Custom Formatter with Emojis
```objective-c
@interface EmojiLogFormatter : NSObject <DDLogFormatter>
@end

@implementation EmojiLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *emoji;
    switch (logMessage.flag) {
        case DDLogFlagError:   emoji = @"❌"; break;
        case DDLogFlagWarning: emoji = @"⚠️"; break;
        case DDLogFlagInfo:    emoji = @"ℹ️"; break;
        case DDLogFlagDebug:   emoji = @"🐛"; break;
        case DDLogFlagVerbose: emoji = @"🔍"; break;
        default:               emoji = @"📝"; break;
    }

    NSString *timestamp = [self formattedTimestamp:logMessage.timestamp];
    return [NSString stringWithFormat:@"[%@] %@ %@",
            timestamp, emoji, logMessage.message];
}

- (NSString *)formattedTimestamp:(NSDate *)date {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss.SSS";
    });
    return [formatter stringFromDate:date];
}

@end

// Usage
DDTTYLogger *ttyLogger = [DDTTYLogger sharedInstance];
ttyLogger.logFormatter = [[EmojiLogFormatter alloc] init];
[DDLog addLogger:ttyLogger];
```

---

## 2. XcodeLogger

**CocoaPods:**
```ruby
pod 'XcodeLogger'
```

A fast, customizable NSLog replacement.

### Key Features
- Up to 6x faster than NSLog
- Colored output
- Filterable by build scheme
- Multiple log levels

### Example
```objective-c
#import "XcodeLogger.h"

@implementation MyClass

- (void)logExamples {
    // Different log levels
    XLog(@"Default log");
    XLog_NH(@"No header log");

    // Colored logs
    XLog_INFO(@"Info message");    // Blue
    XLog_WARN(@"Warning");         // Yellow
    XLog_ERROR(@"Error");          // Red
    XLog_DEBUG(@"Debug");          // Cyan
    XLog_SUCCESS(@"Success");      // Green

    // With formatting
    XLog_INFO(@"User %@ logged in", @"alice");
}

@end
```

---

## 3. NSLog with Colors (Terminal Only)

When running from Terminal (not Xcode), you can use ANSI colors.

### Example
```objective-c
#import <Foundation/Foundation.h>

// ANSI color codes
#define ANSI_RESET   @"\033[0m"
#define ANSI_RED     @"\033[31m"
#define ANSI_GREEN   @"\033[32m"
#define ANSI_YELLOW  @"\033[33m"
#define ANSI_BLUE    @"\033[34m"
#define ANSI_CYAN    @"\033[36m"
#define ANSI_BOLD    @"\033[1m"

// Color logging macros
#define LogDebug(fmt, ...) \
    NSLog(@"%@🔍 [DEBUG] " fmt @"%@", ANSI_CYAN, ##__VA_ARGS__, ANSI_RESET)

#define LogInfo(fmt, ...) \
    NSLog(@"%@ℹ️ [INFO] " fmt @"%@", ANSI_BLUE, ##__VA_ARGS__, ANSI_RESET)

#define LogSuccess(fmt, ...) \
    NSLog(@"%@%@✅ [SUCCESS] " fmt @"%@", ANSI_BOLD, ANSI_GREEN, ##__VA_ARGS__, ANSI_RESET)

#define LogWarn(fmt, ...) \
    NSLog(@"%@⚠️ [WARN] " fmt @"%@", ANSI_YELLOW, ##__VA_ARGS__, ANSI_RESET)

#define LogError(fmt, ...) \
    NSLog(@"%@%@❌ [ERROR] " fmt @"%@", ANSI_BOLD, ANSI_RED, ##__VA_ARGS__, ANSI_RESET)

// Usage
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        LogDebug(@"Loading configuration...");
        LogInfo(@"Application starting");
        LogSuccess(@"Database connected");
        LogWarn(@"High memory usage: %dMB", 512);
        LogError(@"Connection failed: %@", @"timeout");
    }
    return 0;
}
```

---

## 4. os_log (Modern Apple Logging)

Apple's unified logging system (iOS 10+, macOS 10.12+).

### Example
```objective-c
#import <os/log.h>

@interface MyClass ()
@property (nonatomic, strong) os_log_t logger;
@end

@implementation MyClass

- (instancetype)init {
    self = [super init];
    if (self) {
        _logger = os_log_create("com.example.myapp", "general");
    }
    return self;
}

- (void)logExamples {
    os_log_debug(self.logger, "Debug message");
    os_log_info(self.logger, "Info message");
    os_log(self.logger, "Default message");
    os_log_error(self.logger, "Error message");
    os_log_fault(self.logger, "Fault message");

    // With formatting
    NSString *user = @"alice";
    os_log_info(self.logger, "User %{public}@ logged in", user);

    // Private data (redacted in logs)
    os_log_info(self.logger, "Password: %{private}@", @"secret");
}

@end
```

---

## 5. Custom Color Logger Class

Build your own colorful logger.

### ColorLogger.h
```objective-c
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelTrace,
    LogLevelDebug,
    LogLevelInfo,
    LogLevelSuccess,
    LogLevelWarn,
    LogLevelError,
    LogLevelFatal
};

@interface ColorLogger : NSObject

@property (nonatomic, assign) LogLevel minimumLevel;

+ (instancetype)sharedLogger;

- (void)trace:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)debug:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)info:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)success:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)warn:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)error:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (void)fatal:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

@end
```

### ColorLogger.m
```objective-c
#import "ColorLogger.h"

// ANSI codes for terminal
#define ANSI_RESET   @"\033[0m"
#define ANSI_RED     @"\033[31m"
#define ANSI_GREEN   @"\033[32m"
#define ANSI_YELLOW  @"\033[33m"
#define ANSI_BLUE    @"\033[34m"
#define ANSI_MAGENTA @"\033[35m"
#define ANSI_CYAN    @"\033[36m"
#define ANSI_BOLD    @"\033[1m"
#define ANSI_BG_RED  @"\033[41m"
#define ANSI_WHITE   @"\033[37m"

@implementation ColorLogger

+ (instancetype)sharedLogger {
    static ColorLogger *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[ColorLogger alloc] init];
        shared.minimumLevel = LogLevelDebug;
    });
    return shared;
}

- (void)logWithLevel:(LogLevel)level
               color:(NSString *)color
               emoji:(NSString *)emoji
               label:(NSString *)label
              format:(NSString *)format
                args:(va_list)args {

    if (level < self.minimumLevel) return;

    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *timestamp = [self timestamp];

    // For terminal output
    printf("%s[%s] %s [%s] %s%s\n",
           color.UTF8String,
           timestamp.UTF8String,
           emoji.UTF8String,
           label.UTF8String,
           message.UTF8String,
           ANSI_RESET.UTF8String);
}

- (NSString *)timestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    return [formatter stringFromDate:[NSDate date]];
}

- (void)trace:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self logWithLevel:LogLevelTrace color:ANSI_MAGENTA emoji:@"🔍" label:@"TRACE" format:format args:args];
    va_end(args);
}

- (void)debug:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self logWithLevel:LogLevelDebug color:ANSI_CYAN emoji:@"🐛" label:@"DEBUG" format:format args:args];
    va_end(args);
}

- (void)info:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self logWithLevel:LogLevelInfo color:ANSI_BLUE emoji:@"ℹ️" label:@"INFO" format:format args:args];
    va_end(args);
}

- (void)success:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *color = [NSString stringWithFormat:@"%@%@", ANSI_BOLD, ANSI_GREEN];
    [self logWithLevel:LogLevelSuccess color:color emoji:@"✅" label:@"SUCCESS" format:format args:args];
    va_end(args);
}

- (void)warn:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self logWithLevel:LogLevelWarn color:ANSI_YELLOW emoji:@"⚠️" label:@"WARN" format:format args:args];
    va_end(args);
}

- (void)error:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self logWithLevel:LogLevelError color:ANSI_RED emoji:@"❌" label:@"ERROR" format:format args:args];
    va_end(args);
}

- (void)fatal:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *color = [NSString stringWithFormat:@"%@%@%@", ANSI_BOLD, ANSI_BG_RED, ANSI_WHITE];
    [self logWithLevel:LogLevelFatal color:color emoji:@"💀" label:@"FATAL" format:format args:args];
    va_end(args);
}

@end
```

### Usage
```objective-c
ColorLogger *log = [ColorLogger sharedLogger];
log.minimumLevel = LogLevelDebug;

[log trace:@"Trace message"];
[log debug:@"Loading configuration..."];
[log info:@"Server starting on port %d", 8080];
[log success:@"Database connected"];
[log warn:@"High memory usage: %dMB", 512];
[log error:@"Connection failed: %@", @"timeout"];
[log fatal:@"System crash!"];
```

---

## Quick Comparison

| Library | Colors | Performance | Features | Best For |
|---------|--------|-------------|----------|----------|
| CocoaLumberjack | ⭐⭐⭐⭐ | Fast | Full-featured | Production |
| XcodeLogger | ⭐⭐⭐⭐ | Very Fast | Simple | Quick setup |
| os_log | ⭐⭐⭐ | Native | Apple unified | Modern iOS/macOS |
| Custom | ⭐⭐⭐⭐⭐ | Fast | Full control | Terminal apps |

## Recommendation

**For iOS/macOS apps:** Use **CocoaLumberjack** - it's the most feature-rich and widely used.

**For modern Apple platforms:** Use **os_log** - it integrates with Console.app.

**For command-line tools:** Use a **custom ANSI logger** - colors work in Terminal.

## Note on Xcode Console

Xcode 8+ removed support for plugins, so XcodeColors no longer works. Colors will display correctly when:
- Running from Terminal
- Using Console.app for os_log
- Using external terminal emulators

## Sources

- [CocoaLumberjack GitHub](https://github.com/CocoaLumberjack/CocoaLumberjack)
- [XcodeLogger GitHub](https://github.com/codeFi/XcodeLogger)
- [Apple os_log Documentation](https://developer.apple.com/documentation/os/logging)
- [XcodeColors (deprecated)](https://github.com/robbiehanson/XcodeColors)
