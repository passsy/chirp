import 'package:chirp_protocol/chirp_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ChirpLogLevel', () {
    group('static constants', () {
      test('trace has correct name and severity', () {
        expect(ChirpLogLevel.trace.name, 'trace');
        expect(ChirpLogLevel.trace.severity, 0);
      });

      test('debug has correct name and severity', () {
        expect(ChirpLogLevel.debug.name, 'debug');
        expect(ChirpLogLevel.debug.severity, 100);
      });

      test('info has correct name and severity', () {
        expect(ChirpLogLevel.info.name, 'info');
        expect(ChirpLogLevel.info.severity, 200);
      });

      test('notice has correct name and severity', () {
        expect(ChirpLogLevel.notice.name, 'notice');
        expect(ChirpLogLevel.notice.severity, 300);
      });

      test('warning has correct name and severity', () {
        expect(ChirpLogLevel.warning.name, 'warning');
        expect(ChirpLogLevel.warning.severity, 400);
      });

      test('error has correct name and severity', () {
        expect(ChirpLogLevel.error.name, 'error');
        expect(ChirpLogLevel.error.severity, 500);
      });

      test('critical has correct name and severity', () {
        expect(ChirpLogLevel.critical.name, 'critical');
        expect(ChirpLogLevel.critical.severity, 600);
      });

      test('wtf has correct name and severity', () {
        expect(ChirpLogLevel.wtf.name, 'wtf');
        expect(ChirpLogLevel.wtf.severity, 1000);
      });

      test('severity levels are in ascending order', () {
        expect(ChirpLogLevel.trace.severity, lessThan(ChirpLogLevel.debug.severity));
        expect(ChirpLogLevel.debug.severity, lessThan(ChirpLogLevel.info.severity));
        expect(ChirpLogLevel.info.severity, lessThan(ChirpLogLevel.notice.severity));
        expect(ChirpLogLevel.notice.severity, lessThan(ChirpLogLevel.warning.severity));
        expect(ChirpLogLevel.warning.severity, lessThan(ChirpLogLevel.error.severity));
        expect(ChirpLogLevel.error.severity, lessThan(ChirpLogLevel.critical.severity));
        expect(ChirpLogLevel.critical.severity, lessThan(ChirpLogLevel.wtf.severity));
      });
    });

    group('custom log levels', () {
      test('can create custom log level with constructor', () {
        const custom = ChirpLogLevel('verbose', 50);
        expect(custom.name, 'verbose');
        expect(custom.severity, 50);
      });

      test('custom levels can have any severity value', () {
        const lowSeverity = ChirpLogLevel('very-low', -100);
        const highSeverity = ChirpLogLevel('very-high', 10000);

        expect(lowSeverity.severity, -100);
        expect(highSeverity.severity, 10000);
      });

      test('custom levels can fit between standard levels', () {
        const verbose = ChirpLogLevel('verbose', 50);
        const alert = ChirpLogLevel('alert', 450);

        expect(verbose.severity, greaterThan(ChirpLogLevel.trace.severity));
        expect(verbose.severity, lessThan(ChirpLogLevel.debug.severity));

        expect(alert.severity, greaterThan(ChirpLogLevel.warning.severity));
        expect(alert.severity, lessThan(ChirpLogLevel.error.severity));
      });
    });

    group('properties', () {
      test('name is accessible', () {
        expect(ChirpLogLevel.info.name, 'info');
        const custom = ChirpLogLevel('custom', 250);
        expect(custom.name, 'custom');
      });

      test('severity is accessible', () {
        expect(ChirpLogLevel.info.severity, 200);
        const custom = ChirpLogLevel('custom', 250);
        expect(custom.severity, 250);
      });
    });

    group('comparison operators', () {
      test('< operator compares by severity', () {
        expect(ChirpLogLevel.trace < ChirpLogLevel.debug, isTrue);
        expect(ChirpLogLevel.debug < ChirpLogLevel.info, isTrue);
        expect(ChirpLogLevel.info < ChirpLogLevel.warning, isTrue);
        expect(ChirpLogLevel.warning < ChirpLogLevel.error, isTrue);
        expect(ChirpLogLevel.error < ChirpLogLevel.critical, isTrue);
        expect(ChirpLogLevel.critical < ChirpLogLevel.wtf, isTrue);

        expect(ChirpLogLevel.debug < ChirpLogLevel.trace, isFalse);
        expect(ChirpLogLevel.info < ChirpLogLevel.info, isFalse);
      });

      test('<= operator compares by severity', () {
        expect(ChirpLogLevel.trace <= ChirpLogLevel.debug, isTrue);
        expect(ChirpLogLevel.info <= ChirpLogLevel.info, isTrue);
        expect(ChirpLogLevel.error <= ChirpLogLevel.warning, isFalse);
      });

      test('> operator compares by severity', () {
        expect(ChirpLogLevel.debug > ChirpLogLevel.trace, isTrue);
        expect(ChirpLogLevel.info > ChirpLogLevel.debug, isTrue);
        expect(ChirpLogLevel.warning > ChirpLogLevel.info, isTrue);
        expect(ChirpLogLevel.error > ChirpLogLevel.warning, isTrue);
        expect(ChirpLogLevel.critical > ChirpLogLevel.error, isTrue);
        expect(ChirpLogLevel.wtf > ChirpLogLevel.critical, isTrue);

        expect(ChirpLogLevel.trace > ChirpLogLevel.debug, isFalse);
        expect(ChirpLogLevel.info > ChirpLogLevel.info, isFalse);
      });

      test('>= operator compares by severity', () {
        expect(ChirpLogLevel.debug >= ChirpLogLevel.trace, isTrue);
        expect(ChirpLogLevel.info >= ChirpLogLevel.info, isTrue);
        expect(ChirpLogLevel.warning >= ChirpLogLevel.error, isFalse);
      });

      test('comparison operators work with custom levels', () {
        const verbose = ChirpLogLevel('verbose', 50);
        const alert = ChirpLogLevel('alert', 450);

        expect(verbose < ChirpLogLevel.debug, isTrue);
        expect(verbose > ChirpLogLevel.trace, isTrue);

        expect(alert < ChirpLogLevel.error, isTrue);
        expect(alert > ChirpLogLevel.warning, isTrue);

        expect(verbose < alert, isTrue);
        expect(alert > verbose, isTrue);
      });
    });

    group('equality', () {
      test('same instance is equal to itself', () {
        expect(ChirpLogLevel.info, equals(ChirpLogLevel.info));
        expect(ChirpLogLevel.info == ChirpLogLevel.info, isTrue);
      });

      test('different instances with same name and severity are equal', () {
        const level1 = ChirpLogLevel('custom', 250);
        const level2 = ChirpLogLevel('custom', 250);

        expect(level1, equals(level2));
        expect(level1 == level2, isTrue);
      });

      test('levels with different names are not equal', () {
        const level1 = ChirpLogLevel('custom1', 250);
        const level2 = ChirpLogLevel('custom2', 250);

        expect(level1, isNot(equals(level2)));
        expect(level1 == level2, isFalse);
      });

      test('levels with different severity are not equal', () {
        const level1 = ChirpLogLevel('custom', 250);
        const level2 = ChirpLogLevel('custom', 251);

        expect(level1, isNot(equals(level2)));
        expect(level1 == level2, isFalse);
      });

      test('levels with different name and severity are not equal', () {
        expect(ChirpLogLevel.info, isNot(equals(ChirpLogLevel.warning)));
        expect(ChirpLogLevel.info == ChirpLogLevel.warning, isFalse);
      });

      test('level is not equal to non-ChirpLogLevel object', () {
        expect(ChirpLogLevel.info == 'info', isFalse);
        expect(ChirpLogLevel.info == 200, isFalse);
        expect(ChirpLogLevel.info == null, isFalse);
      });
    });

    group('hashCode', () {
      test('equal objects have equal hashCodes', () {
        const level1 = ChirpLogLevel('custom', 250);
        const level2 = ChirpLogLevel('custom', 250);

        expect(level1.hashCode, equals(level2.hashCode));
      });

      test('same instance has consistent hashCode', () {
        final hashCode1 = ChirpLogLevel.info.hashCode;
        final hashCode2 = ChirpLogLevel.info.hashCode;

        expect(hashCode1, equals(hashCode2));
      });

      test('different levels typically have different hashCodes', () {
        // Note: Different objects CAN have the same hashCode (hash collision)
        // but it's unlikely for these specific values
        expect(
          ChirpLogLevel.info.hashCode,
          isNot(equals(ChirpLogLevel.warning.hashCode)),
        );
      });
    });

    group('toString', () {
      test('toString returns name for standard levels', () {
        expect(ChirpLogLevel.trace.toString(), 'trace');
        expect(ChirpLogLevel.debug.toString(), 'debug');
        expect(ChirpLogLevel.info.toString(), 'info');
        expect(ChirpLogLevel.notice.toString(), 'notice');
        expect(ChirpLogLevel.warning.toString(), 'warning');
        expect(ChirpLogLevel.error.toString(), 'error');
        expect(ChirpLogLevel.critical.toString(), 'critical');
        expect(ChirpLogLevel.wtf.toString(), 'wtf');
      });

      test('toString returns name for custom levels', () {
        const verbose = ChirpLogLevel('verbose', 50);
        const alert = ChirpLogLevel('alert', 450);

        expect(verbose.toString(), 'verbose');
        expect(alert.toString(), 'alert');
      });
    });

    group('API stability tests', () {
      test('all standard level constants exist and are const', () {
        // This test ensures the public API constants don't get renamed/removed
        const levels = [
          ChirpLogLevel.trace,
          ChirpLogLevel.debug,
          ChirpLogLevel.info,
          ChirpLogLevel.notice,
          ChirpLogLevel.warning,
          ChirpLogLevel.error,
          ChirpLogLevel.critical,
          ChirpLogLevel.wtf,
        ];

        expect(levels.length, 8);
      });

      test('severity values remain stable', () {
        // Changing these values would be a breaking change
        expect(ChirpLogLevel.trace.severity, 0);
        expect(ChirpLogLevel.debug.severity, 100);
        expect(ChirpLogLevel.info.severity, 200);
        expect(ChirpLogLevel.notice.severity, 300);
        expect(ChirpLogLevel.warning.severity, 400);
        expect(ChirpLogLevel.error.severity, 500);
        expect(ChirpLogLevel.critical.severity, 600);
        expect(ChirpLogLevel.wtf.severity, 1000);
      });

      test('constructor accepts name and severity parameters', () {
        // Ensures the constructor signature remains stable
        const level = ChirpLogLevel('test', 123);
        expect(level.name, 'test');
        expect(level.severity, 123);
      });

      test('all comparison operators are available', () {
        final level1 = ChirpLogLevel.info;
        final level2 = ChirpLogLevel.warning;

        // Ensure all operators are callable (compile-time check)
        expect(level1 < level2, isTrue);
        expect(level1 <= level2, isTrue);
        expect(level2 > level1, isTrue);
        expect(level2 >= level1, isTrue);
      });
    });
  });
}
