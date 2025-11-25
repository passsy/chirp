import 'package:chirp/chirp.dart';

/// Base class for formatters that use the span-based templating system.
///
/// Provides common functionality for building spans, applying transformers,
/// and rendering to the buffer. Subclasses only need to implement [buildSpan].
///
/// ## Example
///
/// ```dart
/// class MyFormatter extends SpanBasedFormatter {
///   MyFormatter({super.spanTransformers});
///
///   @override
///   LogSpan buildSpan(LogRecord record) {
///     return SpanSequence([
///       Timestamp(record.date),
///       const Whitespace(),
///       LogMessage(record.message),
///     ]);
///   }
/// }
/// ```
abstract class SpanBasedFormatter extends ConsoleMessageFormatter {
  /// Transformers to apply to the span tree before rendering.
  ///
  /// Transformers are applied in order after [buildSpan] creates the initial
  /// span tree. They can modify, remove, or wrap spans in the tree.
  final List<SpanTransformer> spanTransformers;

  SpanBasedFormatter({
    List<SpanTransformer>? spanTransformers,
  }) : spanTransformers = spanTransformers ?? [];

  /// Builds the span tree for the given [record].
  ///
  /// Subclasses should return a [LogSpan] representing the formatted output.
  /// The span will be transformed by [spanTransformers] before rendering.
  LogSpan buildSpan(LogRecord record);

  @override
  void format(LogRecord record, ConsoleMessageBuffer buffer) {
    final span = buildSpan(record);

    if (spanTransformers.isEmpty) {
      renderSpan(span, buffer);
      return;
    }

    final tree = SpanNode.fromSpan(span);
    for (final transformer in spanTransformers) {
      transformer(tree, record);
    }
    renderSpan(tree.toSpan(), buffer);
  }
}
