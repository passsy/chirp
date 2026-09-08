part of '../chirp_terminal.dart';

/// A label is independent of the typed value returned to the application.
class Choice<T> {
  const Choice(this.value,
      {required this.label, this.description, this.disabled = false});
  final T value;
  final String label;
  final String? description;
  final bool disabled;
}

enum SelectAppearance { arrow, radio }

typedef InputValidator = FutureOr<String?> Function(String value);
typedef ChoiceSearch<T> = Future<List<Choice<T>>> Function(
    String query, PromptCancellation cancellation);

extension TerminalPromptApi on ChirpTerminal {
  Future<String> text(
    String message, {
    String initialValue = '',
    String? placeholder,
    InputValidator? validate,
    PromptCancellation? cancellation,
  }) {
    return _ask(
        _TextPrompt(this, message,
            initialValue: initialValue,
            placeholder: placeholder,
            validate: validate),
        cancellation);
  }

  Future<String> password(
    String message, {
    bool hidden = false,
    InputValidator? validate,
    PromptCancellation? cancellation,
  }) {
    return _ask(
        _TextPrompt(this, message,
            secret: true, hidden: hidden, validate: validate),
        cancellation);
  }

  Future<bool> confirm(
    String message, {
    bool defaultValue = false,
    PromptCancellation? cancellation,
  }) {
    return _ask(_ConfirmPrompt(this, message, defaultValue), cancellation);
  }

  Future<num> number(
    String message, {
    num? initialValue,
    num? min,
    num? max,
    bool integer = false,
    PromptCancellation? cancellation,
  }) async {
    if (min != null && max != null && min > max) {
      throw ArgumentError('min must not exceed max');
    }
    final answer = await text(message,
        initialValue: initialValue?.toString() ?? '',
        cancellation: cancellation, validate: (value) {
      final parsed = num.tryParse(value);
      if (parsed == null || !parsed.isFinite || (integer && parsed % 1 != 0)) {
        return integer ? 'Enter a whole number' : 'Enter a number';
      }
      if ((min != null && parsed < min) || (max != null && parsed > max)) {
        return 'Enter a value ${min == null ? '' : '>= $min'} ${max == null ? '' : '<= $max'}';
      }
      return null;
    });
    return num.parse(answer);
  }

  Future<T> select<T>(
    String message, {
    required List<Choice<T>> choices,
    T? initialValue,
    bool searchable = false,
    SelectAppearance appearance = SelectAppearance.arrow,
    PromptCancellation? cancellation,
  }) async {
    final values = await _ask(
        _SelectPrompt<T>(this, message, choices,
            initialValues: initialValue == null ? [] : [initialValue],
            searchable: searchable,
            appearance: appearance),
        cancellation);
    return values.single;
  }

  Future<List<T>> multiselect<T>(
    String message, {
    required List<Choice<T>> choices,
    List<T> initialValues = const [],
    bool searchable = false,
    int min = 0,
    int? max,
    PromptCancellation? cancellation,
  }) {
    return _ask(
        _SelectPrompt<T>(this, message, choices,
            initialValues: initialValues,
            searchable: searchable,
            multiple: true,
            min: min,
            max: max),
        cancellation);
  }

  Future<T> search<T>(
    String message, {
    required ChoiceSearch<T> source,
    PromptCancellation? cancellation,
  }) async {
    final prompt =
        _SelectPrompt<T>(this, message, [], searchable: true, source: source);
    final result = _ask(prompt, cancellation);
    return (await result).single;
  }
}

abstract class _Prompt<T> {
  _Prompt(this.terminal, this.message);
  final ChirpTerminal terminal;
  final String message;
  final Completer<T> result = Completer<T>();
  String? validationError;
  bool busy = false;
  bool get secret => false;
  (int, int)? get cursor => null;
  String get plainDescription => message;
  String summary(T value) => value.toString();
  List<String> lines(int height, int width);
  void key(_KeyEvent event);
  Future<void> line(String value);
  void start() {}
  void dispose() {}

  void complete(T value) {
    if (!result.isCompleted) {
      result.complete(value);
    }
  }

  void cancel([String reason = 'cancelled']) {
    fail(PromptCancelled(reason), StackTrace.current);
  }

  void fail(Object error, StackTrace stack) {
    if (!result.isCompleted) {
      result.completeError(error, stack);
    }
  }

  void invalid(String error) {
    validationError = error;
    if (terminal._interactive) {
      terminal._redraw();
    } else {
      terminal.backend.writeDiagnostic('${_safeText(error)}\n> ');
    }
  }
}

class _TextPrompt extends _Prompt<String> {
  _TextPrompt(
    super.terminal,
    super.message, {
    String initialValue = '',
    this.placeholder,
    this.validate,
    this.secret = false,
    this.hidden = false,
  }) : edit = _EditBuffer(initialValue);
  final _EditBuffer edit;
  final String? placeholder;
  final InputValidator? validate;
  @override
  final bool secret;
  final bool hidden;
  (int, int)? _cursor;
  @override
  (int, int)? get cursor => _cursor;
  @override
  String get plainDescription {
    return '$message${edit.value.isEmpty ? '' : ' [${edit.value}]'}';
  }

  @override
  String summary(String value) => secret ? '[hidden]' : value;

  @override
  List<String> lines(int height, int width) {
    final chars = (secret
            ? (hidden ? '' : '*' * edit.value.characters.length)
            : edit.value)
        .characters
        .toList();
    var position = secret && hidden ? 0 : edit.cursor;
    var start = 0;
    final available = math.max(1, width - 2);
    while (start < position &&
        _width(chars.sublist(start, position).join()) >= available) {
      start++;
    }
    position = _width(chars.sublist(start, position).join());
    _cursor = (1, math.min(width, 2 + position));
    return [
      '? $message',
      '> ${edit.value.isEmpty && placeholder != null ? placeholder : chars.skip(start).join()}',
      if (busy) 'Validating...',
      if (validationError != null) '! $validationError',
    ];
  }

  @override
  void key(_KeyEvent event) {
    if (event.key == _Key.cancel) {
      cancel();
      return;
    }
    if (result.isCompleted || busy) {
      return;
    }
    if (event.key == _Key.enter) {
      unawaited(submit(edit.value));
    } else if (edit.edit(event)) {
      validationError = null;
      terminal._redraw();
    }
  }

  @override
  Future<void> line(String value) => submit(value.isEmpty ? edit.value : value);

  Future<void> submit(String value) async {
    busy = true;
    terminal._redraw();
    try {
      final error = await validate?.call(value);
      if (result.isCompleted) {
        return;
      }
      if (error != null) {
        invalid(error);
      } else {
        complete(value);
      }
    } catch (error, stack) {
      fail(error, stack);
    } finally {
      busy = false;
      if (!result.isCompleted) {
        terminal._redraw();
      }
    }
  }
}

class _ConfirmPrompt extends _Prompt<bool> {
  _ConfirmPrompt(super.terminal, super.message, this.value);
  bool value;
  @override
  String get plainDescription => '$message ${value ? '[Y/n]' : '[y/N]'}';
  @override
  String summary(bool value) => value ? 'Yes' : 'No';
  @override
  List<String> lines(int height, int width) {
    return [
      '? $message',
      if (value)
        '  No  > Yes   [←→ choose, y/n, enter]'
      else
        '> No    Yes   [←→ choose, y/n, enter]',
      if (validationError != null) '! $validationError'
    ];
  }

  @override
  void key(_KeyEvent event) {
    if (result.isCompleted) {
      return;
    }
    switch (event.key) {
      case _Key.cancel:
        cancel();
      case _Key.enter:
        complete(value);
      case _Key.left || _Key.right || _Key.tab:
        value = !value;
        terminal._redraw();
      case _Key.text:
        final text = event.text.toLowerCase();
        if (text == 'y' || text == 'n') {
          value = text == 'y';
          terminal._redraw();
        }
      default:
        break;
    }
  }

  @override
  Future<void> line(String input) {
    switch (input.trim().toLowerCase()) {
      case '':
        complete(value);
      case 'y' || 'yes':
        complete(true);
      case 'n' || 'no':
        complete(false);
      default:
        invalid('Enter yes or no');
    }
    return Future<void>.value();
  }
}

class _SelectPrompt<T> extends _Prompt<List<T>> {
  _SelectPrompt(
    super.terminal,
    super.message,
    List<Choice<T>> choices, {
    List<T> initialValues = const [],
    this.multiple = false,
    this.searchable = false,
    this.appearance = SelectAppearance.arrow,
    this.min = 0,
    this.max,
    this.source,
  })  : choices = List.of(choices),
        selected = Set.of(initialValues) {
    if (min < 0 || (max != null && max! < min)) {
      throw ArgumentError('Invalid selection bounds');
    }
    if (source == null && !choices.any((c) => !c.disabled)) {
      throw ArgumentError('At least one enabled choice is required');
    }
    if (choices.map((c) => c.value).toSet().length != choices.length) {
      throw ArgumentError('Choice values must be unique');
    }
    if (initialValues
        .any((v) => !choices.any((c) => c.value == v && !c.disabled))) {
      throw ArgumentError('Initial values must refer to enabled choices');
    }
    final initial = choices.indexWhere((c) => selected.contains(c.value));
    index = initial >= 0
        ? initial
        : math.max(0, choices.indexWhere((c) => !c.disabled));
  }
  List<Choice<T>> choices;
  final Set<T> selected;
  final bool multiple;
  final bool searchable;
  final SelectAppearance appearance;
  final int min;
  final int? max;
  final ChoiceSearch<T>? source;
  final _EditBuffer query = _EditBuffer('');
  int index = 0;
  int _generation = 0;
  PromptCancellation? _searchCancellation;
  Timer? _debounce;
  Completer<void>? _searchDone;

  @override
  void start() {
    if (source != null) {
      search();
    }
  }

  List<Choice<T>> get visible {
    return source != null
        ? choices
        : choices
            .where((c) =>
                c.label.toLowerCase().contains(query.value.toLowerCase()))
            .toList();
  }

  @override
  String get plainDescription {
    return '$message\n${[
      for (var i = 0; i < choices.length; i++)
        '${i + 1}. ${choices[i].label}${choices[i].disabled ? ' (disabled)' : ''}'
    ].join('\n')}\n${source != null ? 'Type a search query; then enter an option number.' : multiple ? 'Enter option numbers separated by commas.' : 'Enter an option number.'}';
  }

  @override
  String summary(List<T> value) {
    return value
        .map((v) => choices.firstWhere((c) => c.value == v).label)
        .join(', ');
  }

  @override
  List<String> lines(int height, int width) {
    final items = visible;
    final count = math.max(1,
        height - (searchable ? 2 : 1) - 1 - (validationError == null ? 0 : 1));
    final start =
        math.max(0, math.min(index - count ~/ 2, items.length - count));
    return [
      '? $message',
      if (searchable) 'Search: ${query.value}',
      if (busy) 'Searching...' else if (items.isEmpty) 'No matches',
      if (!busy) ...[
        for (var i = start; i < math.min(items.length, start + count); i++)
          '${i == index ? '>' : ' '} ${multiple ? (selected.contains(items[i].value) ? '[x] ' : '[ ] ') : appearance == SelectAppearance.radio ? (i == index ? '(*) ' : '( ) ') : ''}${items[i].label}${items[i].disabled ? ' (disabled)' : ''}${items[i].description == null ? '' : ' — ${items[i].description}'}',
      ],
      if (multiple)
        '↑↓ move, space toggle, tab all, enter accept'
      else
        '↑↓ move, enter select',
      if (validationError != null) '! $validationError',
    ];
  }

  @override
  void key(_KeyEvent event) {
    if (result.isCompleted) {
      return;
    }
    final items = visible;
    if (event.key == _Key.cancel) {
      cancel();
      return;
    }
    if (event.key == _Key.up || event.key == _Key.down) {
      final delta = event.key == _Key.up ? -1 : 1;
      if (items.isNotEmpty) {
        for (var n = 0; n < items.length; n++) {
          index = (index + delta) % items.length;
          if (!items[index].disabled) {
            break;
          }
        }
      }
    } else if (event.key == _Key.enter && !busy) {
      if (multiple) {
        accept();
      } else if (items.isNotEmpty && !items[index].disabled) {
        complete([items[index].value]);
      }
      return;
    } else if (multiple && event.key == _Key.text && event.text == ' ') {
      if (items.isNotEmpty && !items[index].disabled) {
        toggle(items[index].value);
      }
    } else if (multiple && event.key == _Key.tab) {
      final enabled =
          items.where((c) => !c.disabled).map((c) => c.value).toList();
      if (enabled.every(selected.contains)) {
        selected.removeAll(enabled);
      } else {
        for (final value in enabled) {
          if (max == null || selected.length < max!) {
            selected.add(value);
          }
        }
      }
    } else if (searchable && query.edit(event)) {
      index = 0;
      validationError = null;
      if (source != null) {
        search();
      } else {
        final enabled = visible.indexWhere((c) => !c.disabled);
        index = math.max(0, enabled);
      }
    }
    terminal._redraw();
  }

  void toggle(T value) {
    if (selected.remove(value)) {
      return;
    }
    if (max != null && selected.length >= max!) {
      invalid('Select at most $max options');
      return;
    }
    selected.add(value);
  }

  void accept() {
    if (selected.length < min || (max != null && selected.length > max!)) {
      invalid(
          'Select at least $min${max == null ? '' : ' and at most $max'} options');
      return;
    }
    complete(choices
        .where((c) => selected.contains(c.value))
        .map((c) => c.value)
        .toList());
  }

  @override
  Future<void> line(String value) {
    if (source != null && int.tryParse(value) == null) {
      query.value = value;
      search();
      return _searchDone!.future;
    }
    final numbers = value.trim().isEmpty
        ? <int>[]
        : value.split(',').map((n) => int.tryParse(n.trim()) ?? 0).toList();
    if ((!multiple && numbers.length != 1) ||
        numbers.any(
            (n) => n < 1 || n > choices.length || choices[n - 1].disabled)) {
      invalid('Enter valid enabled option numbers');
      return Future<void>.value();
    }
    if (multiple) {
      selected
        ..clear()
        ..addAll(numbers.map((n) => choices[n - 1].value));
      accept();
    } else {
      complete([choices[numbers.single - 1].value]);
    }
    return Future<void>.value();
  }

  void search() {
    if (_searchDone?.isCompleted == false) {
      _searchDone!.complete();
    }
    final done = Completer<void>();
    _searchDone = done;
    _searchCancellation?.cancel();
    _debounce?.cancel();
    final cancellation = PromptCancellation();
    _searchCancellation = cancellation;
    final generation = ++_generation;
    busy = true;
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final matches = await source!(query.value, cancellation);
        if (result.isCompleted || generation != _generation) {
          return;
        }
        if (matches.map((c) => c.value).toSet().length != matches.length) {
          throw ArgumentError('Search choice values must be unique');
        }
        choices = List.of(matches);
        index = math.max(0, choices.indexWhere((c) => !c.disabled));
        validationError = null;
        if (!terminal._interactive) {
          terminal.backend.writeDiagnostic('$plainDescription\n> ');
        }
      } catch (error) {
        if (!result.isCompleted && generation == _generation) {
          invalid('Search failed. Edit the query to retry.');
        }
      } finally {
        if (!done.isCompleted) {
          done.complete();
        }
        if (!result.isCompleted && generation == _generation) {
          busy = false;
          terminal._redraw();
        }
      }
    });
  }

  @override
  void dispose() {
    if (_searchDone?.isCompleted == false) {
      _searchDone!.complete();
    }
    _generation++;
    _debounce?.cancel();
    _searchCancellation?.cancel();
  }
}
