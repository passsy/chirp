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
      ..addOption('package', abbr: 'p', help: 'Run tests for a specific package')
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
    final List<String> rest = argResults?.rest ?? [];

    // If a file path is provided as rest argument
    if (rest.isNotEmpty) {
      final filePath = rest.first;
      collector.add(await _testFile(filePath, testName));
      exit(collector.exitCode);
    }

    if (packageArg != null) {
      // only run tests in selected package
      collector.add(await _testPackageWithName(packageArg, testName: testName));
      exit(collector.exitCode);
    }

    // outside of package, fallback to all packages
    for (final package in findAllPackages(SidekickContext.projectRoot)) {
      collector.add(await _test(package, requireTests: false, testName: testName));
      print('\n');
    }

    exit(collector.exitCode);
  }

  Future<_TestResult> _testFile(String filePath, String? testName) async {
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

    print(yellow('=== package ${package.name} ==='));
    print('Running test: $relativePath');

    final args = ['test', relativePath];
    if (testName != null) {
      args.addAll(['--name', testName]);
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
    return await _test(package, requireTests: true, testName: testName);
  }

  Future<_TestResult> _test(
    DartPackage package, {
    required bool requireTests,
    String? testName,
  }) async {
    print(yellow('=== package ${package.name} ==='));
    if (!package.testDir.existsSync()) {
      if (requireTests) {
        error(
          'Could not find a test folder in package ${package.name}. '
          'Please create some tests first.',
        );
      } else {
        print("No tests");
        return _TestResult.noTests;
      }
    }

    final args = ['test'];
    if (testName != null) {
      args.addAll(['--name', testName]);
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
