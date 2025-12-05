import 'dart:math';

import 'package:sidekick_core/sidekick_core.dart';

class TestCommand extends Command {
  @override
  final String description =
      'Runs all tests in all packages, a single package, or a specific file/directory';

  @override
  final String name = 'test';

  @override
  final String invocation = 'chrp test [<path>]';

  TestCommand() {
    argParser
      ..addFlag('all', hide: true, help: 'deprecated')
      ..addFlag(
        'fast',
        help: 'Run tests with minimal output, only showing failures',
      )
      ..addOption(
        'package',
        abbr: 'p',
        help: 'Run tests for a specific package',
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Run only tests whose name contains the given substring',
      );
  }

  @override
  Future<void> run() async {
    final collector = _TestResultCollector();

    final String? packageArg = argResults?['package'] as String?;
    final String? testName = argResults?['name'] as String?;
    // Ignore --fast when filtering by test name (you want verbose output for debugging)
    final bool fast =
        testName == null && (argResults?['fast'] as bool? ?? false);
    final List<String> rest = argResults?.rest ?? [];

    // If a file path is provided as rest argument
    if (rest.isNotEmpty) {
      final filePath = rest.first;
      collector.add(await _testFile(filePath, testName, fast: fast));
      exit(collector.exitCode);
    }

    if (packageArg != null) {
      // only run tests in selected package
      collector.add(
        await _testPackageWithName(packageArg, testName: testName, fast: fast),
      );
      exit(collector.exitCode);
    }

    // outside of package, fallback to all packages
    for (final package in findAllPackages(SidekickContext.projectRoot)) {
      collector.add(
        await _test(
          package,
          requireTests: false,
          testName: testName,
          fast: fast,
        ),
      );
      if (!fast) print('\n');
    }

    exit(collector.exitCode);
  }

  Future<_TestResult> _testFile(
    String filePath,
    String? testName, {
    required bool fast,
  }) async {
    final file = File(filePath);
    final absolutePath = file.absolute.path;

    // Find which package this file belongs to
    final allPackages = findAllPackages(SidekickContext.projectRoot);
    final package = allPackages.firstOrNullWhere(
      (pkg) => absolutePath.startsWith(pkg.root.absolute.path),
    );

    if (package == null) {
      error(
        'Could not determine package for file: $filePath\n'
        'Make sure the file is within one of the project packages.',
      );
    }

    // Get the relative path from the package root
    final relativePath =
        absolutePath.substring(package.root.absolute.path.length + 1);

    if (!fast) {
      print(yellow('=== package ${package.name} ==='));
      print('Running test: $relativePath');
    } else {
      print('Running test for package: ${package.name}');
    }

    final args = ['test', relativePath];
    if (testName != null) {
      args.addAll(['--name', testName]);
    }

    if (fast) {
      return _runFastTest(package, args);
    }

    final exitCode = await () async {
      if (package.isFlutterPackage) {
        return await flutter(args, workingDirectory: package.root);
      } else {
        return await dart(args, workingDirectory: package.root);
      }
    }();

    if (exitCode.exitCode == 0) {
      return _TestResult.success;
    }
    return _TestResult.failed;
  }

  Future<_TestResult> _testPackageWithName(
    String name, {
    String? testName,
    required bool fast,
  }) async {
    // only run tests in selected package
    final allPackages = findAllPackages(SidekickContext.projectRoot);
    final package = allPackages.firstOrNullWhere((it) => it.name == name);
    if (package == null) {
      final packageOptions =
          allPackages.map((it) => it.name).toList(growable: false);
      error(
        'Could not find package $name. '
        'Please use one of ${packageOptions.joinToString()}',
      );
    }
    return await _test(
      package,
      requireTests: true,
      testName: testName,
      fast: fast,
    );
  }

  Future<_TestResult> _test(
    DartPackage package, {
    required bool requireTests,
    required bool fast,
    String? testName,
  }) async {
    if (!fast) {
      print(yellow('=== package ${package.name} ==='));
    }
    if (!package.testDir.existsSync()) {
      if (requireTests) {
        error(
          'Could not find a test folder in package ${package.name}. '
          'Please create some tests first.',
        );
      } else {
        if (!fast) print("No tests");
        return _TestResult.noTests;
      }
    }

    final args = ['test'];
    if (testName != null) {
      args.addAll(['--name', testName]);
    }

    if (fast) {
      return _runFastTest(package, args);
    }

    final exitCode = await () async {
      if (package.isFlutterPackage) {
        return await flutter(args, workingDirectory: package.root);
      } else {
        return await dart(args, workingDirectory: package.root);
      }
    }();
    if (exitCode.exitCode == 0) {
      return _TestResult.success;
    }
    return _TestResult.failed;
  }

  Future<_TestResult> _runFastTest(
    DartPackage package,
    List<String> args,
  ) async {
    final concurrency = max(1, Platform.numberOfProcessors - 1);
    final fullArgs = [
      ...args,
      '--concurrency=$concurrency',
      '-r',
      'compact',
    ];

    final executable = package.isFlutterPackage ? 'flutter' : 'dart';
    final result = await Process.run(
      executable,
      fullArgs,
      workingDirectory: package.root.path,
    );

    final stdout = result.stdout.toString();
    final stderr = result.stderr.toString();

    if (result.exitCode == 0) {
      print('${green('✓')} package:${package.name}: All tests passed!');
      return _TestResult.success;
    }

    // Parse and show only failed tests
    final failedTests = _extractFailedTestNames(stdout);
    print('${red('✗')} ${package.name}');
    if (failedTests != null && failedTests.isNotEmpty) {
      for (final testName in failedTests) {
        print('  - $testName');
      }
    } else {
      // Other errors (compilation, test not found, etc.) - dump full output
      print(stdout);
    }

    if (stderr.isNotEmpty) {
      print(stderr);
    }

    return _TestResult.failed;
  }

  /// Extracts the names of failed tests from test output.
  /// Returns null if this is not a test failure (e.g., compilation error, no tests found).
  List<String>? _extractFailedTestNames(String output) {
    // Strip ANSI escape codes for easier parsing
    final cleanOutput = output.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    final lines = cleanOutput.split('\n');
    final failedTests = <String>[];

    // Check for non-test-failure errors
    if (lines.any(
      (line) =>
          line.trim().startsWith('Failed to load') ||
          line.trim().endsWith('Does not exist.') ||
          line.trim().startsWith('No tests ran.') ||
          line.contains('No tests match regular expression'),
    )) {
      return null;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Look for lines that contain "The test description was:" (widget tests)
      if (line.contains('The test description was:')) {
        if (i + 1 < lines.length) {
          final testNameLine = lines[i + 1].trim();
          if (testNameLine.isNotEmpty &&
              !testNameLine.startsWith('The test description was:')) {
            failedTests.add(testNameLine);
          }
        }
      }
      // Look for lines ending with [E] (unit tests with compact reporter)
      else if (line.contains('[E]')) {
        final match = RegExp(r':\s+(.+?)\s+\[E\]').firstMatch(line);
        if (match != null) {
          final testName = match.group(1)?.trim();
          if (testName != null && testName.isNotEmpty) {
            failedTests.add(testName);
          }
        }
      }
    }

    // Remove duplicates and substrings
    final uniqueTests = failedTests.toSet().toList();
    final deduplicated = <String>[];
    for (final test in uniqueTests) {
      bool isSubstringOfAnother = false;
      for (final other in uniqueTests) {
        if (test != other && other.contains(test)) {
          isSubstringOfAnother = true;
          break;
        }
      }
      if (!isSubstringOfAnother) {
        deduplicated.add(test);
      }
    }

    return deduplicated;
  }
}

class _TestResultCollector {
  final List<_TestResult> _results = [];

  void add(_TestResult result) {
    _results.add(result);
  }

  int get exitCode {
    if (_results.contains(_TestResult.failed)) {
      return -1;
    }
    if (_results.contains(_TestResult.success)) {
      return 0;
    }
    // no tests or all skipped
    return -2;
  }
}

enum _TestResult {
  success,
  failed,
  noTests,
}
