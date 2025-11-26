import 'dart:io' show Platform, stdout;

/// Whether we're running in Flutter (vs pure Dart).
///
/// Detected via the presence of `dart.library.ui`.
const bool _isFlutter = bool.fromEnvironment('dart.library.ui');

/// Returns the recommended max chunk length for the current platform.
///
/// - **iOS**: 800 (to stay safely under the 1024 byte limit)
/// - **Android**: 3500 (to stay safely under the ~4000 char limit)
/// - **Other platforms**: null (no chunking needed)
int? get platformMaxChunkLength {
  if (Platform.isIOS) {
    return 800;
  }
  if (Platform.isAndroid) {
    return 3500;
  }
  // Desktop and other platforms don't have log truncation issues
  return null;
}

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
