import 'package:chirp/src/stack_trace_util.dart';
import 'package:test/test.dart';

void main() {
  // ignore: prefer_const_declarations
  final testStackTrace = StackTrace.empty;

  group('parseStackFrame', () {
    group('Android/iOS VM stack traces', () {
      test('parses standard VM stack trace with line and column', () {
        const frame =
            '#2      UserService.processUser (file:///Users/pascalwelsch/Projects/passsy/chirp/example/main.dart:168:11)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'UserService.processUser');
        expect(
          result.file,
          'file:///Users/pascalwelsch/Projects/passsy/chirp/example/main.dart',
        );
        expect(result.line, 168);
        expect(result.column, 11);
      });

      test('parses VM stack trace with package: URI', () {
        const frame =
            '#0      MyClass.method (package:my_app/my_file.dart:42:10)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'MyClass.method');
        expect(result.file, 'package:my_app/my_file.dart');
        expect(result.line, 42);
        expect(result.column, 10);
      });

      test('parses VM stack trace without column', () {
        const frame = '#1      main (file:///path/to/my_file.dart:123)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'main');
        expect(result.file, 'file:///path/to/my_file.dart');
        expect(result.line, 123);
        expect(result.column, isNull);
      });

      test('parses VM stack trace with top-level function', () {
        const frame = '#3      doSomething (package:app/utils.dart:99:5)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'doSomething');
        expect(result.file, 'package:app/utils.dart');
        expect(result.line, 99);
        expect(result.column, 5);
      });

      test('parses VM stack trace with async modifier', () {
        const frame =
            '#4      MyClass.asyncMethod (package:my_app/service.dart:200:15)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'MyClass.asyncMethod');
        expect(result.file, 'package:my_app/service.dart');
        expect(result.line, 200);
        expect(result.column, 15);
      });

      test('parses VM stack trace with nested class', () {
        const frame =
            '#5      OuterClass.InnerClass.method (package:my_app/nested.dart:50:3)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'OuterClass.InnerClass.method');
        expect(result.file, 'package:my_app/nested.dart');
        expect(result.line, 50);
        expect(result.column, 3);
      });

      test('parses VM stack trace with closure', () {
        const frame =
            '#6      MyClass.method.<anonymous closure> (package:my_app/closures.dart:75:20)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.rawCallerMethod, 'MyClass.method.<anonymous closure>');
        expect(result.callerMethod, 'MyClass.method');
        expect(result.file, 'package:my_app/closures.dart');
        expect(result.line, 75);
        expect(result.column, 20);
      });
    });

    group('Flutter Web (dart2js) stack traces', () {
      test('parses dart2js stack trace with "at" prefix', () {
        const frame =
            'at Object.MyClass_method (packages/my_app/my_file.dart:42:10)';

        final result = parseStackFrame(testStackTrace, frame);

        // Should extract the file reference even if the format is different
        expect(result, isNotNull);
        expect(result!.file, 'packages/my_app/my_file.dart');
        expect(result.line, 42);
      });

      test('parses web stack trace without method name in parentheses', () {
        const frame = 'packages/my_app/utils.dart:100:5  helperFunction';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.file, 'packages/my_app/utils.dart');
        expect(result.line, 100);
      });

      test('parses dart-sdk internal frame', () {
        const frame = 'dart-sdk/lib/async/schedule_microtask.dart:40:5';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.file, 'dart-sdk/lib/async/schedule_microtask.dart');
        expect(result.line, 40);
      });
    });

    group('Browser/JavaScript stack traces', () {
      test('parses browser stack trace with http URL', () {
        const frame =
            'at MyClass.method (http://localhost:8080/main.dart:50:20)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.file, 'http://localhost:8080/main.dart');
        expect(result.line, 50);
      });

      test('parses Chrome-style stack trace', () {
        const frame =
            '    at processData (file:///C:/Projects/app/lib/service.dart:123:15)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.file, 'file:///C:/Projects/app/lib/service.dart');
        expect(result.line, 123);
      });
    });

    group('Fallback patterns', () {
      test('parses file reference without method name', () {
        const frame = 'my_file.dart:42';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, '<unknown>');
        expect(result.file, 'my_file.dart');
        expect(result.line, 42);
        expect(result.column, isNull);
      });

      test('parses filename with underscores and numbers', () {
        const frame = 'user_service_v2.dart:999';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.file, 'user_service_v2.dart');
        expect(result.line, 999);
      });
    });

    group('Edge cases', () {
      test('returns null for empty string', () {
        const frame = '';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNull);
      });

      test('returns null for whitespace only', () {
        const frame = '   \n  \t  ';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNull);
      });

      test('returns null for non-Dart file reference', () {
        const frame = '#0      someFunction (file.txt:10:5)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNull);
      });

      test('returns null for malformed frame', () {
        const frame = 'random text without proper format';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNull);
      });

      test('returns null for obfuscated stack trace', () {
        const frame =
            '*** *** *** *** *** *** *** *** *** *** *** *** *** *** ***';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNull);
      });

      test('handles very long method names', () {
        const frame =
            '#0      VeryLongClassName.veryLongMethodNameThatKeepsGoing (package:app/file.dart:1:1)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(
          result!.callerMethod,
          'VeryLongClassName.veryLongMethodNameThatKeepsGoing',
        );
      });

      test('handles frame with special characters in path', () {
        const frame =
            '#0      MyClass.method (file:///Users/user-name/my_app/lib/file.dart:10:5)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(
          result!.file,
          'file:///Users/user-name/my_app/lib/file.dart',
        );
      });
    });

    group('Platform-specific real-world examples', () {
      test('parses Android debug stack trace', () {
        const frame =
            '#0      _AssertionError._throwNew (dart:core-patch/errors_patch.dart:46:39)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, '_AssertionError._throwNew');
        expect(result.file, 'dart:core-patch/errors_patch.dart');
        expect(result.line, 46);
        expect(result.column, 39);
      });

      test('parses iOS release stack trace', () {
        const frame =
            '#1      MyWidget.build (package:flutter_app/widgets/my_widget.dart:89:12)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'MyWidget.build');
        expect(result.file, 'package:flutter_app/widgets/my_widget.dart');
        expect(result.line, 89);
        expect(result.column, 12);
      });

      test('parses Flutter Web production stack trace', () {
        const frame = 'packages/flutter/src/widgets/framework.dart:5000:15';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.file, 'packages/flutter/src/widgets/framework.dart');
        expect(result.line, 5000);
      });

      test('parses Windows desktop stack trace', () {
        const frame =
            '#2      main (file:///C:/Users/Developer/Projects/app/lib/main.dart:25:7)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'main');
        expect(
          result.file,
          'file:///C:/Users/Developer/Projects/app/lib/main.dart',
        );
        expect(result.line, 25);
        expect(result.column, 7);
      });

      test('parses macOS desktop stack trace', () {
        const frame =
            '#3      AppState.initState (file:///Users/dev/flutter_app/lib/app.dart:150:3)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'AppState.initState');
        expect(result.file, 'file:///Users/dev/flutter_app/lib/app.dart');
        expect(result.line, 150);
        expect(result.column, 3);
      });

      test('parses Linux desktop stack trace', () {
        const frame =
            '#4      DatabaseService.query (file:///home/user/projects/app/lib/db.dart:200:9)';

        final result = parseStackFrame(testStackTrace, frame);

        expect(result, isNotNull);
        expect(result!.callerMethod, 'DatabaseService.query');
        expect(result.file, 'file:///home/user/projects/app/lib/db.dart');
        expect(result.line, 200);
        expect(result.column, 9);
      });
    });
  });

  group('StackFrameInfo', () {
    test('callerLocation returns simplified location', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'MyClass.method',
        file: 'package:my_app/services/my_service.dart',
        line: 42,
        column: 10,
      );

      expect(info.callerLocation, 'my_service:42');
    });

    test('callerLocation handles file:// URIs', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'main',
        file: 'file:///Users/dev/app/lib/main.dart',
        line: 123,
      );

      expect(info.callerLocation, 'main:123');
    });

    test('callerName returns file name without extension', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'MyClass.method',
        file: 'package:my_app/services/my_service.dart',
        line: 42,
        column: 10,
      );

      expect(info.callerFileName, 'my_service');
    });

    test('callerName handles file:// URIs', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'main',
        file: 'file:///Users/dev/app/lib/main.dart',
        line: 123,
      );

      expect(info.callerFileName, 'main');
    });

    test('callerClassName extracts class from simple method', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'UserService.processUser',
        file: 'package:app/user_service.dart',
        line: 168,
        column: 11,
      );

      expect(info.callerClassName, 'UserService');
    });

    test('callerClassName extracts class from nested class', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'OuterClass.InnerClass.method',
        file: 'package:app/nested.dart',
        line: 50,
        column: 3,
      );

      expect(info.callerClassName, 'OuterClass.InnerClass');
    });

    test('callerClassName extracts class from closure', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'MyClass.method.<anonymous closure>',
        file: 'package:app/closures.dart',
        line: 75,
        column: 20,
      );

      expect(info.callerClassName, 'MyClass');
    });

    test('callerClassName returns null for top-level function', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'main',
        file: 'file:///path/to/main.dart',
        line: 10,
      );

      expect(info.callerClassName, isNull);
    });

    test('callerClassName returns null for doSomething function', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'doSomething',
        file: 'package:app/utils.dart',
        line: 99,
      );

      expect(info.callerClassName, isNull);
    });

    test('callerClassName returns null for <unknown>', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: '<unknown>',
        file: 'my_file.dart',
        line: 42,
      );

      expect(info.callerClassName, isNull);
    });

    test('toString returns full debug information', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'UserService.processUser',
        file: 'package:app/user_service.dart',
        line: 168,
        column: 11,
      );

      expect(
        info.toString(),
        'StackFrameInfo(callerMethod: UserService.processUser, file: package:app/user_service.dart, line: 168, column: 11)',
      );
    });

    test('toString handles null column', () {
      final info = StackFrameInfo(
        stackTrace: testStackTrace,
        rawCallerMethod: 'helper',
        file: 'package:app/utils.dart',
        line: 50,
      );

      expect(
        info.toString(),
        'StackFrameInfo(callerMethod: helper, file: package:app/utils.dart, line: 50, column: null)',
      );
    });
  });

  group('getCallerInfo', () {
    test('extracts first non-chirp frame', () {
      final stackTrace = StackTrace.fromString('''
#0      getCallerInfo (package:chirp/src/stack_trace_util.dart:49:5)
#1      MyClass.method (package:my_app/my_class.dart:100:20)
#2      main (file:///path/to/main.dart:10:5)
''');

      final result = getCallerInfo(stackTrace);

      expect(result, isNotNull);
      expect(result!.callerMethod, 'MyClass.method');
      expect(result.file, 'package:my_app/my_class.dart');
      expect(result.line, 100);
    });

    test('skips dart:core frames', () {
      final stackTrace = StackTrace.fromString('''
#0      Error._throw (dart:core/errors.dart:100:5)
#1      MyClass.validate (package:my_app/validator.dart:50:10)
''');

      final result = getCallerInfo(stackTrace);

      expect(result, isNotNull);
      expect(result!.callerMethod, 'MyClass.validate');
    });

    test('skips dart:async frames', () {
      final stackTrace = StackTrace.fromString('''
#0      _Future._completeError (dart:async/future.dart:100:5)
#1      MyClass.asyncMethod (package:my_app/async.dart:75:12)
''');

      final result = getCallerInfo(stackTrace);

      expect(result, isNotNull);
      expect(result!.callerMethod, 'MyClass.asyncMethod');
    });

    test('honors skipFrames parameter', () {
      final stackTrace = StackTrace.fromString('''
#0      firstMethod (package:my_app/first.dart:10:5)
#1      secondMethod (package:my_app/second.dart:20:5)
#2      thirdMethod (package:my_app/third.dart:30:5)
''');

      final result = getCallerInfo(stackTrace, skipFrames: 2);

      expect(result, isNotNull);
      expect(result!.callerMethod, 'thirdMethod');
      expect(result.line, 30);
    });

    test('returns null for empty stack trace', () {
      final stackTrace = StackTrace.fromString('');

      final result = getCallerInfo(stackTrace);

      expect(result, isNull);
    });

    test('returns null when all frames are internal', () {
      final stackTrace = StackTrace.fromString('''
#0      chirpMethod (package:chirp/chirp.dart:10:5)
#1      Error._throw (dart:core/errors.dart:100:5)
''');

      final result = getCallerInfo(stackTrace);

      expect(result, isNull);
    });
  });

  group('getCallerInfo with callerLocation', () {
    test('returns simplified location string via callerLocation', () {
      final stackTrace = StackTrace.fromString('''
#0      MyClass.method (package:my_app/services/my_service.dart:42:10)
''');

      final result = getCallerInfo(stackTrace)?.callerLocation;

      expect(result, 'my_service:42');
    });

    test('returns null when no valid frame found', () {
      final stackTrace = StackTrace.fromString('invalid stack trace');

      final result = getCallerInfo(stackTrace)?.callerLocation;

      expect(result, isNull);
    });

    test('callerName returns file name without line number', () {
      final stackTrace = StackTrace.fromString('''
#0      MyClass.method (package:my_app/services/my_service.dart:42:10)
''');

      final result = getCallerInfo(stackTrace)?.callerFileName;

      expect(result, 'my_service');
    });
  });
}
