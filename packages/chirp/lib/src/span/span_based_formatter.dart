import 'package:chirp/chirp.dart';
import 'package:meta/meta.dart';

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
///     return SpanSequence(children: [
///       Timestamp(record.date),
///       Whitespace(),
///       LogMessage(record.message),
///     ]);
///   }
/// }
/// ```
@experimental
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

    // Apply formatter's default transformers
    for (final transformer in spanTransformers) {
      transformer(span, record);
    }

    // Apply per-log transformers from formatOptions
    final perLogTransformers = record.formatOptions
        ?.whereType<SpanFormatOptions>()
        .expand((options) => options.spanTransformers);
    if (perLogTransformers != null) {
      for (final transformer in perLogTransformers) {
        transformer(span, record);
      }
    }

    // Transformers may wrap the original root in a new parent span.
    // Always render starting from the current root so wrappers (e.g. Bordered)
    // that become ancestors of the original span are included.
    renderSpan(span.root, buffer);
  }
}

/// Callback type for transforming log spans before rendering.
///
/// Receives a root [LogSpan] that can be mutated in place.
/// The [record] provides access to the original log data.
///
/// Example:
/// ```dart
/// void myTransformer(LogSpan root, LogRecord record) {
///   // Replace timestamp with level emoji
///   root.findFirst<Timestamp>()?.replaceWith(LevelEmoji(record.level));
/// }
/// ```
@experimental
typedef SpanTransformer = void Function(
  LogSpan span,
  LogRecord record,
);

/// Format options that include span transformers for [SpanBasedFormatter].
///
/// This allows per-log customization of the span tree, enabling features like:
/// - Wrapping specific logs in borders
/// - Adding custom decorations to important messages
/// - Removing or replacing spans for specific log entries
///
/// ## Example
///
/// ```dart
/// Chirp.info(
///   'Important message',
///   formatOptions: [
///     SpanFormatOptions(
///       spanTransformers: [
///         (span, record) => span.wrap(Bordered()),
///       ],
///     ),
///   ],
/// );
/// ```
@experimental
class SpanFormatOptions extends FormatOptions {
  const SpanFormatOptions({
    this.spanTransformers = const [],
  });

  /// Additional span transformers to apply for this specific log entry.
  ///
  /// These transformers are applied after the formatter's default transformers.
  final List<SpanTransformer> spanTransformers;
}
