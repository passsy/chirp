/// Example: Lazy message and lazy log construction.
///
/// Run with: dart run bin/lazy_messages.dart
import 'dart:convert';

import 'package:chirp/chirp.dart';

void main() {
  // Configure logger with warning as minimum level.
  // trace and debug messages will be filtered out.
  Chirp.root =
      ChirpLogger().setMinLogLevel(ChirpLogLevel.warning).addConsoleWriter();

  final hugeMap = {
    'users': List.generate(1000, (i) => {'id': i, 'name': 'User $i'}),
  };

  // Without lazy: jsonEncode() runs even though trace is filtered out.
  Chirp.trace('User data: ${jsonEncode(hugeMap)}');

  // Lazy message: the lambda is never called because trace is filtered.
  Chirp.trace(() => 'User data: ${jsonEncode(hugeMap)}');

  // traceLazy / warningLazy / etc.: defer EVERY argument (message, data,
  // error, …) until the logger has decided to actually emit. Use this when
  // expensive work is in the structured `data` map, not just the message.
  Chirp.traceLazy(
    (log) => log('User data', data: {'snapshot': jsonEncode(hugeMap)}),
  );

  // Works at every level.
  Chirp.warningLazy(
    (log) => log('Rendered users', data: {'count': hugeMap.length}),
  );
  Chirp.errorLazy((log) => log('This error is logged'));

  // Plain strings and lazy messages still work as before.
  Chirp.warning('Plain string warning');
  Chirp.warning(() => 'Lazy string warning');
}

// Output (only warning and above are shown):
// ... [warning] Rendered users {count: 1}
// ... [error] This error is logged
// ... [warning] Plain string warning
// ... [warning] Lazy string warning
