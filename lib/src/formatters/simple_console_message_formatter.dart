import 'package:chirp/chirp.dart';

/// Simple, comprehensive text formatter that displays all LogRecord fields
///
/// Format pattern:
/// ```dart
/// 2024-01-10 10:30:45.123 [INFO] main:42 processUser UserService@0000a3f2 [payment] - User logged in
///   userId=user_123 action=login
/// Exception: Payment failed
/// #0  PaymentService.process (payment_service.dart:78:5)
/// #1  handlePayment (main.dart:123:12)
/// ```
///
/// Components (all shown if present):
/// - Timestamp: Full date and time with milliseconds
/// - Level: Log level in uppercase brackets
/// - Location: file:line from caller stack trace
/// - Method: Method name from caller
/// - Class: Class name with instance hash
/// - Logger name: Shown in square brackets (only if not "root")
/// - Message: The log message
/// - Data: Structured key=value pairs (indented)
/// - Error: Exception or error object
/// - Stack trace: Full stack trace
///
/// This formatter prioritizes completeness over brevity, making it useful
/// for debugging and development.
class SimpleConsoleMessageFormatter extends ConsoleMessageFormatter {
  /// Whether to show the logger name field
  final bool showLoggerName;

  /// Whether to show caller location (file:line)
  final bool showCaller;

  /// Whether to show instance information (class@hash)
  final bool showInstance;

  /// Whether to show structured data fields
  final bool showData;

  SimpleConsoleMessageFormatter({
    this.showLoggerName = true,
    this.showCaller = true,
    this.showInstance = true,
    this.showData = true,
  });

  @override
  void format(LogRecord record, ConsoleMessageBuilder builder) {
    // Main log line: timestamp [LEVEL] class@hash (loggerName) - message
    _writeMainLine(record, builder);

    // Structured data on separate line (key=value format)
    if (showData && record.data != null && record.data!.isNotEmpty) {
      builder.write('\n  ');
      final entries = record.data!.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        builder.write('${entry.key}=${entry.value}');
        if (i < entries.length - 1) {
          builder.write(' ');
        }
      }
    }

    // Error on new line (no label, just the error itself)
    if (record.error != null) {
      builder.write('\n${record.error}');
    }

    // Stack trace on new lines (no label, just the trace)
    if (record.stackTrace != null) {
      final stackLines = record.stackTrace.toString().split('\n');
      for (final line in stackLines) {
        if (line.isNotEmpty) {
          builder.write('\n$line');
        }
      }
    }
  }

  void _writeMainLine(LogRecord record, ConsoleMessageBuilder builder) {
    // Format timestamp: 2024-01-10 10:30:45.123
    final date = record.date;
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    final timestamp = '$year-$month-$day $hour:$minute:$second.$ms';

    builder.write(timestamp);

    // Level: [INFO], [ERROR], etc.
    builder.write(' [${record.level.name.toUpperCase()}]');

    // Caller location and method: main:42 MyClass.method
    if (showCaller && record.caller != null) {
      final callerInfo = getCallerInfo(record.caller!);
      if (callerInfo != null) {
        // Location: main:42
        builder.write(' ${callerInfo.callerLocation}');

        // Method name if available and different from class
        final className = _resolveClassName(record);
        final method = callerInfo.callerMethod;

        // Show method if it's not just the class name
        if (method != '<unknown>' &&
            (className == null || !method.startsWith('$className.'))) {
          builder.write(' $method');
        } else if (method.startsWith('$className.')) {
          // Show just the method part without class prefix
          final methodName = method.substring(className!.length + 1);
          if (methodName.isNotEmpty) {
            builder.write(' $methodName');
          }
        }
      }
    }

    // Class and instance information
    if (showInstance) {
      final className = _resolveClassName(record);
      if (className != null) {
        builder.write(' $className');

        // Add instance hash if available
        if (record.instanceHash != null) {
          final hash = record.instanceHash!.toRadixString(16).padLeft(8, '0');
          builder.write('@$hash');
        }
      }
    }

    // Logger name - shown if present and not "root"
    if (showLoggerName &&
        record.loggerName != null &&
        record.loggerName != 'root') {
      builder.write(' [${record.loggerName}]');
    }

    // Message separator and text
    builder.write(' - ${record.message?.toString() ?? ''}');
  }

  String? _resolveClassName(LogRecord record) {
    // Priority order (most specific to least specific):
    // 1. caller class name (from stack trace - actual location of log call)
    // 2. instance runtime type (fallback when no caller info)
    // Note: loggerName is displayed separately, not used as className

    // Try to extract from caller first - most specific
    if (record.caller != null) {
      final callerInfo = getCallerInfo(record.caller!);
      if (callerInfo?.callerClassName != null) {
        return callerInfo!.callerClassName;
      }
    }

    // Fallback to instance type
    if (record.instance != null) {
      return record.instance!.runtimeType.toString();
    }

    return null;
  }
}
