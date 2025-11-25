import 'package:chirp/chirp.dart';

export 'package:chirp/src/span/span_based_formatter.dart';
export 'package:chirp/src/span/spans.dart';

/// Base class for all log spans.
///
/// Spans are composable building blocks for log output. Third-party developers
/// should extend this class to create custom spans.
///
/// ## Example: Custom span
///
/// ```dart
/// class EmojiSpan extends LogSpan {
///   final String emoji;
///   final LogSpan child;
///
///   const EmojiSpan(this.emoji, {required this.child});
///
///   @override
///   LogSpan build() => Row([Text('$emoji '), child]);
/// }
/// ```
abstract class LogSpan {
  const LogSpan();

  /// Builds this span into another span (or itself for RenderSpans).
  LogSpan build();
}

/// A span that renders directly to a [ConsoleMessageBuffer].
///
/// Most spans should extend [LogSpan] and return composed spans from [build].
/// Only extend [RenderSpan] for primitive spans that write text directly.
abstract class RenderSpan extends LogSpan {
  const RenderSpan();

  @override
  LogSpan build() => this;

  /// Renders this span to the builder.
  void render(ConsoleMessageBuffer buffer);
}

/// Builds and renders a [LogSpan] tree to a [ConsoleMessageBuffer].
///
/// Repeatedly calls [LogSpan.build] until reaching a [RenderSpan],
/// then calls [RenderSpan.render].
void renderSpan(LogSpan span, ConsoleMessageBuffer builder) {
  var current = span;
  while (current is! RenderSpan) {
    current = current.build();
  }
  current.render(builder);
}

// =============================================================================
// Span interfaces for traversal
// =============================================================================

/// Interface for spans that have a single child.
///
/// Implement this to allow generic span traversal and transformation.
abstract interface class SingleChildSpan implements LogSpan {
  /// The child span (may be null for optional children like [Prefixed]).
  LogSpan? get child;
}

/// Interface for spans that have multiple children.
///
/// Implement this to allow generic span traversal and transformation.
abstract interface class MultiChildSpan implements LogSpan {
  /// The child spans.
  List<LogSpan> get children;
}

// =============================================================================
// Span transformer
// =============================================================================

/// Callback type for transforming log spans before rendering.
///
/// Receives a [SpanNode] tree that can be mutated in place.
/// The [record] provides access to the original log data.
typedef SpanTransformer = void Function(
  SpanNode tree,
  LogRecord record,
);


// =============================================================================
// Span tree utilities
// =============================================================================

/// Result of finding a span in the tree.
class SpanMatch<T extends LogSpan> {
  /// The found span.
  final T span;

  /// Parent spans from root to immediate parent (does not include [span]).
  final List<LogSpan> parents;

  const SpanMatch(this.span, this.parents);

  @override
  String toString() => 'SpanMatch($span, parents: $parents)';
}

/// Finds the first span of type [T] in the tree and returns it with its parents.
///
/// Returns `null` if no span of type [T] is found.
/// The [parents] list contains the path from root to the found span (exclusive).
SpanMatch<T>? findSpan<T extends LogSpan>(LogSpan span) {
  return _findSpan<T>(span, []);
}

SpanMatch<T>? _findSpan<T extends LogSpan>(
    LogSpan span, List<LogSpan> parents) {
  // Found the target
  if (span is T) {
    return SpanMatch(span, parents);
  }

  final newParents = [...parents, span];

  // Handle MultiChildSpan (Row)
  if (span is MultiChildSpan) {
    for (final child in span.children) {
      final result = _findSpan<T>(child, newParents);
      if (result != null) return result;
    }
  }

  // Handle SingleChildSpan (Styled, Box, Prefixed)
  if (span is SingleChildSpan) {
    final child = span.child;
    if (child != null) {
      final result = _findSpan<T>(child, newParents);
      if (result != null) return result;
    }
  }

  return null;
}

// =============================================================================
// SpanNode - Mutable wrapper for tree manipulation
// =============================================================================

/// A mutable wrapper around [LogSpan] that provides parent links and
/// tree manipulation methods.
///
/// SpanNode is like Flutter's Element - it represents a specific position
/// in the tree, while [LogSpan] (like Widget) is the immutable description.
///
/// ## Usage
///
/// ```dart
/// // Build a SpanNode tree from a LogSpan tree
/// final tree = SpanNode.fromSpan(rootSpan);
///
/// // Find and manipulate nodes
/// final levelNode = tree.findFirst<Level>();
/// levelNode?.remove();
///
/// // Convert back to LogSpan tree
/// final newSpan = tree.toSpan();
/// ```
class SpanNode {
  LogSpan _span;
  final List<SpanNode> _children = [];

  /// The underlying [LogSpan] this node wraps.
  LogSpan get span => _span;

  /// Parent node, null for root.
  SpanNode? parent;

  /// Child nodes in tree order (read-only view).
  ///
  /// For [Row]: all children in order.
  /// For [Styled], [Box]: single child at index 0.
  List<SpanNode> get children => List.unmodifiable(_children);

  SpanNode._(this._span);

  /// Builds a [SpanNode] tree from a [LogSpan] tree.
  ///
  /// This is O(n) where n is the number of spans in the tree.
  factory SpanNode.fromSpan(LogSpan span) {
    final node = SpanNode._(span);

    if (span is MultiChildSpan) {
      for (final child in span.children) {
        final childNode = SpanNode.fromSpan(child);
        childNode.parent = node;
        node._children.add(childNode);
      }
    } else if (span is SingleChildSpan && span.child != null) {
      final childNode = SpanNode.fromSpan(span.child!);
      childNode.parent = node;
      node._children.add(childNode);
    }

    return node;
  }

  /// Rebuilds a [LogSpan] tree from this [SpanNode] tree.
  ///
  /// This creates new span instances where children have changed.
  /// Leaf spans are returned as-is (no allocation).
  LogSpan toSpan() {
    final s = _span;

    if (s is SpanSequence) {
      return SpanSequence(_children.map((c) => c.toSpan()).toList());
    }

    if (s is AnsiColored) {
      return AnsiColored(
        foreground: s.foreground,
        background: s.background,
        child: _children.isNotEmpty ? _children.first.toSpan() : const PlainText(''),
      );
    }

    if (s is Prefixed) {
      return Prefixed(
        prefix: _children.isNotEmpty ? _children[0].toSpan() : const PlainText(''),
        child: _children.length > 1 ? _children[1].toSpan() : null,
      );
    }

    if (s is Bordered) {
      return Bordered(
        style: s.style,
        borderColor: s.borderColor,
        padding: s.padding,
        child: _children.isNotEmpty ? _children.first.toSpan() : const PlainText(''),
      );
    }

    // Leaf spans (PlainText, Whitespace, NewLine, Timestamp, BracketedLogLevel, etc.)
    return s;
  }

  /// Finds the first descendant node (including self) where span is of type [T].
  ///
  /// Returns null if no matching node is found.
  SpanNode? findFirst<T extends LogSpan>() {
    if (_span is T) return this;
    for (final child in _children) {
      final found = child.findFirst<T>();
      if (found != null) return found;
    }
    return null;
  }

  /// Finds all descendant nodes (including self) where span is of type [T].
  List<SpanNode> findAll<T extends LogSpan>() {
    final results = <SpanNode>[];
    _findAll<T>(results);
    return results;
  }

  void _findAll<T extends LogSpan>(List<SpanNode> results) {
    if (_span is T) results.add(this);
    for (final child in _children) {
      child._findAll<T>(results);
    }
  }

  /// Removes this node from its parent's children.
  ///
  /// Returns true if the node was removed, false if it had no parent.
  bool remove() {
    final removed = parent?._children.remove(this) ?? false;
    if (removed) parent = null;
    return removed;
  }

  /// Adds [child] as the last child of this node.
  ///
  /// If [child] already has a parent, it is removed from its current parent.
  void append(SpanNode child) {
    child.remove();
    child.parent = this;
    _children.add(child);
  }

  /// Adds [child] as the first child of this node.
  ///
  /// If [child] already has a parent, it is removed from its current parent.
  void prepend(SpanNode child) {
    child.remove();
    child.parent = this;
    _children.insert(0, child);
  }

  /// Inserts [newNode] before this node in its parent's children.
  ///
  /// Returns true if inserted, false if this node has no parent.
  bool insertBefore(SpanNode newNode) {
    if (parent == null) return false;
    final idx = parent!._children.indexOf(this);
    if (idx < 0) return false;

    newNode.remove();
    newNode.parent = parent;
    parent!._children.insert(idx, newNode);
    return true;
  }

  /// Inserts [newNode] after this node in its parent's children.
  ///
  /// Returns true if inserted, false if this node has no parent.
  bool insertAfter(SpanNode newNode) {
    if (parent == null) return false;
    final idx = parent!._children.indexOf(this);
    if (idx < 0) return false;

    newNode.remove();
    newNode.parent = parent;
    parent!._children.insert(idx + 1, newNode);
    return true;
  }

  /// Replaces this node with another node in its parent's children.
  ///
  /// Returns true if replaced, false if this node has no parent.
  bool replaceWith(SpanNode replacement) {
    if (parent == null) return false;
    final idx = parent!._children.indexOf(this);
    if (idx < 0) return false;

    parent!._children[idx] = replacement;
    replacement.parent = parent;
    parent = null;
    return true;
  }

  /// Replaces this node's span with a new span.
  ///
  /// This rebuilds the children to match the new span's structure.
  void replaceSpan(LogSpan newSpan) {
    // Clear existing children
    for (final child in _children) {
      child.parent = null;
    }
    _children.clear();

    _span = newSpan;

    // Rebuild children from new span using interfaces only
    if (newSpan is MultiChildSpan) {
      for (final child in newSpan.children) {
        final childNode = SpanNode.fromSpan(child);
        childNode.parent = this;
        _children.add(childNode);
      }
    } else if (newSpan is SingleChildSpan && newSpan.child != null) {
      final childNode = SpanNode.fromSpan(newSpan.child!);
      childNode.parent = this;
      _children.add(childNode);
    }
  }

  /// Wraps this node's span with a wrapper span.
  ///
  /// The wrapper must be a [SingleChildSpan] that takes this node's span
  /// as its child.
  ///
  /// Example:
  /// ```dart
  /// node.wrap((child) => Styled(foreground: XtermColor.red, child: child));
  /// ```
  void wrap(LogSpan Function(LogSpan child) wrapper) {
    final wrapped = wrapper(_span);
    replaceSpan(wrapped);
  }

  /// Unwraps this node by replacing it with its single child.
  ///
  /// Only works if this node has exactly one child.
  /// Returns true if unwrapped, false if node doesn't have exactly one child.
  bool unwrap() {
    if (_children.length != 1) return false;
    final child = _children.first;
    replaceSpan(child._span);
    return true;
  }

  /// Gets the previous sibling, or null if first child or no parent.
  SpanNode? get previousSibling {
    if (parent == null) return null;
    final idx = parent!._children.indexOf(this);
    return idx > 0 ? parent!._children[idx - 1] : null;
  }

  /// Gets the next sibling, or null if last child or no parent.
  SpanNode? get nextSibling {
    if (parent == null) return null;
    final siblings = parent!._children;
    final idx = siblings.indexOf(this);
    return idx >= 0 && idx < siblings.length - 1 ? siblings[idx + 1] : null;
  }

  /// Index of this node in parent's children, or -1 if no parent.
  int get index => parent?._children.indexOf(this) ?? -1;

  /// Returns all descendants (including self) in pre-order.
  Iterable<SpanNode> get allDescendants sync* {
    yield this;
    for (final child in _children) {
      yield* child.allDescendants;
    }
  }

  /// Returns all ancestors from parent to root.
  ///
  /// Does not include self. Empty if this is the root node.
  Iterable<SpanNode> get allAncestors sync* {
    var current = parent;
    while (current != null) {
      yield current;
      current = current.parent;
    }
  }

  /// Returns the root node of the tree.
  ///
  /// Returns self if this node has no parent.
  SpanNode get root {
    var current = this;
    while (current.parent != null) {
      current = current.parent!;
    }
    return current;
  }

  @override
  String toString() => 'SpanNode(${span.runtimeType})';
}
