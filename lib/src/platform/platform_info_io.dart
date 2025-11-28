import 'dart:io' show Platform, stdout;

/// Whether we're running in Flutter (vs pure Dart).
///
/// Detected via the presence of `dart.library.ui`.
const bool _isFlutter = bool.fromEnvironment('dart.library.ui');

/// Returns the recommended max chunk length for [print()] on the current platform.
///
/// The limit comes from Android's `liblog/logger_write.cpp`:
/// ```c
/// #define LOG_BUF_SIZE 1024
/// ```
/// which is used in `__android_log_print()` via `vsnprintf(buf, LOG_BUF_SIZE, ...)`.
///
/// - **Android**: 1024 - 100 chars (`LOG_BUF_SIZE` minus "I/flutter (" prefix)
/// - **iOS**: 1024 bytes (os_log limit)
/// - **Other platforms**: null (no chunking needed)
///
/// See: https://cs.android.com/android/platform/superproject/main/+/main:system/logging/liblog/logger_write.cpp;l=62
int? get platformPrintMaxChunkLength {
  if (Platform.isAndroid) {
    // Android's __android_log_print uses LOG_BUF_SIZE=1024 buffer
    // Leave margin for "I/flutter (" prefix added by Flutter engine
    return 1024 - 100;
  }
  if (Platform.isIOS) {
    // iOS os_log has 1024 byte limit
    return 1024;
  }
  // Desktop and other platforms don't have log truncation issues
  return null;
}

/// @Deprecated('Use platformPrintMaxChunkLength instead')
int? get platformMaxChunkLength => platformPrintMaxChunkLength;

/// Whether the console supports ANSI escape codes for colors.
///
/// - **iOS/macOS**: false (Xcode console doesn't render ANSI colors)
/// - **Flutter (other)**: true (Android Studio, VS Code support colors)
/// - **Pure Dart**: Checks [stdout.supportsAnsiEscapes]
bool get platformSupportsAnsiColors {
  // Xcode console doesn't render ANSI escape codes
  if (Platform.isIOS) {
    // https://github.com/flutter/flutter/issues/20663
    return false;
  }
  if (_isFlutter) {
    // Flutter debug consoles (Android Studio, VS Code) support colors
    return true;
  }
  // Pure Dart CLI - check if terminal supports ANSI
  return stdout.supportsAnsiEscapes;
}
