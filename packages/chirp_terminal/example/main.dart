import 'dart:async';
import 'dart:convert';

import 'package:chirp_terminal/chirp_terminal.dart';

Future<void> main(List<String> args) async {
  final file = RotatingFileWriter(
    baseFilePathProvider: () => 'chirp-terminal-demo.jsonl',
    formatter: const JsonLogFormatter(),
  );
  final terminal = ChirpTerminal(
    logger: ChirpLogger().addWriter(file),
    verbose: args.contains('--verbose'),
    mode: args.contains('--plain') ? TerminalMode.plain : TerminalMode.auto,
    flushLogs: file.flush,
  );
  try {
    terminal.verbose(
      Text('Cache ') + Text('HIT').green().bold() + Text(' for chirp_terminal'),
      data: {'packages': 42},
    );
    final name = await terminal.text('Project name',
        initialValue: 'my-cli',
        validate: (value) =>
            value.trim().isEmpty ? 'A name is required' : null);
    final environment = await terminal.select<String>('Environment',
        choices: [
          const Choice('dev',
              label: 'Development', description: 'Local iteration'),
          const Choice('staging', label: 'Staging'),
          const Choice('production', label: 'Production'),
        ],
        searchable: true,
        appearance: SelectAppearance.radio);
    final features = await terminal.multiselect<String>('Features', choices: [
      const Choice('logging', label: 'File logging'),
      const Choice('json', label: 'JSON output'),
      const Choice('color', label: 'Color'),
    ], initialValues: [
      'logging'
    ]);
    if (!await terminal.confirm('Create project?')) {
      terminal.info('Cancelled');
      return;
    }
    final progress = terminal.progress('Creating project',
        total: 10, appearance: ProgressAppearance.bar);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      progress.advance();
      if (i == 4) {
        terminal.logger
            .child(context: {'project': name}).info('Writing configuration');
      }
    }
    progress.finish('Project created');
    terminal.out.writeln(jsonEncode(
        {'name': name, 'environment': environment, 'features': features}));
  } on PromptCancelled {
    terminal.info('Cancelled');
  } on NonInteractivePrompt catch (error) {
    terminal.error(error.message);
  } finally {
    await terminal.close();
    await file.close();
  }
}
