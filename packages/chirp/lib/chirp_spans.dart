/// Span-based formatting system for building log output.
///
/// This library provides a tree-based approach to formatting log messages,
/// similar to how Flutter builds widget trees.
///
/// **Note:** This API is experimental and may change in future versions.
@experimental
library;

import 'package:meta/meta.dart';

export 'package:chirp/src/ansi/hash_colors.dart'
    show ColorSaturation, colorForHash;
export 'package:chirp/src/span/span_based_formatter.dart'
    show SpanBasedFormatter, SpanFormatOptions, SpanTransformer;
export 'package:chirp/src/span/span_foundation.dart'
    show
        LeafSpan,
        LogSpan,
        MultiChildSpan,
        SingleChildSpan,
        SlottedSpan,
        renderSpan;
export 'package:chirp/src/span/spans.dart'
    show
        Aligned,
        AnsiStyled,
        Bordered,
        BoxBorderChars,
        BoxBorderStyle,
        BracketedLogLevel,
        BracketedTimestamp,
        ChirpLogo,
        ClassName,
        DartSourceCodeLocation,
        DataKey,
        DataValue,
        EmptySpan,
        ErrorSpan,
        HorizontalAlign,
        InlineData,
        LogMessage,
        LoggerName,
        MethodName,
        MultilineData,
        NewLine,
        PlainText,
        SpanSequence,
        StackTraceSpan,
        Surrounded,
        Timestamp,
        Whitespace;
