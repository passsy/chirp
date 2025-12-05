# Dart/Flutter Logging Libraries

A comprehensive guide to the most popular logging libraries for Dart and Flutter, with a focus on colorful console output.

## 1. logger

**pub.dev:**
```yaml
dependencies:
  logger: ^2.0.2
```
**Likes:** 1200+

The most popular logging package for Dart/Flutter with beautiful colorful output.

### Key Features
- Beautiful colorful console output
- Emoji support for log levels
- Stack trace printing
- Customizable output

### Example
```dart
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    printTime: true, // Should each log print contain a timestamp
  ),
);

void main() {
  logger.t('Trace message');      // 🔍 Trace
  logger.d('Debug message');      // 🐛 Debug
  logger.i('Info message');       // 💡 Info
  logger.w('Warning message');    // ⚠️ Warning
  logger.e('Error message');      // ⛔ Error
  logger.f('Fatal message');      // 💀 Fatal (What a terrible failure)

  // With data
  logger.i('User logged in', error: null, stackTrace: null);

  // With exception
  try {
    throw Exception('Something went wrong');
  } catch (e, stackTrace) {
    logger.e('Error occurred', error: e, stackTrace: stackTrace);
  }
}

// Simple logger without box
final simpleLogger = Logger(
  printer: SimplePrinter(colors: true),
);
```

### Custom Printer
```dart
class CustomPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final color = _levelColors[event.level];
    final emoji = _levelEmojis[event.level];
    final time = DateTime.now().toIso8601String();

    return ['$color[$time] $emoji ${event.message}\x1B[0m'];
  }

  static const _levelColors = {
    Level.trace: '\x1B[37m',    // White
    Level.debug: '\x1B[36m',    // Cyan
    Level.info: '\x1B[32m',     // Green
    Level.warning: '\x1B[33m',  // Yellow
    Level.error: '\x1B[31m',    // Red
    Level.fatal: '\x1B[35m',    // Magenta
  };

  static const _levelEmojis = {
    Level.trace: '🔍',
    Level.debug: '🐛',
    Level.info: 'ℹ️',
    Level.warning: '⚠️',
    Level.error: '❌',
    Level.fatal: '💀',
  };
}
```

---

## 2. talker

**pub.dev:**
```yaml
dependencies:
  talker: ^4.0.0
  talker_flutter: ^4.0.0  # For Flutter UI
```
**Likes:** 600+

Advanced error handling and logging for Flutter with built-in UI.

### Key Features
- Colorful console output
- Built-in Flutter log viewer UI
- Error and exception handling
- HTTP request logging (talker_dio_logger)
- BLoC logging (talker_bloc_logger)

### Example
```dart
import 'package:talker/talker.dart';

final talker = Talker(
  settings: TalkerSettings(
    colors: {
      TalkerLogType.debug: AnsiPen()..cyan(),
      TalkerLogType.info: AnsiPen()..green(),
      TalkerLogType.warning: AnsiPen()..yellow(),
      TalkerLogType.error: AnsiPen()..red(),
      TalkerLogType.critical: AnsiPen()..magenta(),
    },
  ),
);

void main() {
  // Basic logging
  talker.debug('Debug message');
  talker.info('Info message');
  talker.warning('Warning message');
  talker.error('Error message');
  talker.critical('Critical message');

  // With exception
  try {
    throw Exception('Something went wrong');
  } catch (e, stackTrace) {
    talker.handle(e, stackTrace, 'Error occurred');
  }

  // Custom log
  talker.log('Custom message', logLevel: LogLevel.info);
}
```

### Flutter UI Integration
```dart
import 'package:talker_flutter/talker_flutter.dart';

// In your widget
class MyApp extends StatelessWidget {
  final talker = TalkerFlutter.init();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        TalkerRouteObserver(talker), // Log route changes
      ],
      home: Scaffold(
        body: TalkerScreen(talker: talker), // Built-in log viewer
      ),
    );
  }
}
```

---

## 3. colored_logger

**pub.dev:**
```yaml
dependencies:
  colored_logger: ^0.0.5
```

A simple colored logging utility with ANSI support.

### Key Features
- Color-coded log levels
- Rich text formatting
- 256-color and RGB support
- VS Code, Android Studio, IntelliJ support

### Example
```dart
import 'package:colored_logger/colored_logger.dart';

void main() {
  // Basic colored logging
  ColoredLogger.info('Info message');        // Blue
  ColoredLogger.success('Success message');  // Green
  ColoredLogger.warning('Warning message');  // Yellow
  ColoredLogger.error('Error message');      // Red

  // With styling
  ColoredLogger.log(
    'Styled message',
    style: LogStyle(
      color: LogColor.cyan,
      bold: true,
    ),
  );

  // Custom colors
  ColoredLogger.log(
    'Custom color',
    style: LogStyle(
      color: LogColor.rgb(255, 128, 0), // Orange
    ),
  );
}
```

---

## 4. flutter_color_logger

**pub.dev:**
```yaml
dependencies:
  flutter_color_logger: ^1.0.0
```

Simple color logger with string extensions.

### Key Features
- String extension methods
- Semantic log methods
- Debug-only (no output in release)

### Example
```dart
import 'package:flutter_color_logger/flutter_color_logger.dart';

void main() {
  // Color extensions
  'Red text'.logRed;
  'Green text'.logGreen;
  'Yellow text'.logYellow;
  'Blue text'.logBlue;
  'Purple text'.logPurple;
  'Cyan text'.logCyan;

  // Semantic methods
  'Success message'.logSuccess;   // Green
  'Error message'.logError;       // Red
  'Warning message'.logWarning;   // Yellow
  'Info message'.logInfo;         // Blue
  'Debug message'.logDebug;       // Purple

  // Only logs in debug mode, suppressed in release
}
```

---

## 5. ChalkDart

**pub.dev:**
```yaml
dependencies:
  chalkdart: ^2.0.0
```

A port of the popular Chalk.js library.

### Key Features
- Familiar API from Chalk.js
- Chainable methods
- 256 and TrueColor support
- Works in VS Code debugger

### Example
```dart
import 'package:chalkdart/chalk.dart';

void main() {
  // Basic colors
  print(chalk.red('Red text'));
  print(chalk.green('Green text'));
  print(chalk.yellow('Yellow text'));
  print(chalk.blue('Blue text'));

  // Chaining
  print(chalk.bold.red('Bold red'));
  print(chalk.underline.blue('Underlined blue'));

  // Background colors
  print(chalk.bgRed.white('White on red'));
  print(chalk.bgGreen.black('Black on green'));

  // RGB colors
  print(chalk.rgb(255, 136, 0)('Orange text'));

  // Hex colors
  print(chalk.hex('#FF8800')('Hex orange'));

  // Create custom logger
  final info = chalk.blue;
  final success = chalk.green.bold;
  final warn = chalk.yellow;
  final error = chalk.red.bold;

  print(info('ℹ️ Info message'));
  print(success('✅ Success message'));
  print(warn('⚠️ Warning message'));
  print(error('❌ Error message'));
}
```

---

## 6. Custom Logger with ANSI

Build your own colorful logger.

### Example
```dart
import 'dart:developer' as developer;

class ColorLog {
  // ANSI color codes
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _bold = '\x1B[1m';

  static void debug(String message) {
    _log(_cyan, '🔍 DEBUG', message);
  }

  static void info(String message) {
    _log(_blue, 'ℹ️ INFO', message);
  }

  static void success(String message) {
    _log(_green, '✅ SUCCESS', message);
  }

  static void warn(String message) {
    _log(_yellow, '⚠️ WARN', message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_red, '❌ ERROR', message);
    if (error != null) {
      print('$_red$error$_reset');
    }
    if (stackTrace != null) {
      print('$_red$stackTrace$_reset');
    }
  }

  static void fatal(String message) {
    print('$_bold$_magenta💀 FATAL: $message$_reset');
  }

  static void _log(String color, String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    print('$color[$timestamp] $level: $message$_reset');
  }
}

// For Flutter apps, use developer.log for better IDE support
class FlutterLog {
  static void debug(String message, {String name = 'APP'}) {
    developer.log('🔍 $message', name: name, level: 500);
  }

  static void info(String message, {String name = 'APP'}) {
    developer.log('ℹ️ $message', name: name, level: 800);
  }

  static void warn(String message, {String name = 'APP'}) {
    developer.log('⚠️ $message', name: name, level: 900);
  }

  static void error(
    String message, {
    String name = 'APP',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '❌ $message',
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

void main() {
  ColorLog.debug('Loading configuration...');
  ColorLog.info('Server starting on port 8080');
  ColorLog.success('Database connected');
  ColorLog.warn('High memory usage');
  ColorLog.error('Connection failed');
  ColorLog.fatal('System crash!');

  try {
    throw Exception('Test error');
  } catch (e, stackTrace) {
    ColorLog.error('An error occurred', e, stackTrace);
  }
}
```

---

## 7. ansi_styles

**pub.dev:**
```yaml
dependencies:
  ansi_styles: ^0.3.2
```

ANSI escape codes for styling terminal text.

### Example
```dart
import 'package:ansi_styles/ansi_styles.dart';

void main() {
  // Colors
  print(AnsiStyles.red('Red text'));
  print(AnsiStyles.green('Green text'));
  print(AnsiStyles.yellow('Yellow text'));

  // Styles
  print(AnsiStyles.bold('Bold text'));
  print(AnsiStyles.italic('Italic text'));
  print(AnsiStyles.underline('Underlined'));

  // Combine
  print(AnsiStyles.bold(AnsiStyles.red('Bold red')));

  // Background
  print(AnsiStyles.bgRed('Red background'));
}
```

---

## Quick Comparison

| Library | Colors | Features | UI Viewer | Best For |
|---------|--------|----------|-----------|----------|
| logger | ⭐⭐⭐⭐⭐ | Pretty boxes | ❌ | General use |
| talker | ⭐⭐⭐⭐ | Full featured | ✅ | Flutter apps |
| ChalkDart | ⭐⭐⭐⭐⭐ | Chainable API | ❌ | Chalk.js users |
| colored_logger | ⭐⭐⭐⭐ | Simple | ❌ | Quick coloring |
| Custom | ⭐⭐⭐⭐⭐ | Full control | ❌ | Specific needs |

## Recommendation

**For Flutter apps:** Use **talker** with **talker_flutter** - it provides a built-in log viewer UI.

**For general Dart:** Use **logger** - it has the most beautiful default output with boxes and emojis.

**For JS/Node.js developers:** Use **ChalkDart** - the familiar Chalk.js API.

## Notes on IDE Support

- **VS Code:** ANSI colors work in the Debug Console
- **Android Studio/IntelliJ:** Use the Grep Console plugin for colors
- **Terminal:** Full ANSI support
- **macOS:** Some ANSI sequences may not work in iOS simulator logs

## Sources

- [logger on pub.dev](https://pub.dev/packages/logger)
- [talker on pub.dev](https://pub.dev/packages/talker)
- [talker_flutter on pub.dev](https://pub.dev/packages/talker_flutter)
- [ChalkDart on pub.dev](https://pub.dev/packages/chalkdart)
- [colored_logger on pub.dev](https://pub.dev/packages/colored_logger)
- [DEV.to: Colorized Flutter Logging](https://dev.to/founcehq/colorized-logging-for-flutter-development-with-vs-code-40kn)
