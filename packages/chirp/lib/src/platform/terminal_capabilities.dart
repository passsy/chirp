import 'package:chirp/src/platform/platform_info.dart';

export 'package:chirp/src/platform/color_support.dart'
    show TerminalColorSupport;

/// Terminal capabilities for console output.
///
/// Groups all terminal-related settings that affect how output is rendered.
/// Use [TerminalCapabilities.autoDetect] to detect capabilities from the
/// current environment, or construct manually for testing.
///
/// ## Current Capabilities
///
/// - [colorSupport]: Level of ANSI color support (none, 16, 256, or truecolor)
///
/// ## Future Capabilities
///
/// The following capabilities may be added in future versions:
///
/// - **Terminal width**: For text wrapping, alignment, and bordered boxes
/// - **Unicode support**: Whether to use box-drawing characters (`╭─╮`) or
///   ASCII fallbacks (`+-+`)
/// - **Hyperlink support**: OSC 8 sequences for clickable URLs and file paths
/// - **Emoji support**: Whether emoji characters render correctly
///
/// ## Example
///
/// ```dart
/// // Auto-detect from environment
/// final caps = TerminalCapabilities.autoDetect();
///
/// // Manual configuration for testing
/// final caps = TerminalCapabilities(colorSupport: TerminalColorSupport.none);
///
/// // Use with ConsoleMessageBuffer
/// final buffer = ConsoleMessageBuffer(capabilities: caps);
/// ```
class TerminalCapabilities {
  /// Creates terminal capabilities with explicit settings.
  ///
  /// Use [TerminalCapabilities.autoDetect] for automatic detection.
  const TerminalCapabilities({
    this.colorSupport = TerminalColorSupport.none,
  });

  /// Auto-detects terminal capabilities from the current environment.
  ///
  /// Uses platform-specific heuristics and environment variables to determine
  /// the best settings. See [platformColorSupport] for color detection details.
  ///
  /// This factory is the recommended way to create capabilities for production:
  /// ```dart
  /// final caps = TerminalCapabilities.autoDetect();
  /// ```
  factory TerminalCapabilities.autoDetect() {
    return TerminalCapabilities(
      colorSupport: platformColorSupport,
    );
  }

  /// Level of ANSI color support.
  ///
  /// - [TerminalColorSupport.none]: No color codes emitted
  /// - [TerminalColorSupport.ansi16]: Basic 16 colors (\x1B[31m)
  /// - [TerminalColorSupport.ansi256]: 256-color palette (\x1B[38;5;196m)
  /// - [TerminalColorSupport.truecolor]: 24-bit RGB (\x1B[38;2;255;0;0m)
  final TerminalColorSupport colorSupport;

  /// Whether any color output is supported.
  bool get supportsColors => colorSupport.supportsColors;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TerminalCapabilities && other.colorSupport == colorSupport;
  }

  @override
  int get hashCode => colorSupport.hashCode;

  @override
  String toString() => 'TerminalCapabilities(colorSupport: $colorSupport)';
}
