import 'package:chirp/src/platform/color_support.dart';

export 'package:chirp/src/platform/color_support.dart';

/// Returns the recommended max chunk length for [print()] on the current platform.
///
/// Web browsers don't have log truncation issues, so no chunking is needed.
int? get platformPrintMaxChunkLength => null;

/// @Deprecated('Use platformPrintMaxChunkLength instead')
int? get platformMaxChunkLength => platformPrintMaxChunkLength;

/// Parses color support level from environment variables.
///
/// On web, environment variables are not available, so always returns `null`.
TerminalColorSupport? colorSupportFromEnv(Map<String, String> env) => null;

/// Auto-detects color support based on platform and terminal heuristics.
///
/// On web, browsers render their own colors in dev tools, so we return
/// [TerminalColorSupport.none] to avoid polluting output with escape codes.
TerminalColorSupport autoDetectColorSupport(Map<String, String> env) =>
    TerminalColorSupport.none;

/// Detects the level of color support for the current environment.
///
/// On web, browsers render their own colors in dev tools, so we return
/// [TerminalColorSupport.none] to avoid polluting output with escape codes.
TerminalColorSupport get platformColorSupport => TerminalColorSupport.none;

/// Whether the console supports ANSI escape codes for colors.
///
/// @Deprecated('Use platformColorSupport.supportsColors instead')
bool get platformSupportsAnsiColors => platformColorSupport.supportsColors;
