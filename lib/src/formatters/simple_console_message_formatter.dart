import 'package:chirp/chirp.dart';

/// Simple, comprehensive text formatter that displays all LogRecord fields
/// using the span-based templating system.
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
class SimpleConsoleMessageFormatter extends SpanBasedFormatter {
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
    super.spanTransformers,
  });

  @override
  LogSpan buildSpan(LogRecord record) {
    return SimpleLogSpan(
      record: record,
      showLoggerName: showLoggerName,
      showCaller: showCaller,
      showInstance: showInstance,
      showData: showData,
    ).build();
  }
}

/// A span that renders a [LogRecord] in simple comprehensive format.
class SimpleLogSpan extends LogSpan {
  final LogRecord record;
  final bool showLoggerName;
  final bool showCaller;
  final bool showInstance;
  final bool showData;

  const SimpleLogSpan({
    required this.record,
    required this.showLoggerName,
    required this.showCaller,
    required this.showInstance,
    required this.showData,
  });

  @override
  LogSpan build() {
    final spans = <LogSpan>[];

    // Timestamp: 2024-01-10 10:30:45.123
    spans.add(FullTimestamp(record.date));

    // Level: [INFO]
    spans.addAll([
      const Whitespace(),
      BracketedLogLevel(record.level),
    ]);

    // Caller location and method
    if (showCaller && record.caller != null) {
      final callerInfo = getCallerInfo(record.caller!);
      if (callerInfo != null) {
        // Location: main:42
        spans.addAll([
          const Whitespace(),
          DartSourceCodeLocation(
            fileName: callerInfo.callerFileName,
            line: callerInfo.line,
          ),
        ]);

        // Method name
        final className = _resolveClassName();
        final method = callerInfo.callerMethod;
        String? methodToShow;

        if (method != '<unknown>' &&
            (className == null || !method.startsWith('$className.'))) {
          methodToShow = method;
        } else if (className != null && method.startsWith('$className.')) {
          final methodName = method.substring(className.length + 1);
          if (methodName.isNotEmpty) {
            methodToShow = methodName;
          }
        }

        if (methodToShow != null) {
          spans.addAll([
            const Whitespace(),
            MethodName(methodToShow),
          ]);
        }
      }
    }

    // Class and instance information
    if (showInstance) {
      final className = _resolveClassName();
      if (className != null) {
        final instanceHash = record.instanceHash?.toRadixString(16).padLeft(8, '0');
        spans.addAll([
          const Whitespace(),
          ClassName(className, instanceHash: instanceHash),
        ]);
      }
    }

    // Logger name - shown if present and not "root"
    if (showLoggerName &&
        record.loggerName != null &&
        record.loggerName != 'root') {
      spans.addAll([
        const Whitespace(),
        BracketedLoggerName(record.loggerName!),
      ]);
    }

    // Message separator and text
    spans.addAll([
      const PlainText(' - '),
      LogMessage(record.message),
    ]);

    // Structured data on separate line (key=value format)
    if (showData && record.data != null && record.data!.isNotEmpty) {
      spans.addAll([
        const NewLine(),
        const PlainText('  '),
        KeyValueData(record.data!),
      ]);
    }

    // Error on new line
    if (record.error != null) {
      spans.addAll([
        const NewLine(),
        ErrorSpan(record.error),
      ]);
    }

    // Stack trace
    if (record.stackTrace != null) {
      spans.addAll([
        const NewLine(),
        StackTraceSpan(record.stackTrace!),
      ]);
    }

    return SpanSequence(spans);
  }

  String? _resolveClassName() {
    if (record.caller != null) {
      final callerInfo = getCallerInfo(record.caller!);
      if (callerInfo?.callerClassName != null) {
        return callerInfo!.callerClassName;
      }
    }
    if (record.instance != null) {
      return record.instance!.runtimeType.toString();
    }
    return null;
  }

  @override
  String toString() => 'SimpleLogSpan(${record.message})';
}

/// Full timestamp with date: 2024-01-10 10:30:45.123
class FullTimestamp extends LogSpan {
  final DateTime date;

  const FullTimestamp(this.date);

  @override
  LogSpan build() {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    return PlainText('$year-$month-$day $hour:$minute:$second.$ms');
  }

  @override
  String toString() => 'FullTimestamp($date)';
}

/// Logger name in brackets: [payment]
class BracketedLoggerName extends LogSpan {
  final String name;

  const BracketedLoggerName(this.name);

  @override
  LogSpan build() => PlainText('[$name]');

  @override
  String toString() => 'BracketedLoggerName("$name")';
}

/// Key-value data in key=value format: userId=user_123 action=login
class KeyValueData extends LogSpan {
  final Map<String, Object?> data;

  const KeyValueData(this.data);

  @override
  LogSpan build() {
    if (data.isEmpty) return const PlainText('');
    final str = data.entries.map((e) => '${e.key}=${e.value}').join(' ');
    return PlainText(str);
  }

  @override
  String toString() => 'KeyValueData($data)';
}
