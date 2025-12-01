/// Returns the recommended max chunk length for [print()] on the current platform.
///
/// Web browsers don't have log truncation issues, so no chunking is needed.
int? get platformPrintMaxChunkLength => null;

/// @Deprecated('Use platformPrintMaxChunkLength instead')
int? get platformMaxChunkLength => platformPrintMaxChunkLength;

/// Whether the console supports ANSI escape codes for colors.
///
/// On web, browsers render their own colors in dev tools, so we return false
/// to avoid polluting output with escape codes.
bool get platformSupportsAnsiColors => false;
