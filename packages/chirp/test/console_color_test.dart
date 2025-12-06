import 'package:chirp/chirp.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultColor', () {
    test('DefaultColor() returns identical instances (singleton)', () {
      final a = DefaultColor();
      final b = DefaultColor();
      expect(identical(a, b), isTrue);
    });

    test('all DefaultColor instances are equal', () {
      final a = DefaultColor();
      final b = DefaultColor();
      expect(a, equals(b));
      expect(a == b, isTrue);
    });
  });
}
