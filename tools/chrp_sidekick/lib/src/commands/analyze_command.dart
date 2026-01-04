import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:sidekick_core/sidekick_core.dart';

/// Runs analyze on all Flutter/Dart packages in the repository
class AnalyzeCommand extends Command {
  @override
  final String description = 'Runs analyze in all packages or a single package';

  @override
  final String name = 'analyze';

  /// packages whose analysis should not be run
  final List<DartPackage> exclude;

  /// glob patterns of packages whose analysis should not be run
  ///
  /// Search starts at repository root.
  ///
  /// Example project layout:
  ///
  /// ```sh
  /// repo-root
  /// ├── packages
  /// │   ├── package1
  /// │   ├── package2
  /// │   └── circle
  /// └── third_party
  ///     ├── circle
  ///     │   ├── packageA
  ///     │   └── packageB
  ///     └── square
  /// ```
  ///
  /// - Use `packages/package1/**` to exclude only `packages/package1`.
  /// - Use `**/circle/**` to exclude `packages/circle` as well as
  ///   `third_party/circle/packageA` and `third_party/circle/packageB`.
  final List<String> excludeGlob;

  AnalyzeCommand({this.exclude = const [], this.excludeGlob = const []}) {
    argParser.addOption('package', abbr: 'p');
  }

  @override
  Future<void> run() async {
    final String? packageName = argResults?['package'] as String?;

    final List<DartPackage> allPackages = findAllPackages(
      SidekickContext.projectRoot,
    );
    if (packageName != null) {
      final package = allPackages
          .where((it) => it.name == packageName)
          .firstOrNull;
      if (package == null) {
        throw "Package with name $packageName not found in "
            "${SidekickContext.projectRoot.path}";
      }
      _warnIfNotInProject();
      // only analyze selected package
      await _analyze(package);
      return;
    }

    _warnIfNotInProject();
    final errorBuffer = StringBuffer();

    final globExcludes = excludeGlob
        .expand((rule) {
          // start search at repo root
          final root = SidekickContext.projectRoot.path;
          return Glob("$root/$rule").listSync(root: root);
        })
        .whereType<Directory>()
        .mapNotNull((e) => DartPackage.fromDirectory(e));

    final excluded = [...exclude, ...globExcludes];

    for (final package in allPackages.whereNot(excluded.contains)) {
      try {
        await _analyze(package);
      } catch (e, stack) {
        print(
          'Error while analyzing ${package.name} '
          '(${package.root.path})',
        );
        errorBuffer.writeln("${package.name}: $e\n$stack");
      }
    }
    final errorText = errorBuffer.toString();
    if (errorText.isNotEmpty) {
      printerr("\n\nErrors while analyzing:");
      printerr(errorText);
      exitCode = 1;
    } else {
      exitCode = 0;
    }
  }

  Future<void> _analyze(DartPackage package) async {
    print(yellow('=== package ${package.name} ==='));
    final packageDir = package.root;
    final dartOrFlutter = package.isFlutterPackage ? flutter : dart;
    await dartOrFlutter(
      ['analyze', '--fatal-infos', '--fatal-warnings'],
      workingDirectory: packageDir,
      throwOnError: () => 'Failed to analyze package ${packageDir.path}',
    );
    print("\n");
  }

  void _warnIfNotInProject() {
    final currentDir = Directory.current;
    final projectRoot = SidekickContext.projectRoot;
    if (!currentDir.isWithinOrEqual(projectRoot)) {
      printerr(
        "Warning: You aren't analyzing the current "
        "working directory, but of project '${SidekickContext.cliName}'.",
      );
    }
  }
}

extension on Directory {
  bool isWithinOrEqual(Directory dir) {
    return this.isWithin(dir) ||
        // canonicalize is necessary, otherwise '/a/b/c' != '/a/b/c/' != '/a/b/c/.' != '/a/b/c/../c'
        dir.canonicalized.path == canonicalized.path;
  }

  /// A [Directory] whose path is the canonicalized path of [this].
  Directory get canonicalized => Directory(canonicalize(path));
}
