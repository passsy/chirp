import 'dart:io' show Platform, stdout;

import 'package:chirp/src/platform/color_support.dart';

export 'package:chirp/src/platform/color_support.dart';

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

/// Parses color support level from environment variables.
///
/// Checks `NO_COLOR`, `FORCE_COLOR`, and `COLORTERM` env vars.
/// Returns `null` if no explicit color setting is found.
///
/// See:
/// - https://no-color.org/
/// - https://force-color.org/
TerminalColorSupport? colorSupportFromEnv(Map<String, String> env) {
  // NO_COLOR takes precedence - https://no-color.org/
  if (env.containsKey('NO_COLOR')) {
    return TerminalColorSupport.none;
  }

  // FORCE_COLOR overrides auto-detection
  final forceColor = env['FORCE_COLOR'];
  if (forceColor != null) {
    return switch (forceColor) {
      'false' || '0' => TerminalColorSupport.none,
      '1' => TerminalColorSupport.ansi16,
      '2' => TerminalColorSupport.ansi256,
      '3' || 'true' => TerminalColorSupport.truecolor,
      _ => TerminalColorSupport.ansi16, // default if set but unknown value
    };
  }

  // COLORTERM is set by many modern terminals
  final colorterm = env['COLORTERM'];
  if (colorterm != null) {
    final ct = colorterm.toLowerCase();
    if (ct == 'truecolor' || ct == '24bit') {
      return TerminalColorSupport.truecolor;
    }
    if (ct == 'ansi256' || ct == '256color') {
      return TerminalColorSupport.ansi256;
    }
    if (ct == 'ansi') {
      return TerminalColorSupport.ansi16;
    }
  }

  return null;
}

/// Auto-detects color support based on platform and terminal heuristics.
///
/// This does NOT check `NO_COLOR`, `FORCE_COLOR`, or `COLORTERM` env vars.
/// Use [colorSupportFromEnv] for explicit env var settings, or
/// [platformColorSupport] for the combined result.
///
/// Detection order:
/// 1. iOS → [TerminalColorSupport.none] (Xcode console doesn't support ANSI)
/// 2. CI environment (GitHub Actions → truecolor, others → ansi16)
/// 3. Windows 10+ → truecolor
/// 4. `TERM` env var patterns (-256color, xterm, etc.)
/// 5. JetBrains IDEs (macOS `__CFBundleIdentifier`)
/// 6. Flutter apps → truecolor
/// 7. `stdout.supportsAnsiEscapes` fallback
TerminalColorSupport autoDetectColorSupport(Map<String, String> env) {
  // Xcode console doesn't render ANSI escape codes
  if (Platform.isIOS) {
    // https://github.com/flutter/flutter/issues/20663
    return TerminalColorSupport.none;
  }
  // Flutter apps - debug consoles (Android Studio, VS Code) support truecolor
  if (_isFlutter) {
    return TerminalColorSupport.truecolor;
  }

  // CI environment detection
  if (env.containsKey('CI')) {
    // GitHub Actions supports truecolor
    if (env.containsKey('GITHUB_ACTIONS')) {
      return TerminalColorSupport.truecolor;
    }
    // GitLab CI supports truecolor
    if (env.containsKey('GITLAB_CI')) {
      return TerminalColorSupport.truecolor;
    }
    // Other CI systems typically support basic colors
    // (Travis, CircleCI, Jenkins, CodeShip, etc.)
    return TerminalColorSupport.ansi16;
  }

  // Windows 10 build 14931+ supports truecolor via ConPTY
  if (Platform.isWindows) {
    // Windows Terminal and modern ConPTY support truecolor
    // Check for WT_SESSION (Windows Terminal) or modern Windows
    if (env.containsKey('WT_SESSION')) {
      return TerminalColorSupport.truecolor;
    }
    // Windows 10+ generally supports at least 256 colors
    if (stdout.supportsAnsiEscapes) {
      return TerminalColorSupport.truecolor;
    }
  }

  // Check TERM environment variable
  final term = env['TERM']?.toLowerCase() ?? '';

  // dumb terminal - no colors
  if (term == 'dumb') {
    return TerminalColorSupport.none;
  }

  // Check for 256-color terminal indicators
  if (term.contains('-256color') ||
      term.contains('256color') ||
      term == 'xterm-256' ||
      term == 'screen-256') {
    return TerminalColorSupport.ansi256;
  }

  // Common terminals that support truecolor
  // iTerm2, Konsole, VTE-based terminals set COLORTERM, but some don't
  if (term.contains('xterm') ||
      term.contains('vte') ||
      term.contains('gnome') ||
      term.contains('konsole') ||
      term.contains('alacritty') ||
      term.contains('kitty')) {
    // Modern terminals typically support truecolor even without COLORTERM
    return TerminalColorSupport.truecolor;
  }

  if (Platform.isMacOS) {
    // JetBrains IDEs (IntelliJ, WebStorm, etc.) support truecolor
    // https://youtrack.jetbrains.com/issue/IDEA-248978
    final bundleIdentifier = env['__CFBundleIdentifier'] ?? '';
    if (bundleIdentifier.contains('jetbrains')) {
      return TerminalColorSupport.truecolor;
    }
  }

  // VS Code Dart Debug Console support truecolor
  if (env.containsKey('VSCODE_PID')) {
    return TerminalColorSupport.truecolor;
  }

  // Pure Dart CLI - check if terminal supports ANSI at all
  if (stdout.supportsAnsiEscapes) {
    // Conservative default: assume 256-color support for ANSI-capable terminals
    return TerminalColorSupport.ansi256;
  }

  return TerminalColorSupport.none;
}

/// Detects the level of color support for the current terminal/environment.
///
/// Combines [colorSupportFromEnv] (explicit settings) with
/// [autoDetectColorSupport] (heuristics). Env vars take precedence.
///
TerminalColorSupport? _cachedColorSupport;

/// Detection order (based on ansis library):
/// https://github.com/webdiscus/ansis/blob/master/src/color-support.js
/// 1. `NO_COLOR` env var → [TerminalColorSupport.none]
/// 2. `FORCE_COLOR` env var → forced level (0-3)
/// 3. `COLORTERM` env var → truecolor/24bit/ansi256/ansi
/// 4. Auto-detection via [autoDetectColorSupport]
///
/// The result is cached after the first call since environment variables
/// don't typically change during runtime.
TerminalColorSupport get platformColorSupport {
  if (_cachedColorSupport != null) {
    return _cachedColorSupport!;
  }

  final env = Platform.environment;

  // Check explicit env var overrides first
  final fromEnv = colorSupportFromEnv(env);
  if (fromEnv != null) {
    return _cachedColorSupport = fromEnv;
  }

  return _cachedColorSupport = autoDetectColorSupport(env);
}

/// Whether the console supports ANSI escape codes for colors.
///
/// @Deprecated('Use platformColorSupport.supportsColors instead')
bool get platformSupportsAnsiColors => platformColorSupport.supportsColors;
