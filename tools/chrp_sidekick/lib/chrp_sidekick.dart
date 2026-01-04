import 'dart:async';

import 'package:chrp_sidekick/src/commands/analyze_command.dart';
import 'package:chrp_sidekick/src/commands/clean_command.dart';
import 'package:chrp_sidekick/src/commands/test_command.dart';
import 'package:puro_sidekick_plugin/puro_sidekick_plugin.dart';
import 'package:sidekick_core/sidekick_core.dart';

Future<void> runChrp(List<String> args) async {
  final runner = initializeSidekick(flutterSdkPath: flutterSdkSymlink());
  addSdkInitializer(initializePuro);

  runner
    ..addCommand(FlutterCommand())
    ..addCommand(DartCommand())
    ..addCommand(DepsCommand())
    ..addCommand(CleanCommand())
    ..addCommand(AnalyzeCommand())
    ..addCommand(FormatCommand())
    ..addCommand(SidekickCommand())
    ..addCommand(TestCommand())
    ..addCommand(PuroCommand());

  try {
    return await runner.run(args);
  } on UsageException catch (e) {
    print(e);
    exit(64); // usage error
  }
}
