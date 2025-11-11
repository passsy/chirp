// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  print('=== Comparison: Top-level vs Extension ===\n');

  print('--- Static Chirp.log() - File:Line tracking ---');
  topLevelExample();

  print('\n--- Extension .chirp - Instance tracking ---');
  extensionExample();

  print('\n--- The Key Difference ---');
  demonstrateDifference();
}

void topLevelExample() {
  // Using static Chirp.log() - tracks file and line number
  Chirp.log('Message from top-level function');

  final service = UserService();
  service.processWithTopLevel();
}

void extensionExample() {
  // Using extension .chirp - tracks instance hash
  final service = UserService();
  service.processWithExtension();
}

void demonstrateDifference() {
  print('\nCreating two instances of the same class:\n');

  final service1 = UserService();
  final service2 = UserService();

  print('Using static Chirp.log() - SAME file:line:');
  service1.processWithTopLevel();
  service2.processWithTopLevel();

  print('\nUsing extension .chirp - DIFFERENT instance hashes:');
  service1.processWithExtension();
  service2.processWithExtension();

  print(
      '\n💡 Notice: Extension .chirp gives unique hashes (e.g., a1b2, c3d4)');
  print('   Static Chirp.log() gives file:line (same for both: main:XX)');
}

class UserService {
  void processWithTopLevel() {
    // Using static Chirp.log() method - tracks file:line
    Chirp.log('Processing with static method');
  }

  void processWithExtension() {
    // Using extension - gets instance hash via identityHashCode(this)
    // This is the natural way to use it
    chirp.log('Processing with extension');
  }
}

// Top-level helper to demonstrate true top-level usage
void logFromTopLevel() {
  // Here, Chirp.log() is the static method (no instance)
  Chirp.log('From true top-level context');
}
