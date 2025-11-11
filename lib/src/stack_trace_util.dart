/// Extracts the caller's file name and line number from a stack trace
///
/// Returns a string like "my_service.dart:42" or just "my_service.dart"
/// if the line number cannot be determined.
///
/// Skips frames from the chirp library itself to find the actual caller.
String? getCallerLocation(StackTrace stackTrace, {int skipFrames = 0}) {
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

    // Try to extract file name and line number
    final info = _parseStackFrame(line);
    if (info != null) return info;
  }

  return null;
}

/// Extracts just the class/file name without line number
String? getCallerName(StackTrace stackTrace, {int skipFrames = 0}) {
  final info = getCallerLocation(stackTrace, skipFrames: skipFrames);
  if (info == null) return null;

  // Remove line number if present
  final colonIndex = info.lastIndexOf(':');
  if (colonIndex != -1) {
    return info.substring(0, colonIndex);
  }
  return info;
}

String? _parseStackFrame(String frame) {
  // Pattern: #1      MyClass.method (package:my_app/my_file.dart:42:10)
  // Pattern: #1      main (file:///path/to/my_file.dart:42:10)
  // Pattern: package:my_app/my_file.dart 42:10  MyClass.method

  // Try to find .dart file reference
  final dartMatch =
      RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*\.dart)(?::(\d+))?').firstMatch(frame);

  if (dartMatch != null) {
    final fileName = dartMatch.group(1)!;
    final lineNumber = dartMatch.group(2);

    // Remove .dart extension for cleaner output
    final nameWithoutExt = fileName.replaceAll('.dart', '');

    if (lineNumber != null) {
      return '$nameWithoutExt:$lineNumber';
    }
    return nameWithoutExt;
  }

  return null;
}
