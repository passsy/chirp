/// Example: Lazy message construction to avoid expensive string building.
///
/// Run with: dart run bin/lazy_messages.dart
import 'dart:convert';

import 'package:chirp/chirp.dart';

void main() {
  // Configure logger with warning as minimum level.
  // trace and debug messages will be filtered out.
  Chirp.root = ChirpLogger()
    .setMinLogLevel(ChirpLogLevel.warning)
    .addConsoleWriter();

  final hugeMap = {
    'users': List.generate(1000, (i) => {'id': i, 'name': 'User $i'}),
  };

  // Without lazy messages: jsonEncode() runs even though trace is filtered out
  Chirp.trace('User data: ${jsonEncode(hugeMap)}');

  // With lazy messages: the lambda is never called because trace is filtered
  Chirp.trace(() => 'User data: ${jsonEncode(hugeMap)}');

  // Works with all log levels
  Chirp.warning(() => 'This warning is logged');
  Chirp.error(() => 'This error is logged');

  // Plain strings still work as before
  Chirp.warning('Plain string warning');
}

// Output (only warning and above are shown):
// ... [warning] This warning is logged
// ... [error] This error is logged
// ... [warning] Plain string warning
