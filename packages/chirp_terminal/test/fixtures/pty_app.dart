import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:chirp_terminal/chirp_terminal.dart';

Future<void> main(List<String> args) async {
  final lineMode = io.stdin.lineMode;
  final echoMode = io.stdin.echoMode;
  final terminal = ChirpTerminal(verbose: true);
  try {
    if (args.contains('cancel')) {
      try {
        await terminal.text('Cancel me');
      } on PromptCancelled {
        terminal.out.writeln('CANCELLED');
      }
      return;
    }
    terminal.verbose(Text('Cache ') + Text('HIT').green().bold());
    final progress =
        terminal.progress('Background', spinner: SpinnerAppearance.line);
    final timer = Timer(const Duration(milliseconds: 350), () {
      terminal.logger.child(context: {'id': 1}).info('Background log');
    });
    try {
      final name = await terminal.text('Name', initialValue: 'ac');
      final choice = await terminal.select<int>('Environment',
          searchable: true,
          choices: [
            const Choice(1, label: 'Development'),
            const Choice(2, label: 'Production')
          ]);
      final enabled = await terminal.confirm('Continue?');
      final password = await terminal.password('Token');
      progress.finish('Background done');
      terminal.out.writeln(jsonEncode({
        'name': name,
        'choice': choice,
        'enabled': enabled,
        'passwordLength': password.length
      }));
    } finally {
      timer.cancel();
    }
  } finally {
    final restored =
        io.stdin.lineMode == lineMode && io.stdin.echoMode == echoMode;
    await terminal.close();
    assert(restored, 'Terminal input modes were not restored');
  }
}
