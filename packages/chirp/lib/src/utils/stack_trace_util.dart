/// Captures stack trace only when assertions are enabled (debug mode).
///
/// Returns `null` in release mode to avoid the performance overhead of
/// capturing stack traces in production.
///
/// This is useful for debugging delegated implementations where the
/// creation site helps identify which instance is which.
StackTrace? debugCaptureStackTrace() {
  StackTrace? result;
  assert(() {
    result = StackTrace.current;
    return true;
  }());
  return result;
}

/// Information extracted from a stack frame
class StackFrameInfo {
  /// The raw caller method (e.g., `UserService.processUser.<anonymous closure>`)
  final String rawCallerMethod;

  /// The file path (e.g., "file:///path/to/file.dart" or "package:my_app/file.dart")
  final String file;

  /// The line number
  final int line;

  /// The column number (optional)
  final int? column;

  /// The original stack trace this frame was parsed from.
  final StackTrace stackTrace;

  /// Creates stack frame info from parsed stack trace components.
  StackFrameInfo({
    required this.stackTrace,
    required this.rawCallerMethod,
    required this.file,
    required this.line,
    this.column,
  });

  /// The caller method with anonymous closures stripped
  ///
  /// Examples:
  /// - `UserService.processUser.<anonymous closure>` -> `UserService.processUser`
  /// - `main.<anonymous closure>.<anonymous closure>` -> `main`
  late final String callerMethod =
      rawCallerMethod.replaceAll('.<anonymous closure>', '');

  /// Returns the location string like "my_service:42"
  late final String callerLocation = () {
    final fileName = file.split('/').last;
    final nameWithoutExt = fileName.replaceAll('.dart', '');
    return '$nameWithoutExt:$line';
  }();

  /// Returns just the file name without extension, like "my_service"
  late final String callerFileName = () {
    final fileName = file.split('/').last;
    return fileName.replaceAll('.dart', '');
  }();

  /// Returns a package-relative file path, like "my_app/lib/src/server.dart"
  ///
  /// Converts various file path formats to a clean, package-relative path:
  /// - `package:my_app/src/server.dart` → `my_app/lib/src/server.dart`
  /// - `file:///home/user/project/lib/server.dart` → `lib/server.dart`
  /// - `packages/my_app/src/server.dart` → `my_app/lib/src/server.dart`
  ///
  /// Falls back to the original [file] if no transformation applies.
  late final String packageRelativePath = () {
    // Handle package: URI format
    // package:my_app/src/server.dart → my_app/lib/src/server.dart
    if (file.startsWith('package:')) {
      final withoutScheme = file.substring('package:'.length);
      final slashIndex = withoutScheme.indexOf('/');
      if (slashIndex != -1) {
        final packageName = withoutScheme.substring(0, slashIndex);
        final rest = withoutScheme.substring(slashIndex + 1);
        return '$packageName/lib/$rest';
      }
      return withoutScheme;
    }

    // Handle file:// URI format - extract path after common roots
    // file:///home/user/project/lib/server.dart → lib/server.dart
    if (file.startsWith('file://')) {
      final path = file.substring('file://'.length);
      // Look for lib/, bin/, test/ as package root markers
      for (final marker in ['lib/', 'bin/', 'test/']) {
        final markerIndex = path.indexOf(marker);
        if (markerIndex != -1) {
          return path.substring(markerIndex);
        }
      }
      // Fallback: return just the filename
      return path.split('/').last;
    }

    // Handle web packages format
    // packages/my_app/src/server.dart → my_app/lib/src/server.dart
    if (file.startsWith('packages/')) {
      final withoutPrefix = file.substring('packages/'.length);
      final slashIndex = withoutPrefix.indexOf('/');
      if (slashIndex != -1) {
        final packageName = withoutPrefix.substring(0, slashIndex);
        final rest = withoutPrefix.substring(slashIndex + 1);
        return '$packageName/lib/$rest';
      }
      return withoutPrefix;
    }

    return file;
  }();

  /// Extracts the class/type name from the caller method
  ///
  /// Examples:
  /// - "UserService.processUser" -> "UserService"
  /// - "OuterClass.InnerClass.method" -> "OuterClass.InnerClass"
  /// - "MyClass.method.\<anonymous closure\>" -> "MyClass"
  /// - "main" -> null (top-level function)
  /// - "\<unknown\>" -> null
  late final String? callerClassName = () {
    // Handle special cases
    if (callerMethod == '<unknown>' || !callerMethod.contains('.')) {
      return null;
    }

    // Find the last dot before the method name
    // For "UserService.processUser" we want "UserService"
    // For "OuterClass.InnerClass.method" we want "OuterClass.InnerClass"

    // Find last dot - everything before it is the class name
    final lastDotIndex = callerMethod.lastIndexOf('.');
    if (lastDotIndex == -1) {
      return null; // Top-level function
    }

    return callerMethod.substring(0, lastDotIndex);
  }();

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
    final info = parseStackFrame(stackTrace, line);
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
StackFrameInfo? parseStackFrame(StackTrace stackTrace, String frame) {
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
    final column =
        vmMatch.group(4) != null ? int.parse(vmMatch.group(4)!) : null;

    return StackFrameInfo(
      stackTrace: stackTrace,
      rawCallerMethod: callerMethod,
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
    final column = browserMatch.group(4) != null
        ? int.parse(browserMatch.group(4)!)
        : null;

    return StackFrameInfo(
      stackTrace: stackTrace,
      rawCallerMethod: callerMethod,
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
    final column =
        webMatch.group(3) != null ? int.parse(webMatch.group(3)!) : null;
    final methodName = webMatch.group(4)?.trim();

    return StackFrameInfo(
      stackTrace: stackTrace,
      rawCallerMethod: (methodName != null && methodName.isNotEmpty)
          ? methodName
          : '<unknown>',
      file: file,
      line: line,
      column: column,
    );
  }

  // Fallback: Try to find just .dart file reference
  // my_file.dart:42
  final dartMatch =
      RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*\.dart)(?::(\d+))?').firstMatch(frame);

  if (dartMatch != null) {
    final fileName = dartMatch.group(1)!;
    final lineNumber = dartMatch.group(2);

    if (lineNumber != null) {
      return StackFrameInfo(
        stackTrace: stackTrace,
        rawCallerMethod: '<unknown>',
        file: fileName,
        line: int.parse(lineNumber),
      );
    }
  }

  return null;
}
