import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';

/// Simple, comprehensive text formatter that displays all LogRecord fields
/// using the span-based templating system.
///
/// Format pattern:
/// ```dart
/// 10:30:45.123 [INFO] main:42 processUser UserService@0000a3f2 [payment] - User logged in (userId: "user_123", action: "login")
/// Exception: Payment failed
/// #0  PaymentService.process (payment_service.dart:78:5)
/// #1  handlePayment (main.dart:123:12)
/// ```
///
/// Components (all shown if present):
/// - Timestamp: Time with milliseconds (HH:mm:ss.SSS) - uses [Timestamp] span
/// - Level: Log level in uppercase brackets
/// - Location: file:line from caller stack trace
/// - Method: Method name from caller
/// - Class: Class name with instance hash
/// - Logger name: Shown in square brackets (only if not "root")
/// - Message: The log message
/// - Data: Structured data inline with message
/// - Error: Exception or error object
/// - Stack trace: Full stack trace
///
/// This formatter prioritizes completeness over brevity, making it useful
/// for debugging and development.
class SimpleConsoleMessageFormatter extends SpanBasedFormatter {
  /// Whether to show the timestamp
  final bool showTimestamp;

  /// Whether to show the log level (e.g., [INFO])
  final bool showLevel;

  /// Whether to show the logger name field
  final bool showLoggerName;

  /// Whether to show caller location (file:line)
  final bool showCaller;

  /// Whether to show the method name from caller info.
  ///
  /// Only has effect when [showCaller] is true.
  /// Set to false to show source location (file:line) without the method name.
  final bool showMethod;

  /// Whether to show instance information (class@hash)
  final bool showInstance;

  /// Whether to show structured data fields
  final bool showData;

  /// Creates a simple console message formatter.
  ///
  /// All fields are shown by default. Set any `show*` parameter to `false`
  /// to hide that element from the output.
  SimpleConsoleMessageFormatter({
    this.showTimestamp = true,
    this.showLevel = true,
    this.showLoggerName = true,
    this.showCaller = true,
    this.showMethod = true,
    this.showInstance = true,
    this.showData = true,
    super.spanTransformers,
  });

  @override
  LogSpan buildSpan(LogRecord record) {
    return _buildSimpleLogSpan(
      record: record,
      showTimestamp: showTimestamp,
      showLevel: showLevel,
      showLoggerName: showLoggerName,
      showCaller: showCaller,
      showMethod: showMethod,
      showInstance: showInstance,
      showData: showData,
    );
  }
}

/// Builds a span tree for a [LogRecord] in simple comprehensive format.
LogSpan _buildSimpleLogSpan({
  required LogRecord record,
  required bool showTimestamp,
  required bool showLevel,
  required bool showLoggerName,
  required bool showCaller,
  required bool showMethod,
  required bool showInstance,
  required bool showData,
}) {
  final spans = <LogSpan>[];

  // Timestamp: 10:30:45.123
  if (showTimestamp) {
    spans.add(Timestamp(record.timestamp));
  }

  // Level: [INFO]
  if (showLevel) {
    if (spans.isNotEmpty) spans.add(Whitespace());
    spans.add(BracketedLogLevel(record.level));
  }

  // Caller location and method
  if (showCaller && record.caller != null) {
    final callerInfo = getCallerInfo(record.caller!);
    if (callerInfo != null) {
      // Location: main:42
      if (spans.isNotEmpty) spans.add(Whitespace());
      spans.add(
        DartSourceCodeLocation(
          fileName: callerInfo.callerFileName,
          line: callerInfo.line,
        ),
      );

      // Method name (only if showMethod is true)
      if (showMethod) {
        final classNameSpan = ClassName.fromRecord(record);
        final method = callerInfo.callerMethod;
        String? methodToShow;

        if (method != '<unknown>' &&
            (classNameSpan == null ||
                !method.startsWith('${classNameSpan.name}.'))) {
          methodToShow = method;
        } else if (classNameSpan != null &&
            method.startsWith('${classNameSpan.name}.')) {
          final methodName = method.substring(classNameSpan.name.length + 1);
          if (methodName.isNotEmpty) {
            methodToShow = methodName;
          }
        }

        if (methodToShow != null) {
          spans.addAll([
            Whitespace(),
            MethodName(methodToShow),
          ]);
        }
      }
    }
  }

  // Class and instance information
  if (showInstance) {
    final classNameSpan = ClassName.fromRecord(record);
    if (classNameSpan != null) {
      if (spans.isNotEmpty) spans.add(Whitespace());
      spans.add(classNameSpan);
    }
  }

  // Logger name - shown if present and not "root"
  if (showLoggerName &&
      record.loggerName != null &&
      record.loggerName != 'root') {
    if (spans.isNotEmpty) spans.add(Whitespace());
    spans.add(BracketedLoggerName(record.loggerName!));
  }

  // Message separator and text
  if (spans.isNotEmpty) {
    spans.add(PlainText(' - '));
  }
  spans.add(LogMessage(record.message));

  // Structured data inline with message
  if (showData && record.data.isNotEmpty) {
    spans.add(InlineData(record.data));
  }

  // Error on new line
  if (record.error != null) {
    spans.addAll([
      NewLine(),
      ErrorSpan(record.error),
    ]);
  }

  // Stack trace
  if (record.stackTrace != null) {
    spans.addAll([
      NewLine(),
      StackTraceSpan(record.stackTrace!),
    ]);
  }

  return SpanSequence(children: spans);
}

/// {@template chirp.FullTimestamp}
/// Renders full date and time: "2024-01-10 10:30:45.123".
///
/// Use this when logs span multiple days or need to be correlated
/// with external systems. For compact output with just the time,
/// use [Timestamp] instead.
/// {@endtemplate}
class FullTimestamp extends LeafSpan {
  /// The date and time to render.
  final DateTime date;

  /// {@macro chirp.FullTimestamp}
  FullTimestamp(this.date);

  @override
  void render(ConsoleMessageBuffer buffer) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final ms = date.millisecond.toString().padLeft(3, '0');
    buffer.write('$year-$month-$day $hour:$minute:$second.$ms');
  }

  @override
  String toString() => 'FullTimestamp($date)';
}

/// {@template chirp.BracketedLoggerName}
/// Renders logger name in brackets: "[payment]", "[auth]".
///
/// Use to visually distinguish logs from different named loggers.
/// {@endtemplate}
class BracketedLoggerName extends LeafSpan {
  /// The logger name to display in brackets.
  final String name;

  /// {@macro chirp.BracketedLoggerName}
  BracketedLoggerName(this.name);

  @override
  void render(ConsoleMessageBuffer buffer) {
    buffer.write('[$name]');
  }

  @override
  String toString() => 'BracketedLoggerName("$name")';
}

/// {@template chirp.KeyValueData}
/// Renders data as space-separated "key=value" pairs.
///
/// Example output: `userId=user_123 action=login`
///
/// This format is commonly used for log aggregation systems that
/// parse structured data. Renders nothing if [data] is empty.
/// {@endtemplate}
class KeyValueData extends LeafSpan {
  /// The key-value pairs to render.
  final Map<String, Object?> data;

  /// {@macro chirp.KeyValueData}
  KeyValueData(this.data);

  @override
  void render(ConsoleMessageBuffer buffer) {
    if (data.isEmpty) return;
    final str = data.entries.map((e) => '${e.key}=${e.value}').join(' ');
    buffer.write(str);
  }

  @override
  String toString() => 'KeyValueData($data)';
}
