/// Information extracted from a stack frame
class StackFrameInfo {
  /// The caller method (e.g., "UserService.processUser")
  final String callerMethod;

  /// The file path (e.g., "file:///path/to/file.dart" or "package:my_app/file.dart")
  final String file;

  /// The line number
  final int line;

  /// The column number (optional)
  final int? column;

  StackFrameInfo({
    required this.callerMethod,
    required this.file,
    required this.line,
    this.column,
  });

  /// Returns the location string like "my_service:42"
  String get callerLocation {
    final fileName = file.split('/').last;
    final nameWithoutExt = fileName.replaceAll('.dart', '');
    return '$nameWithoutExt:$line';
  }

  /// Returns just the file name without extension, like "my_service"
  String get callerName {
    final fileName = file.split('/').last;
    return fileName.replaceAll('.dart', '');
  }

  @override
  String toString() {
    return 'StackFrameInfo(callerMethod: $callerMethod, file: $file, line: $line, column: $column)';
  }
}

/// Extracts full stack frame information from a stack trace
///
/// Skips frames from the chirp library itself to find the actual caller.
StackFrameInfo? getCallerInfo(StackTrace stackTrace, {int skipFrames = 0}) {
  final traceString = stackTrace.toString();
  final lines = traceString.split('\n');

  for (final line in lines) {
    // Skip empty lines
    if (line.trim().isEmpty) continue;

    // Skip chirp library frames
    if (line.contains('package:chirp/')) continue;
    if (line.contains('dart:core')) continue;
    if (line.contains('dart:async')) continue;

    // Skip additional frames if requested
    if (skipFrames > 0) {
      // ignore: parameter_assignments
      skipFrames--;
      continue;
    }

    // Try to extract stack frame info
    final info = parseStackFrame(line);
    if (info != null) return info;
  }

  return null;
}

/// Parses a single stack frame string and extracts information
///
/// Supports various stack trace formats from different platforms:
/// - Android/iOS: `#1      MyClass.method (package:my_app/my_file.dart:42:10)`
/// - Web: `packages/my_app/my_file.dart 42:10  MyClass.method`
/// - Browser: `at MyClass.method (file:///path/to/my_file.dart:42:10)`
///
/// Returns null if the frame cannot be parsed.
///
/// Inspired by: https://github.com/kmartins/groveman/blob/main/packages/groveman/lib/src/util/stack_trace_util.dart
StackFrameInfo? parseStackFrame(String frame) {
  // Pattern: #1      MyClass.method (package:my_app/my_file.dart:42:10)
  // Pattern: #1      main (file:///path/to/my_file.dart:42:10)
  // Pattern: at MyClass.method (packages/my_app/my_file.dart:42:10)
  // Pattern: packages/my_app/my_file.dart:42:10  MyClass.method

  // Try to match the standard VM stack frame format
  // #1      MyClass.method (package:my_app/my_file.dart:42:10)
  final vmMatch = RegExp(
    r'#\d+\s+(.+?)\s+\((.+?\.dart):(\d+)(?::(\d+))?\)',
  ).firstMatch(frame);

  if (vmMatch != null) {
    final callerMethod = vmMatch.group(1)!.trim();
    final file = vmMatch.group(2)!;
    final line = int.parse(vmMatch.group(3)!);
    final column = vmMatch.group(4) != null ? int.parse(vmMatch.group(4)!) : null;

    return StackFrameInfo(
      callerMethod: callerMethod,
      file: file,
      line: line,
      column: column,
    );
  }

  // Try to match browser/web stack frame format with "at" prefix
  // at Object.MyClass_method (packages/my_app/my_file.dart:42:10)
  // at MyClass.method (http://localhost:8080/main.dart:50:20)
  final browserMatch = RegExp(
    r'at\s+(.+?)\s+\((.+?\.dart):(\d+)(?::(\d+))?\)',
  ).firstMatch(frame);

  if (browserMatch != null) {
    final callerMethod = browserMatch.group(1)!.trim();
    final file = browserMatch.group(2)!;
    final line = int.parse(browserMatch.group(3)!);
    final column = browserMatch.group(4) != null ? int.parse(browserMatch.group(4)!) : null;

    return StackFrameInfo(
      callerMethod: callerMethod,
      file: file,
      line: line,
      column: column,
    );
  }

  // Try to match web format without parentheses
  // packages/my_app/utils.dart:100:5  helperFunction
  // dart-sdk/lib/async/schedule_microtask.dart:40:5
  final webMatch = RegExp(
    r'^((?:packages|dart-sdk|dart:)?\S+\.dart):(\d+)(?::(\d+))?\s*(.*)$',
  ).firstMatch(frame);

  if (webMatch != null) {
    final file = webMatch.group(1)!;
    final line = int.parse(webMatch.group(2)!);
    final column = webMatch.group(3) != null ? int.parse(webMatch.group(3)!) : null;
    final methodName = webMatch.group(4)?.trim();

    return StackFrameInfo(
      callerMethod: (methodName != null && methodName.isNotEmpty)
          ? methodName
          : '<unknown>',
      file: file,
      line: line,
      column: column,
    );
  }

  // Fallback: Try to find just .dart file reference
  // my_file.dart:42
  final dartMatch = RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*\.dart)(?::(\d+))?')
      .firstMatch(frame);

  if (dartMatch != null) {
    final fileName = dartMatch.group(1)!;
    final lineNumber = dartMatch.group(2);

    if (lineNumber != null) {
      return StackFrameInfo(
        callerMethod: '<unknown>',
        file: fileName,
        line: int.parse(lineNumber),
      );
    }
  }

  return null;
}
