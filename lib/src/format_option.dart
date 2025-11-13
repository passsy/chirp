/// A formatting option that controls how a formatter displays output
///
/// Like [ChirpLogLevel], this is a class rather than an enum to allow
/// custom formatting options to be defined by users and formatter implementations.
///
/// Each formatter defines its own format options as static constants.
/// For example, [RainbowMessageFormatter] defines [RainbowMessageFormatter.dataInline]
/// and [RainbowMessageFormatter.dataMultiline] options.
class FormatOptions {
  const FormatOptions();
}
