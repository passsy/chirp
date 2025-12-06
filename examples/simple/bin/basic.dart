/// Basic example: Zero-config logging that just works.
///
/// Run with: dart run bin/basic.dart
import 'package:chirp/chirp.dart';

void main() {
  // No configuration needed - just log!
  Chirp.info('Application started');
  Chirp.debug('Loading configuration...');
  Chirp.warning('Using default settings');
  Chirp.error('Connection failed', error: Exception('timeout'));
}

// Output:
// 14:32:05.123 [info] Application started
// 14:32:05.124 [debug] Loading configuration...
// 14:32:05.125 [warning] Using default settings
// 14:32:05.126 [error] Connection failed
//   Exception: timeout
