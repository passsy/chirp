// ignore_for_file: avoid_print

import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger().addConsoleWriter(
    formatter: SimpleConsoleMessageFormatter(),
  );
  print('Testing instance hash tracking:\n');

  final service1 = UserService();
  final service2 = UserService();

  print('Service 1 hash: ${service1.hashCode}');
  print('Service 2 hash: ${service2.hashCode}\n');

  print('Logging with extension:\n');
  service1.chirp.log('From service 1');
  service2.chirp.log('From service 2');

  print('Logging from inside the service');
  service1.someMethod();
  service2.someMethod();

  print('\n\nLogging from top-level context:\n');
  Chirp.log('From top-level - no instance');
}

class UserService {
  // Empty class to test instance tracking

  void someMethod() {
    chirp.info('message 1');
    Chirp.info('message 2');
  }
}
