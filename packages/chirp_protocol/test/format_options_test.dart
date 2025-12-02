import 'package:chirp_protocol/chirp_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('FormatOptions', () {
    test('can be const-constructed', () {
      const options = FormatOptions();
      expect(options, isA<FormatOptions>());
    });

    test('is usable as a const value', () {
      const options = FormatOptions();
      const list = [options];
      expect(list.first, isA<FormatOptions>());
    });

    test('two const instances are identical', () {
      const options1 = FormatOptions();
      const options2 = FormatOptions();
      expect(identical(options1, options2), isTrue);
    });

    test('can be extended with custom subclass', () {
      const custom = _CustomFormatOptions();
      expect(custom, isA<FormatOptions>());
      expect(custom, isA<_CustomFormatOptions>());
    });

    test('can be implemented by custom classes', () {
      const custom = _ImplementingFormatOptions(value: 42);
      expect(custom, isA<FormatOptions>());
      expect(custom, isA<_ImplementingFormatOptions>());
      expect(custom.value, 42);
    });

    test('subclass can be const-constructed', () {
      const custom = _CustomFormatOptions();
      expect(custom, isA<_CustomFormatOptions>());
    });

    test('subclass can add properties with default values', () {
      const custom = _CustomFormatOptions();
      expect(custom.uppercase, isFalse);
      expect(custom.maxLength, 100);
    });

    test('subclass can override properties', () {
      const custom = _CustomFormatOptions(uppercase: true, maxLength: 50);
      expect(custom.uppercase, isTrue);
      expect(custom.maxLength, 50);
    });

    test('subclass instances with same values are identical', () {
      const custom1 = _CustomFormatOptions(uppercase: true, maxLength: 50);
      const custom2 = _CustomFormatOptions(uppercase: true, maxLength: 50);
      expect(identical(custom1, custom2), isTrue);
    });

    test('subclass instances with different values are not identical', () {
      const custom1 = _CustomFormatOptions(uppercase: true);
      const custom2 = _CustomFormatOptions();
      expect(identical(custom1, custom2), isFalse);
    });

    test('can create list of mixed FormatOptions subclasses', () {
      const options = <FormatOptions>[
        FormatOptions(),
        _CustomFormatOptions(),
        _AnotherCustomFormatOptions(color: 'red'),
      ];

      expect(options.length, 3);
      expect(options[0], isA<FormatOptions>());
      expect(options[1], isA<_CustomFormatOptions>());
      expect(options[2], isA<_AnotherCustomFormatOptions>());
    });

    test('subclasses can be filtered by type', () {
      const options = <FormatOptions>[
        FormatOptions(),
        _CustomFormatOptions(uppercase: true),
        _AnotherCustomFormatOptions(color: 'red'),
        _CustomFormatOptions(maxLength: 50),
      ];

      final customOptions = options.whereType<_CustomFormatOptions>().toList();
      expect(customOptions.length, 2);
      expect(customOptions[0].uppercase, isTrue);
      expect(customOptions[1].maxLength, 50);

      final anotherOptions =
          options.whereType<_AnotherCustomFormatOptions>().toList();
      expect(anotherOptions.length, 1);
      expect(anotherOptions[0].color, 'red');
    });

    test('base class has no properties', () {
      const options = FormatOptions();
      // This test verifies the API surface - FormatOptions should remain
      // a simple marker class with no properties
      expect(options.runtimeType.toString(), 'FormatOptions');
    });

    test('can be used in const collections', () {
      const map = <String, FormatOptions>{
        'default': FormatOptions(),
        'custom': _CustomFormatOptions(uppercase: true),
      };

      expect(map['default'], isA<FormatOptions>());
      expect(map['custom'], isA<_CustomFormatOptions>());
    });

    test('subclass with multiple properties works correctly', () {
      const options = _ComplexFormatOptions(
        uppercase: true,
        maxLength: 80,
        prefix: '[LOG]',
        showTimestamp: false,
      );

      expect(options.uppercase, isTrue);
      expect(options.maxLength, 80);
      expect(options.prefix, '[LOG]');
      expect(options.showTimestamp, isFalse);
    });

    test('nullable properties in subclass work correctly', () {
      const options1 = _NullablePropertiesOptions();
      expect(options1.optionalValue, isNull);
      expect(options1.optionalInt, isNull);

      const options2 = _NullablePropertiesOptions(
        optionalValue: 'test',
        optionalInt: 42,
      );
      expect(options2.optionalValue, 'test');
      expect(options2.optionalInt, 42);
    });
  });
}

/// Test subclass with basic properties
class _CustomFormatOptions extends FormatOptions {
  const _CustomFormatOptions({
    this.uppercase = false,
    this.maxLength = 100,
  });

  final bool uppercase;
  final int maxLength;
}

/// Test subclass with different properties
class _AnotherCustomFormatOptions extends FormatOptions {
  const _AnotherCustomFormatOptions({
    this.color = 'white',
  });

  final String color;
}

/// Test subclass with multiple properties of different types
class _ComplexFormatOptions extends FormatOptions {
  const _ComplexFormatOptions({
    this.uppercase = false,
    this.maxLength = 100,
    this.prefix = '',
    this.showTimestamp = true,
  });

  final bool uppercase;
  final int maxLength;
  final String prefix;
  final bool showTimestamp;
}

/// Test subclass with nullable properties
class _NullablePropertiesOptions extends FormatOptions {
  const _NullablePropertiesOptions({
    this.optionalValue,
    this.optionalInt,
  });

  final String? optionalValue;
  final int? optionalInt;
}

/// Test class that implements FormatOptions instead of extending it
class _ImplementingFormatOptions implements FormatOptions {
  const _ImplementingFormatOptions({required this.value});

  final int value;
}
