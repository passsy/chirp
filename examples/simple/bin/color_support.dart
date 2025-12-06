// ignore_for_file: avoid_redundant_argument_values, avoid_print
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:chirp/src/platform/platform_info.dart';

void main() {
  final env = Platform.environment;
  final fromEnv = colorSupportFromEnv(env);
  final autoDetected = autoDetectColorSupport(env);
  final combined = platformColorSupport;

  print('=== Color Support Detection ===');
  print('');
  print('From env vars (NO_COLOR/FORCE_COLOR/COLORTERM): $fromEnv');
  print('Auto-detected (platform heuristics):            $autoDetected');
  print('Combined (platformColorSupport):                $combined');
  print('');

  _printTrueColorVs256();

  final buffer = ConsoleMessageBuffer(
    capabilities: TerminalCapabilities(colorSupport: autoDetected),
  );
  renderSpan(
    AnsiStyled(
      foreground: RgbColor(255, 90, 10),
      // bold: true,
      // italic: true,
      // strikethrough: true,
      // underline: true,
      child: PlainText('=== Environment Variables ==='),
    ),
    buffer,
  );
  print(buffer);

  final items = env.entries.map((e) {
    return SpanSequence(children: [
      AnsiStyled(
        child: PlainText(e.key),
        foreground: DefaultColor(),
        dim: true,
      ),
      AnsiStyled(
        child: PlainText('='),
        foreground: Ansi256.grey50_244,
      ),
      AnsiStyled(
        child: PlainText(e.value),
        foreground: colorForHash(e.value, saturation: ColorSaturation.low),
      ),
    ]);
  }).toList();

  final allLines = SpanSequence(children: items, separator: NewLine());

  final buffer2 = ConsoleMessageBuffer(
    capabilities: TerminalCapabilities(colorSupport: autoDetected),
  );
  renderSpan(
    allLines,
    buffer2,
  );
  print(buffer2);
}

void _printTrueColorVs256() {
  const steps = 32;
  print('');
  print('=== Comparison: True Color vs 256-Color ===');
  print('If both lines look identical, true color may not be supported.');
  print('');

  // True color gradient (should be smooth)
  final trueColorBuffer = StringBuffer();
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final r = (255 * t).round();
    final g = (255 * (1 - t)).round();
    trueColorBuffer.write('\x1B[48;2;$r;$g;0m  \x1B[0m');
  }

  // 256-color approximation (will show banding)
  final color256Buffer = StringBuffer();
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    // Map to 6x6x6 color cube (values 0-5)
    final r6 = (5 * t).round();
    final g6 = (5 * (1 - t)).round();
    // 256-color cube formula: 16 + 36*r + 6*g + b
    final colorIndex = 16 + 36 * r6 + 6 * g6;
    color256Buffer.write('\x1B[48;5;${colorIndex}m  \x1B[0m');
  }

  print('True Color (38;2;r;g;b): $trueColorBuffer');
  print('256-Color  (38;5;n):     $color256Buffer');
  print('');
  print('The 256-color line should show visible banding/steps.');
  print('If both look the same, true color is NOT working.');
  print('');
}
