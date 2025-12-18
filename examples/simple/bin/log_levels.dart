/// Example: All 9 built-in log levels plus custom levels.
///
/// Run with: dart run bin/log_levels.dart
import 'package:chirp/chirp.dart';

void main() {
  // All 9 built-in levels (ordered by severity)
  Chirp.trace('Detailed execution trace', data: {'step': 1});
  Chirp.debug('Debug information', data: {'cache': 'miss'});
  Chirp.info('Application started');
  Chirp.notice('Configuration changed', data: {'key': 'timeout', 'value': 30});
  Chirp.success('Deployment completed', data: {'version': '1.2.0'});
  Chirp.warning('Deprecated API used', data: {'api': 'v1'});
  Chirp.error('Operation failed', error: Exception('Timeout'));
  Chirp.critical('Database connection lost');
  Chirp.wtf(
    'User age is negative',
    data: {'age': -5},
  ); // What a Terrible Failure

  // Custom log levels
  const verbose = ChirpLogLevel('verbose', 50); // Between trace and debug
  const alert = ChirpLogLevel('alert', 550); // Between error and critical

  Chirp.log('Very detailed info', level: verbose);
  Chirp.log('System alert!', level: alert);
}
