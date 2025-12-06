/// Example: Instance tracking with the `.chirp` extension.
///
/// Run with: dart run bin/instance_tracking.dart
import 'package:chirp/chirp.dart';

void main() {
  final service1 = UserService();
  final service2 = UserService();

  // Different instances get different hashes
  service1.doWork();
  service2.doWork();

  // Static methods use Chirp (no instance to track)
  UserService.validateConfig();
}

class UserService {
  void doWork() {
    // chirp.info() tracks which instance is logging
    chirp.info('Processing request');
  }

  static void validateConfig() {
    // Chirp.info() for static methods (no instance)
    Chirp.info('Validating configuration');
  }
}

// Output - different instances have different hashes:
// 14:32:05.123 UserService@a1b2 [info] Processing request
// 14:32:05.124 UserService@c3d4 [info] Processing request
// 14:32:05.125 [info] Validating configuration
