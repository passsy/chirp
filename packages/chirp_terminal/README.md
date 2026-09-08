# chirp_terminal

Interactive terminal prompts, progress, and inline styled logging backed by Chirp.
This package is an unreleased first version in the Chirp monorepo.

## Styled logging

```dart
import 'package:chirp_terminal/chirp_terminal.dart';

final terminal = ChirpTerminal(verbose: true);
try {
  terminal.verbose(
    Text('Resolved ') + Text('42 packages').green().bold(),
    data: {'count': 42},
  );
  terminal.warning(Text('Using cached dependencies').yellow());
  terminal.out.writeln('Command result');
} finally {
  await terminal.close();
}
```

`Text` is immutable and supports composition, foreground/background colors, bold, dim, italic, underline, strikethrough, and reverse video.
Its `toString()` returns plain text; terminal rendering adds styling for the destination.
Chirp's existing JSON and file formatters therefore receive readable text without generated ANSI codes.

`Text` builds fresh Chirp `PlainText`, `AnsiStyled`, and `SpanSequence` trees rather than maintaining a separate styling system.
`TerminalMessageFormatter` extends Chirp's `SpanBasedFormatter`, so formatter transformers and per-record `SpanFormatOptions` work normally.
Chirp's span API is currently experimental.

```dart
final terminal = ChirpTerminal(
  formatter: TerminalMessageFormatter(spanTransformers: [
    (span, record) {
      if (record.level == ChirpLogLevel.error) {
        span.wrap((child) => Bordered(child: child));
      }
    },
  ]),
);
terminal.info(
  Text.fromSpan(
    () => Aligned(width: 12, child: PlainText('Ready')),
    plainText: 'Ready',
  ),
);
```

Use `Text.fromSpan` to adapt custom Chirp spans, including layout spans, while providing their plain message for file writers.
Its builder must create a new tree on every call; sharing a mutable span instance between renders is unsupported.
Fluent styles on a single fragment merge, with the last color winning.
Styling a composition provides an outer style; explicitly styled child fragments retain their own colors, following Chirp's nested-span behavior.
Pass `requiresCallerInfo: true` to `TerminalMessageFormatter` when a transformer or custom span needs caller information.

`verbose()` maps to Chirp's debug level.
`isVerbose` controls only the terminal writer: other writers can retain debug and trace records regardless of what is visible onscreen.
Use `logger` for Chirp's full API, including lazy logging, custom levels, interceptors, context, and child loggers.
Logger-level filters still apply before any writer receives a record.

## Prompts

```dart
final name = await terminal.text('Project name', initialValue: 'my-cli');
final deploy = await terminal.confirm('Deploy now?', defaultValue: false);
final environment = await terminal.select<String>(
  'Environment',
  choices: [
    Choice('dev', label: 'Development'),
    Choice('prod', label: 'Production', description: 'Public service'),
  ],
  searchable: true,
  appearance: SelectAppearance.radio,
);
```

| Method | Behavior |
| --- | --- |
| `text` | Editable default, placeholder, synchronous/asynchronous validation |
| `confirm` | Yes/no, explicit default, arrows or y/n followed by Enter |
| `select<T>` | Typed choices, arrow/radio appearance, filtering, descriptions, disabled options |
| `multiselect<T>` | Space toggles, Tab toggles visible enabled choices, min/max, filtering |
| `search<T>` | Debounced async provider with cooperative cancellation and stale-result suppression |
| `password` | Masked or hidden input; no automatic logging of answers |
| `number` | Finite numeric input, optional bounds and integer requirement |

Text input supports arrows, Home/End, Ctrl+A/E, Backspace/Delete, UTF-8, grapheme-aware deletion, and bracketed paste.
Selectors scroll to keep the highlighted choice visible.
Multiselect reserves Space for toggling, so its text filter cannot contain spaces.

```dart
final repository = await terminal.search<String>(
  'Repository',
  source: (query, cancellation) async {
    final repositories = await findRepositories(query);
    if (cancellation.isCancelled) {
      return [];
    }
    return repositories.map((r) => Choice(r.id, label: r.name)).toList();
  },
);
```

Pass a `PromptCancellation` to cancel a pending prompt from application code.
Escape, Ctrl+C, EOF, and cancellation throw `PromptCancelled`; they never silently accept a default.
Only one prompt can read input at a time.
Logs arriving through the attached writer are rendered above the prompt without losing its input or selection.

## Progress

```dart
final progress = terminal.progress(
  'Uploading',
  total: files.length,
  appearance: ProgressAppearance.bar,
);
try {
  for (final file in files) {
    await upload(file);
    progress.advance();
  }
  progress.finish('Uploaded');
} catch (error, stackTrace) {
  progress.fail('Upload failed', error: error, stackTrace: stackTrace);
  rethrow;
}
```

Appearances: spinner, bar, counter, percentage, and static text.
Spinner presets: dots, line, and bounce.
Multiple handles share a live region, allowing concurrent task displays.
Bars and percentages require a total; zero-total progress is treated as complete.
The terminal clips live output to its available dimensions; Unicode cell widths use a pragmatic wide-character approximation.

Only start/completion/failure/cancellation become structured Chirp records, with `progress`, `completed`, `total`, and `durationMs` fields.
Animation frames never become log records.
Finishing, failing, and cancelling are idempotent.
Closing the session cancels unfinished progress handles.

## Streams, automation, and persistence

- Prompts and diagnostics use stderr; `out.write`, `out.writeln`, and `out.writeCharCode` write exact command output to stdout.
- Automatic mode uses rich prompts only with interactive input and an ANSI-capable diagnostic terminal outside CI.
- Redirected stderr does not inherit colors from `TERM`; `NO_COLOR` disables automatic styling.
- Pass explicit `TerminalCapabilities` to override color detection, including truecolor or no color.
- `TerminalMode.plain` uses line-based prompts without screen redraws and can consume explicitly supplied input lines.
- `TerminalMode.nonInteractive` rejects prompts with `NonInteractivePrompt` and renders progress as static lifecycle lines.
- Password prompts require interactive mode so input echo can be disabled.

```dart
final file = RotatingFileWriter(
  baseFilePathProvider: () => 'tool.jsonl',
  formatter: const JsonLogFormatter(),
);
final terminal = ChirpTerminal(
  logger: ChirpLogger().addWriter(file),
  flushLogs: file.flush,
);
```

Call `close()` in a `finally` block, then close application-owned file writers.
It restores prompt input modes and cursor visibility, removes its own writer, cancels its input subscription, and drains terminal output plus `flushLogs`.
The stdio backend takes ownership of stdin for the session lifetime: cancelling Dart's stdin subscription closes its input descriptor.
Create one stdio session per application and close it when input is finished.
Stdout, stderr, the supplied logger, and its other writers remain application-owned.

Do not attach another console writer targeting the same terminal: its writes would bypass prompt coordination.
Likewise, direct process output during an active prompt is outside the session's control.

## Run the demo

From this package directory:

```sh
dart pub get
dart run example/main.dart --verbose
```

The demo writes diagnostic records to `chirp-terminal-demo.jsonl` and command results to stdout.
Use `--plain` to try sequential line input.
The checked-in `pubspec_overrides.yaml` resolves Chirp from the adjacent package for monorepo development.

## Verification and scope

```sh
dart test
dart analyze
python3 tool/pty_smoke.py
```

`TerminalBackend` supplies injectable input, outputs, capabilities, resize events, and interrupt events for testing.
The POSIX smoke test exercises real terminal input, background logging, password masking, stdout isolation, and Ctrl+C restoration.

This first version includes the core prompts and progress components above.
Multiline/editor prompts, path completion, grouped selectors, task scheduling, and a public theme/renderer API remain future extensions.
It does not embed or require Node.js.
The interaction references are [Clack](https://github.com/bombshell-dev/clack), [Inquirer](https://github.com/SBoudrias/Inquirer.js), [Ora](https://github.com/sindresorhus/ora), [cli-progress](https://github.com/npkgz/cli-progress), and [GitHub CLI](https://github.com/cli/cli).
