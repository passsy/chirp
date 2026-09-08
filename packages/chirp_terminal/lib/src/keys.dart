part of '../chirp_terminal.dart';

enum _Key {
  text,
  enter,
  up,
  down,
  left,
  right,
  home,
  end,
  backspace,
  delete,
  cancel,
  tab
}

class _KeyEvent {
  const _KeyEvent(this.key, [this.text = '']);
  final _Key key;
  final String text;
}

/// Buffers fragmented escape sequences and bracketed paste, including UTF-8
/// chunks already joined by the streaming decoder in the terminal session.
class _KeyDecoder {
  _KeyDecoder(this.emit);
  final void Function(_KeyEvent) emit;
  String _pending = '';
  bool _paste = false;
  Timer? _escapeTimer;

  static const _sequences = {
    '\x1b[A': _Key.up,
    '\x1b[B': _Key.down,
    '\x1b[C': _Key.right,
    '\x1b[D': _Key.left,
    '\x1b[H': _Key.home,
    '\x1b[F': _Key.end,
    '\x1bOH': _Key.home,
    '\x1bOF': _Key.end,
    '\x1b[1~': _Key.home,
    '\x1b[4~': _Key.end,
    '\x1b[3~': _Key.delete,
  };

  void add(String chunk) {
    _escapeTimer?.cancel();
    _pending += chunk;
    while (_pending.isNotEmpty) {
      if (_paste) {
        final end = _pending.indexOf('\x1b[201~');
        if (end < 0) {
          return;
        }
        emit(_KeyEvent(_Key.text, _pending.substring(0, end)));
        _pending = _pending.substring(end + 6);
        _paste = false;
        continue;
      }
      if (_pending.startsWith('\x1b[200~')) {
        _pending = _pending.substring(6);
        _paste = true;
        continue;
      }
      if (_pending.startsWith('\x1b')) {
        String? match;
        for (final sequence in _sequences.keys) {
          if (_pending.startsWith(sequence)) {
            match = sequence;
            break;
          }
        }
        if (match != null) {
          _pending = _pending.substring(match.length);
          emit(_KeyEvent(_sequences[match]!));
          continue;
        }
        final partial = _pending == '\x1b' ||
            _sequences.keys.any((s) => s.startsWith(_pending)) ||
            '\x1b[200~'.startsWith(_pending);
        if (partial) {
          _escapeTimer = Timer(const Duration(milliseconds: 80), () {
            _pending = '';
            emit(const _KeyEvent(_Key.cancel));
          });
          return;
        }
        // Ignore unsupported complete control sequences (e.g. function keys).
        final control =
            RegExp(r'^\x1b\[[0-9;?]*[ -/]*[@-~]').firstMatch(_pending);
        _pending = _pending.substring(control?.end ?? 1);
        continue;
      }
      final char = _pending.characters.first;
      _pending = _pending.substring(char.length);
      final key = switch (char) {
        '\r' || '\n' => _Key.enter,
        '\x7f' || '\b' => _Key.backspace,
        '\x03' || '\x04' => _Key.cancel,
        '\x01' => _Key.home,
        '\x05' => _Key.end,
        '\t' => _Key.tab,
        _ => _Key.text,
      };
      if (char == '\r' && _pending.startsWith('\n')) {
        _pending = _pending.substring(1);
      }
      emit(_KeyEvent(key, key == _Key.text ? char : ''));
    }
  }

  void reset() {
    _escapeTimer?.cancel();
    _pending = '';
    _paste = false;
  }
}

class _EditBuffer {
  _EditBuffer(String initial)
      : value = initial,
        cursor = initial.characters.length;
  String value;
  int cursor;

  bool edit(_KeyEvent event) {
    final chars = value.characters.toList();
    switch (event.key) {
      case _Key.text:
        final text = _safeText(event.text).replaceAll('\n', ' ');
        final prefix = chars.take(cursor).join();
        chars.insertAll(cursor, text.characters);
        cursor = (prefix + text).characters.length;
      case _Key.backspace:
        if (cursor > 0) {
          chars.removeAt(--cursor);
        }
      case _Key.delete:
        if (cursor < chars.length) {
          chars.removeAt(cursor);
        }
      case _Key.left:
        cursor = math.max(0, cursor - 1);
      case _Key.right:
        cursor = math.min(chars.length, cursor + 1);
      case _Key.home:
        cursor = 0;
      case _Key.end:
        cursor = chars.length;
      default:
        return false;
    }
    value = chars.join();
    cursor = math.min(cursor, value.characters.length);
    return true;
  }
}
