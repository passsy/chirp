import 'package:chirp/chirp.dart';
import 'package:meta/meta.dart';

export 'package:chirp/src/span/span_based_formatter.dart';
export 'package:chirp/src/span/spans.dart';

// =============================================================================
// Base LogSpan class - mutable tree with parent/child management
// =============================================================================

/// Base class for all log spans - a mutable tree structure.
///
/// Spans are composable building blocks for log output. Each span knows its
/// parent and can be manipulated in place (replaced, removed, wrapped).
///
/// ## Class hierarchy
///
/// ```text
/// LogSpan (abstract base)
/// ├── LeafSpan (no children)
/// │   ├── PlainText
/// │   ├── Whitespace
/// │   ├── NewLine
/// │   └── EmptySpan
/// ├── SingleChildSpan (one child)
/// │   ├── AnsiColored
/// │   └── Bordered
/// ├── MultiChildSpan (ordered children)
/// │   └── SpanSequence
/// └── SlottedSpan (named children)
///     └── Surrounded
/// ```
///
/// ## Example: Custom span
///
/// ```dart
/// class EmojiSpan extends LeafSpan {
///   final String emoji;
///
///   EmojiSpan(this.emoji);
///
///   @override
///   void render(ConsoleMessageBuffer buffer) {
///     buffer.write(emoji);
///   }
/// }
/// ```
///
/// ## Example: Transforming spans
///
/// ```dart
/// void transform(LogSpan root, LogRecord record) {
///   // Replace timestamp with emoji
///   root.findFirst<Timestamp>()?.replaceWith(LevelEmoji(record.level));
///
///   // Remove class name
///   root.findFirst<ClassName>()?.remove();
///
///   // Wrap message with border
///   root.findFirst<Message>()?.wrap((child) => Bordered(child: child));
/// }
/// ```
@experimental
abstract class LogSpan {
  LogSpan? _parent;

  /// Parent span in the tree, or null if this is the root.
  LogSpan? get parent => _parent;

  /// All direct children of this span.
  ///
  /// Override in subclasses to provide children.
  /// Returns an empty iterable by default (for leaf spans).
  Iterable<LogSpan> get allChildren => const [];

  /// Replaces this span in its parent with [newSpan].
  ///
  /// Returns true if replaced, false if this span has no parent.
  bool replaceWith(LogSpan newSpan);

  /// Removes this span from its parent.
  ///
  /// Returns true if removed, false if this span has no parent.
  bool remove();

  /// Wraps this span with a wrapper span.
  ///
  /// The [wrapper] function receives this span and should return a new span
  /// that contains this span as a child.
  ///
  /// Note: The wrapper function will receive this span as an argument. When
  /// adding this span as a child to the wrapper (e.g., via constructor parameter
  /// or addChild), the span will be automatically removed from its current
  /// parent. The wrap method handles updating the original parent to point
  /// to the wrapper.
  ///
  /// Example:
  /// ```dart
  /// span.wrap((child) => AnsiColored(foreground: XtermColor.red, child: child));
  /// ```
  void wrap(LogSpan Function(LogSpan child) wrapper) {
    final originalParent = _parent;
    // Store position info before the wrapper constructor potentially removes us
    int? originalIndex;
    String? originalSlotKey;
    if (originalParent is MultiChildSpan) {
      originalIndex = originalParent._children.indexOf(this);
    } else if (originalParent is SlottedSpan) {
      for (final entry in originalParent._slots.entries) {
        if (entry.value == this) {
          originalSlotKey = entry.key;
          break;
        }
      }
    }

    // Create the wrapper - this may remove this span from its original parent
    // when addChild or setting child property is called
    final wrapped = wrapper(this);

    // If we had an original parent, we need to put the wrapper in our place
    if (originalParent != null) {
      switch (originalParent) {
        case final SingleChildSpan parent:
          // Set the wrapper as the new child (we were already removed)
          if (parent._child == null || parent._child == this) {
            wrapped._parent?._removeChild(wrapped);
            wrapped._parent = parent;
            parent._child = wrapped;
          }
        case final MultiChildSpan parent:
          // Insert wrapper at our original position
          if (originalIndex != null && originalIndex >= 0) {
            wrapped._parent?._removeChild(wrapped);
            wrapped._parent = parent;
            // Clamp index in case list changed
            final insertIndex = originalIndex.clamp(0, parent._children.length);
            parent._children.insert(insertIndex, wrapped);
          }
        case final SlottedSpan parent:
          // Fill our original slot with the wrapper
          if (originalSlotKey != null) {
            wrapped._parent?._removeChild(wrapped);
            wrapped._parent = parent;
            parent._slots[originalSlotKey] = wrapped;
          }
      }
    }
  }

  /// Builds this span into another span, or returns itself if already terminal.
  ///
  /// Override this for composable spans that build to other spans.
  /// Default implementation returns `this`.
  ///
  /// Example:
  /// ```dart
  /// class Timestamp extends LeafSpan {
  ///   final DateTime date;
  ///   Timestamp(this.date);
  ///
  ///   @override
  ///   LogSpan build() => PlainText('${date.hour}:${date.minute}');
  /// }
  /// ```
  LogSpan build() => this;

  /// Renders this span to the [buffer].
  ///
  /// For primitive spans (PlainText, AnsiColored, etc.), override this to
  /// write directly to the buffer.
  ///
  /// For composite spans that override [build], the default implementation
  /// delegates to the built span.
  void render(ConsoleMessageBuffer buffer) {
    // Default: delegate to build() result
    renderSpan(build(), buffer);
  }

  /// Finds the first descendant (including self) of type [T].
  ///
  /// Returns null if no span of type [T] is found.
  T? findFirst<T extends LogSpan>() {
    if (this is T) return this as T;
    for (final child in allChildren) {
      final found = child.findFirst<T>();
      if (found != null) return found;
    }
    return null;
  }

  /// Finds all descendants (including self) of type [T].
  Iterable<T> findAll<T extends LogSpan>() sync* {
    if (this is T) yield this as T;
    for (final child in allChildren) {
      yield* child.findAll<T>();
    }
  }

  /// Returns all descendants (including self) in pre-order.
  Iterable<LogSpan> get allDescendants sync* {
    yield this;
    for (final child in allChildren) {
      yield* child.allDescendants;
    }
  }

  /// Returns all ancestors from parent to root.
  ///
  /// Does not include self. Empty if this is the root.
  Iterable<LogSpan> get allAncestors sync* {
    var current = _parent;
    while (current != null) {
      yield current;
      current = current._parent;
    }
  }

  /// Returns the root span of the tree.
  ///
  /// Returns self if this span has no parent.
  LogSpan get root {
    var current = this;
    while (current._parent != null) {
      current = current._parent!;
    }
    return current;
  }
}

// =============================================================================
// LeafSpan - spans with no children
// =============================================================================

/// Base class for spans that have no children.
///
/// Leaf spans are the primitive building blocks that render directly
/// to the buffer. Examples: [PlainText], [Whitespace], [NewLine], [EmptySpan].
@experimental
abstract class LeafSpan extends LogSpan {
  @override
  bool replaceWith(LogSpan newSpan) {
    final p = _parent;
    if (p == null) return false;
    p._replaceChild(this, newSpan);
    return true;
  }

  @override
  bool remove() {
    final p = _parent;
    if (p == null) return false;
    p._removeChild(this);
    return true;
  }
}

// =============================================================================
// SingleChildSpan - spans with exactly one child
// =============================================================================

/// Base class for spans that have exactly one child.
///
/// Examples: [AnsiColored], [Bordered].
@experimental
abstract class SingleChildSpan extends LogSpan {
  LogSpan? _child;

  /// Creates a single child span with an optional [child].
  SingleChildSpan({LogSpan? child}) {
    if (child != null) {
      this.child = child;
    }
  }

  /// The single child of this span.
  LogSpan? get child => _child;

  /// Sets the child span, updating parent references.
  set child(LogSpan? newChild) {
    _child?._parent = null;
    _child = newChild;
    if (newChild != null) {
      // Remove from old parent first
      newChild._parent?._removeChild(newChild);
      newChild._parent = this;
    }
  }

  @override
  Iterable<LogSpan> get allChildren =>
      _child != null ? [_child!] : const <LogSpan>[];

  @override
  bool replaceWith(LogSpan newSpan) {
    final p = _parent;
    if (p == null) return false;
    p._replaceChild(this, newSpan);
    return true;
  }

  @override
  bool remove() {
    final p = _parent;
    if (p == null) return false;
    p._removeChild(this);
    return true;
  }
}

// =============================================================================
// MultiChildSpan - spans with multiple ordered children
// =============================================================================

/// Base class for spans that have multiple ordered children.
///
/// Examples: [SpanSequence].
@experimental
abstract class MultiChildSpan extends LogSpan {
  final List<LogSpan> _children = [];

  /// Creates a multi child span with optional initial [children].
  MultiChildSpan({List<LogSpan>? children}) {
    if (children != null) {
      for (final child in children) {
        addChild(child);
      }
    }
  }

  /// Read-only view of children.
  List<LogSpan> get children => List.unmodifiable(_children);

  @override
  Iterable<LogSpan> get allChildren => _children;

  /// Adds [child] as the last child.
  void addChild(LogSpan child) {
    child._parent?._removeChild(child);
    child._parent = this;
    _children.add(child);
  }

  /// Inserts [child] at [index].
  void insertChild(int index, LogSpan child) {
    child._parent?._removeChild(child);
    child._parent = this;
    _children.insert(index, child);
  }

  /// Gets the index of [child] in this span's children.
  ///
  /// Returns -1 if [child] is not a child of this span.
  int indexOf(LogSpan child) => _children.indexOf(child);

  /// Gets the previous sibling of [child], or null if first.
  LogSpan? previousSiblingOf(LogSpan child) {
    final idx = _children.indexOf(child);
    return idx > 0 ? _children[idx - 1] : null;
  }

  /// Gets the next sibling of [child], or null if last.
  LogSpan? nextSiblingOf(LogSpan child) {
    final idx = _children.indexOf(child);
    return idx >= 0 && idx < _children.length - 1 ? _children[idx + 1] : null;
  }

  @override
  bool replaceWith(LogSpan newSpan) {
    final p = _parent;
    if (p == null) return false;
    p._replaceChild(this, newSpan);
    return true;
  }

  @override
  bool remove() {
    final p = _parent;
    if (p == null) return false;
    p._removeChild(this);
    return true;
  }
}

// =============================================================================
// SlottedSpan - spans with named child slots
// =============================================================================

/// Base class for spans that have named child slots.
///
/// Unlike [MultiChildSpan], slots have semantic names (e.g., prefix, child, suffix).
/// Examples: [Surrounded].
@experimental
abstract class SlottedSpan extends LogSpan {
  final Map<String, LogSpan> _slots = {};

  /// Gets the span in the named [slot].
  LogSpan? getSlot(String slot) => _slots[slot];

  /// Sets the span in the named [slot].
  void setSlot(String slot, LogSpan? child) {
    _slots[slot]?._parent = null;
    if (child != null) {
      child._parent?._removeChild(child);
      child._parent = this;
      _slots[slot] = child;
    } else {
      _slots.remove(slot);
    }
  }

  @override
  Iterable<LogSpan> get allChildren => _slots.values;

  @override
  bool replaceWith(LogSpan newSpan) {
    final p = _parent;
    if (p == null) return false;
    p._replaceChild(this, newSpan);
    return true;
  }

  @override
  bool remove() {
    final p = _parent;
    if (p == null) return false;
    p._removeChild(this);
    return true;
  }
}

// =============================================================================
// Internal child manipulation - called by child's replaceWith/remove
// =============================================================================

extension _ParentChildManagement on LogSpan {
  /// Replaces [oldChild] with [newChild] in this span's children.
  void _replaceChild(LogSpan oldChild, LogSpan newChild) {
    switch (this) {
      case final SingleChildSpan parent:
        if (parent._child == oldChild) {
          oldChild._parent = null;
          newChild._parent?._removeChild(newChild);
          newChild._parent = parent;
          parent._child = newChild;
        }
      case final MultiChildSpan parent:
        final index = parent._children.indexOf(oldChild);
        if (index != -1) {
          oldChild._parent = null;
          newChild._parent?._removeChild(newChild);
          newChild._parent = parent;
          parent._children[index] = newChild;
        }
      case final SlottedSpan parent:
        for (final entry in parent._slots.entries) {
          if (entry.value == oldChild) {
            oldChild._parent = null;
            newChild._parent?._removeChild(newChild);
            newChild._parent = parent;
            parent._slots[entry.key] = newChild;
            return;
          }
        }
    }
  }

  /// Removes [child] from this span's children.
  void _removeChild(LogSpan child) {
    switch (this) {
      case final SingleChildSpan parent:
        if (parent._child == child) {
          child._parent = null;
          parent._child = null;
        }
      case final MultiChildSpan parent:
        child._parent = null;
        parent._children.remove(child);
      case final SlottedSpan parent:
        final key = parent._slots.entries
            .where((e) => e.value == child)
            .map((e) => e.key)
            .firstOrNull;
        if (key != null) {
          child._parent = null;
          parent._slots.remove(key);
        }
    }
  }
}

// =============================================================================
// Rendering
// =============================================================================

/// Renders a [LogSpan] tree to a [ConsoleMessageBuffer].
///
/// Repeatedly calls [LogSpan.build] until the span returns itself (terminal),
/// then calls [LogSpan.render] on the terminal span.
@experimental
void renderSpan(LogSpan span, ConsoleMessageBuffer buffer) {
  // Build until terminal (span returns itself)
  var current = span;
  var built = current.build();
  while (!identical(built, current)) {
    current = built;
    built = current.build();
  }
  // Now current is terminal - call render directly
  current.render(buffer);
}
