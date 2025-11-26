import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('formatAsYaml', () {
    group('null values', () {
      test('formats null at root level', () {
        final result = formatAsYaml(null);
        expect(result, ['null']);
      });

      test('formats null with indentation', () {
        final result = formatAsYaml(null, indent: 2);
        expect(result, ['    null']);
      });
    });

    group('maps', () {
      test('formats empty map', () {
        final result = formatAsYaml({});
        expect(result, ['{}']);
      });

      test('formats empty map with indentation', () {
        final result = formatAsYaml({}, indent: 1);
        expect(result, ['  {}']);
      });

      test('formats simple map', () {
        final result = formatAsYaml({'key': 'value'}, indent: 0);
        expect(result, ['key: "value"']);
      });

      test('formats nested map', () {
        final result = formatAsYaml({
          'outer': {'inner': 'value'}
        });
        expect(result, [
          'outer:',
          '  inner: "value"',
        ]);
      });

      test('formats map with empty nested map', () {
        final result = formatAsYaml({'outer': <String, Object?>{}});
        expect(result, ['outer: {}']);
      });

      test('formats map with empty nested list', () {
        final result = formatAsYaml({'outer': <Object?>[]});
        expect(result, ['outer: []']);
      });

      test('formats map with nested list', () {
        final result = formatAsYaml({
          'items': ['a', 'b']
        });
        expect(result, [
          'items:',
          '  - "a"',
          '  - "b"',
        ]);
      });
    });

    group('lists', () {
      test('formats empty list', () {
        final result = formatAsYaml([]);
        expect(result, ['[]']);
      });

      test('formats empty list with indentation', () {
        final result = formatAsYaml([], indent: 1);
        expect(result, ['  []']);
      });

      test('formats simple list', () {
        final result = formatAsYaml(['a', 'b', 'c']);
        expect(result, [
          '- "a"',
          '- "b"',
          '- "c"',
        ]);
      });

      test('formats list with nested map', () {
        final result = formatAsYaml([
          {'name': 'item1'}
        ]);
        expect(result, [
          '-',
          '  name: "item1"',
        ]);
      });

      test('formats list with nested list', () {
        final result = formatAsYaml([
          ['a', 'b']
        ]);
        expect(result, [
          '-',
          '  - "a"',
          '  - "b"',
        ]);
      });

      test('formats list with empty nested map', () {
        final result = formatAsYaml([<String, Object?>{}]);
        expect(result, ['- {}']);
      });

      test('formats list with empty nested list', () {
        final result = formatAsYaml([<Object?>[]]);
        expect(result, ['- []']);
      });
    });

    group('scalar values', () {
      test('formats string at root level', () {
        final result = formatAsYaml('hello');
        expect(result, ['"hello"']);
      });

      test('formats number at root level', () {
        final result = formatAsYaml(42);
        expect(result, ['42']);
      });

      test('formats boolean at root level', () {
        final result = formatAsYaml(true);
        expect(result, ['true']);
      });

      test('formats scalar with indentation', () {
        final result = formatAsYaml('hello', indent: 2);
        expect(result, ['    "hello"']);
      });
    });

    group('complex nested structures', () {
      test('formats deeply nested structure', () {
        final result = formatAsYaml({
          'level1': {
            'level2': {'level3': 'deep'}
          }
        });
        expect(result, [
          'level1:',
          '  level2:',
          '    level3: "deep"',
        ]);
      });

      test('formats mixed nested structure', () {
        final result = formatAsYaml({
          'users': [
            {'name': 'Alice', 'age': 30},
            {'name': 'Bob', 'age': 25},
          ]
        });
        expect(result, [
          'users:',
          '  -',
          '    name: "Alice"',
          '    age: 30',
          '  -',
          '    name: "Bob"',
          '    age: 25',
        ]);
      });
    });
  });

  group('formatYamlKey', () {
    test('returns simple key as-is', () {
      expect(formatYamlKey('simple'), 'simple');
    });

    test('quotes key with space', () {
      expect(formatYamlKey('has space'), '"has space"');
    });

    test('quotes key with colon', () {
      expect(formatYamlKey('has:colon'), '"has:colon"');
    });

    test('quotes key with hash', () {
      expect(formatYamlKey('has#hash'), '"has#hash"');
    });

    test('quotes key with newline', () {
      expect(formatYamlKey('has\nnewline'), '"has\\nnewline"');
    });

    test('quotes key with tab', () {
      expect(formatYamlKey('has\ttab'), '"has\\ttab"');
    });

    test('escapes backslash in quoted key', () {
      // Key with backslash and space triggers quoting
      expect(formatYamlKey('has\\back slash'), '"has\\\\back slash"');
    });

    test('escapes double quote in quoted key', () {
      expect(formatYamlKey('has"quote and space'), '"has\\"quote and space"');
    });

    test('does not quote key with only backslash', () {
      // Backslash alone doesn't trigger quoting
      expect(formatYamlKey('has\\backslash'), 'has\\backslash');
    });

    test('escapes carriage return when key is quoted', () {
      // Key with space triggers quoting, then \r is escaped
      expect(
          formatYamlKey('has\rreturn and space'), '"has\\rreturn and space"');
    });
  });

  group('formatYamlValue', () {
    test('formats null', () {
      expect(formatYamlValue(null), 'null');
    });

    test('formats string with quotes', () {
      expect(formatYamlValue('hello'), '"hello"');
    });

    test('escapes backslash in string', () {
      expect(formatYamlValue('back\\slash'), '"back\\\\slash"');
    });

    test('escapes double quote in string', () {
      expect(formatYamlValue('has"quote'), '"has\\"quote"');
    });

    test('escapes newline in string', () {
      expect(formatYamlValue('line1\nline2'), '"line1\\nline2"');
    });

    test('escapes carriage return in string', () {
      expect(formatYamlValue('line1\rline2'), '"line1\\rline2"');
    });

    test('escapes tab in string', () {
      expect(formatYamlValue('col1\tcol2'), '"col1\\tcol2"');
    });

    test('formats integer without quotes', () {
      expect(formatYamlValue(42), '42');
    });

    test('formats double without quotes', () {
      expect(formatYamlValue(3.14), '3.14');
    });

    test('formats boolean without quotes', () {
      expect(formatYamlValue(true), 'true');
      expect(formatYamlValue(false), 'false');
    });

    test('formats other objects using toString', () {
      final customObject = _CustomObject();
      expect(formatYamlValue(customObject), 'CustomObjectValue');
    });
  });
}

class _CustomObject {
  @override
  String toString() => 'CustomObjectValue';
}
