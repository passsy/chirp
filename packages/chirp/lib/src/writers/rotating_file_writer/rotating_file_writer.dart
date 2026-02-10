import 'dart:async';
import 'dart:convert';

import 'package:chirp/chirp.dart';
import 'package:chirp/src/formatters/yaml_formatter.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer_stub.dart'
    if (dart.library.io) 'package:chirp/src/writers/rotating_file_writer/rotating_file_writer_io.dart'
    as platform;

export 'package:chirp/src/writers/rotating_file_writer/simple_file_formatter.dart';

/// Writes log records to files with optional rotation.
///
/// Supports both size-based and time-based rotation, with configurable
/// retention policies (max files, max age).
///
/// ## Basic Usage
///
/// ```dart
/// // Simple file writer without rotation
/// final writer = RotatingFileWriter(
///   baseFilePathProvider: () => '/var/log/app.log',
/// );
/// ```
///
/// ## Async Path with path_provider
///
/// Use [baseFilePathProvider] with an async callback to resolve the path
/// lazily. Records written before the path resolves are buffered.
///
/// ```dart
/// final writer = RotatingFileWriter(
///   baseFilePathProvider: () async {
///     final dir = await getApplicationSupportDirectory();
///     return '${dir.path}/logs/app.log';
///   },
/// );
/// ```
///
/// ## Size-Based Rotation
///
/// ```dart
/// // Rotate when file reaches 10 MB, keep 5 files
/// final writer = RotatingFileWriter(
///   baseFilePathProvider: () => '/var/log/app.log',
///   rotationConfig: FileRotationConfig.size(
///     maxSize: 10 * 1024 * 1024,
///     maxFiles: 5,
///   ),
/// );
/// ```
///
/// ## Daily Rotation
///
/// ```dart
/// // Rotate daily, keep 7 days of logs
/// final writer = RotatingFileWriter(
///   baseFilePathProvider: () => '/var/log/app.log',
///   rotationConfig: FileRotationConfig.daily(maxFiles: 7),
/// );
/// ```
///
/// ## JSON Lines Format
///
/// ```dart
/// // Write structured JSON logs
/// final writer = RotatingFileWriter(
///   baseFilePathProvider: () => '/var/log/app.jsonl',
///   formatter: const JsonLogFormatter(),
///   rotationConfig: FileRotationConfig.daily(maxFiles: 7),
/// );
/// ```
///
/// ## File Extensions
///
/// Choose the file extension based on the formatter:
/// - `.log` for [SimpleFileFormatter] (plain text)
/// - `.jsonl` or `.ndjson` for [JsonLogFormatter] (JSON Lines format)
///
/// ## File Naming
///
/// Rotated files are named with timestamps:
/// - `app.jsonl` - current log file
/// - `app.2024-01-15_10-30-45.jsonl` - rotated file
/// - `app.2024-01-15_10-30-45_1.jsonl` - second rotation in the same second
/// - `app.2024-01-15_10-30-45.jsonl.gz` - compressed rotated file
///
/// When multiple rotations occur within the same second (e.g., when
/// [FileRotationConfig.maxFileSize] is very small), a counter suffix is
/// appended to avoid overwriting previous rotated files.
///
/// ## Resource Management
///
/// Call [close] when done to flush buffers and release file handles:
///
/// ```dart
/// await writer.close();
/// ```
///
/// ## Thread Safety
///
/// File writes are performed synchronously by default. For high-throughput
/// scenarios, use [FlushStrategy.buffered].
///
/// ## Async Write Mode
///
/// Use [flushStrategy] to control how I/O is performed:
///
/// ```dart
/// // Buffered: accumulates records and flushes periodically
/// final writer = RotatingFileWriter(
///   baseFilePathProvider: () => '/var/log/app.log',
///   flushStrategy: FlushStrategy.buffered,
///   flushInterval: Duration(milliseconds: 100),
/// );
/// ```
///
/// ## Platform Support
///
/// Not supported on web platforms (JavaScript, WASM). Constructing this writer
/// will throw [UnsupportedError] when file I/O is unavailable.
///
/// The implementation uses conditional imports (`rotating_file_writer_io.dart`
/// vs `rotating_file_writer_stub.dart`) to support compilation to WASM where
/// `dart:io` is not available.
abstract class RotatingFileWriter extends ChirpWriter {
  /// Creates a rotating file writer.
  ///
  /// Use [baseFilePathProvider] to provide the file path. The provider may
  /// return the path synchronously (`String`) or asynchronously
  /// (`Future<String>`). Any records written before the path is available are
  /// buffered and written once the path resolves.
  factory RotatingFileWriter({
    required FutureOr<String> Function() baseFilePathProvider,
    ChirpFormatter? formatter,
    FileRotationConfig? rotationConfig,
    Encoding encoding = utf8,
    FileWriterErrorHandler? onError,
    FlushStrategy? flushStrategy,
    Duration flushInterval = const Duration(seconds: 1),
  }) {
    return platform.createRotatingFileWriter(
      baseFilePathProvider: baseFilePathProvider,
      formatter: formatter,
      rotationConfig: rotationConfig,
      encoding: encoding,
      onError: onError,
      flushStrategy: flushStrategy,
      flushInterval: flushInterval,
    );
  }

  /// Base path for log files.
  ///
  /// This is the path to the current log file. Rotated files are created
  /// in the same directory with timestamps appended to the name.
  String get baseFilePath;

  /// Formatter for converting log records to text.
  ChirpFormatter get formatter;

  /// Rotation configuration, or `null` for no rotation.
  FileRotationConfig? get rotationConfig;

  /// Encoding for writing text to files.
  Encoding get encoding;

  /// Error handler for write failures.
  ///
  /// Called when a log record cannot be written due to I/O errors.
  /// Defaults to [defaultFileWriterErrorHandler] which prints errors.
  FileWriterErrorHandler? get onError;

  /// Mode for how file I/O is performed.
  ///
  /// - [FlushStrategy.synchronous]: Immediate synchronous writes
  /// - [FlushStrategy.buffered]: Buffered async writes with periodic flushing
  ///
  /// Defaults to [FlushStrategy.synchronous] in debug mode (asserts enabled) for
  /// immediate log visibility, and [FlushStrategy.buffered] in release mode
  /// for better performance.
  FlushStrategy get flushStrategy;

  /// Interval between automatic buffer flushes in [FlushStrategy.buffered].
  ///
  /// Records are buffered and flushed to disk after this interval.
  /// Shorter intervals reduce data loss risk but increase I/O frequency.
  /// Default is 1 second.
  ///
  /// Note: Error-level logs and above are always written synchronously,
  /// regardless of this interval.
  Duration get flushInterval;

  /// Flushes buffered data to disk.
  ///
  /// Call this to ensure all logged data is persisted.
  Future<void> flush();

  /// Closes the file writer and releases resources.
  ///
  /// Always call this when done logging to ensure data is flushed.
  Future<void> close();

  /// Forces an immediate rotation regardless of size/time thresholds.
  ///
  /// Useful for log rotation triggered by external events (e.g., SIGHUP).
  Future<void> forceRotate();
}

/// Callback for handling errors during file write operations.
///
/// Called when [RotatingFileWriter] fails to write a log record due to
/// I/O errors such as disk full, permission denied, or file system failures.
///
/// Parameters:
/// - [error]: The exception that occurred (e.g., [FileSystemException])
/// - [stackTrace]: Stack trace for debugging
/// - [record]: The log record that failed to write (may be `null` if error
///   occurred during cleanup or rotation triggered by [RotatingFileWriter.forceRotate])
typedef FileWriterErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
  LogRecord? record,
);

/// Default error handler that prints errors to stdout.
///
/// This is used when [RotatingFileWriter.onError] is `null`.
void defaultFileWriterErrorHandler(
  Object error,
  StackTrace stackTrace,
  LogRecord? record,
) {
  // ignore: avoid_print
  print('[RotatingFileWriter] Error message: $error');
  // ignore: avoid_print
  print(stackTrace);
}

/// Configuration for file-based log rotation.
///
/// Supports both size-based and time-based rotation strategies.
class FileRotationConfig {
  /// Maximum size of a single log file in bytes before rotation.
  ///
  /// When the current log file exceeds this size, it is rotated on the next
  /// write. Set to `null` to disable size-based rotation.
  ///
  /// **Note:** Log entries are never dropped or truncated. If a single log
  /// entry is larger than [maxFileSize], it is still written in full, and
  /// rotation occurs before the next entry. This means individual files may
  /// temporarily exceed [maxFileSize].
  ///
  /// Common values:
  /// - 1 MB = 1024 * 1024 = 1048576
  /// - 10 MB = 10 * 1024 * 1024 = 10485760
  /// - 100 MB = 100 * 1024 * 1024 = 104857600
  final int? maxFileSize;

  /// Maximum number of log files to keep (including current).
  ///
  /// When the number of log files exceeds this limit, the oldest files are
  /// deleted. Set to `null` to keep all files (no limit).
  ///
  /// Must be at least 2 (1 current + 1 rotated). For example, `maxFileCount: 5`
  /// keeps the current file plus 4 rotated files.
  ///
  /// Note: This is not a ring buffer. Rotation creates new files; it doesn't
  /// remove old entries from a single file. Use `null` if you don't want
  /// automatic deletion of old log files.
  final int? maxFileCount;

  /// Maximum age of log files before deletion.
  ///
  /// Files older than this duration are deleted during rotation. Set to `null`
  /// to disable age-based deletion.
  ///
  /// Common values:
  /// - 7 days: `Duration(days: 7)`
  /// - 30 days: `Duration(days: 30)`
  final Duration? maxAge;

  /// Time-based rotation interval.
  ///
  /// When set, files are rotated at the specified interval regardless of size.
  /// Common values:
  /// - [FileRotationInterval.daily] - rotate at midnight
  /// - [FileRotationInterval.hourly] - rotate at the start of each hour
  ///
  /// Can be combined with [maxFileSize] for both size and time rotation.
  final FileRotationInterval? rotationInterval;

  /// Whether to compress rotated files using gzip.
  ///
  /// When `true`, rotated files are compressed to `*.gz` format.
  /// Reduces disk space but adds CPU overhead during rotation.
  final bool compress;

  /// Creates a rotation configuration.
  ///
  /// At least one rotation trigger should be configured:
  /// - [maxFileSize] for size-based rotation
  /// - [rotationInterval] for time-based rotation
  ///
  /// Retention can be controlled with:
  /// - [maxFileCount] to limit the number of files (must be >= 2)
  /// - [maxAge] to delete files older than a duration
  ///
  /// Throws [ArgumentError] if [maxFileCount] is less than 2.
  FileRotationConfig({
    this.maxFileSize,
    this.maxFileCount,
    this.maxAge,
    this.rotationInterval,
    this.compress = false,
  }) {
    if (maxFileCount != null && maxFileCount! < 2) {
      throw ArgumentError.value(
        maxFileCount,
        'maxFileCount',
        'must be null or >= 2 (1 current + at least 1 rotated)',
      );
    }
  }

  /// Convenience constructor for size-only rotation.
  ///
  /// Creates a config that rotates when files reach [maxSize] bytes,
  /// keeping at most [maxFiles] rotated files.
  ///
  /// Example:
  /// ```dart
  /// // Rotate at 10 MB, keep 5 files
  /// FileRotationConfig.size(
  ///   maxSize: 10 * 1024 * 1024,
  ///   maxFiles: 5,
  /// )
  /// ```
  FileRotationConfig.size({
    required int maxSize,
    int? maxFiles,
    Duration? maxAge,
    bool compress = false,
  }) : this(
          maxFileSize: maxSize,
          maxFileCount: maxFiles,
          maxAge: maxAge,
          compress: compress,
        );

  /// Convenience constructor for daily rotation.
  ///
  /// Creates a config that rotates files daily at midnight,
  /// keeping at most [maxFiles] rotated files.
  ///
  /// Example:
  /// ```dart
  /// // Rotate daily, keep 7 days of logs
  /// FileRotationConfig.daily(maxFiles: 7)
  /// ```
  FileRotationConfig.daily({
    int? maxFiles,
    Duration? maxAge,
    int? maxFileSize,
    bool compress = false,
  }) : this(
          rotationInterval: FileRotationInterval.daily,
          maxFileCount: maxFiles,
          maxAge: maxAge,
          maxFileSize: maxFileSize,
          compress: compress,
        );

  /// Convenience constructor for hourly rotation.
  ///
  /// Creates a config that rotates files at the start of each hour.
  ///
  /// Example:
  /// ```dart
  /// // Rotate hourly, keep 24 hours of logs
  /// FileRotationConfig.hourly(maxFiles: 24)
  /// ```
  FileRotationConfig.hourly({
    int? maxFiles,
    Duration? maxAge,
    int? maxFileSize,
    bool compress = false,
  }) : this(
          rotationInterval: FileRotationInterval.hourly,
          maxFileCount: maxFiles,
          maxAge: maxAge,
          maxFileSize: maxFileSize,
          compress: compress,
        );
}

/// Time intervals for automatic log rotation.
enum FileRotationInterval {
  /// Rotate at the start of each hour (e.g., 10:00, 11:00).
  hourly,

  /// Rotate at midnight each day.
  daily,

  /// Rotate at midnight on Sunday.
  weekly,

  /// Rotate at midnight on the first of each month.
  monthly,
}

/// Mode for how the file writer performs I/O operations.
///
/// Different modes trade off simplicity, latency, and main thread blocking.
enum FlushStrategy {
  /// Synchronous writes - blocks on every write.
  ///
  /// Every log record is immediately written to disk synchronously, which
  /// blocks the main thread until the I/O completes.
  ///
  /// **Pros:** Simple, guaranteed durability, no buffering delays.
  /// **Cons:** Can cause frame drops in UI applications with heavy logging.
  ///
  /// This is the default in debug mode (when asserts are enabled) for
  /// immediate log visibility during development.
  synchronous,

  /// Buffered async - accumulates records and flushes periodically.
  ///
  /// Records are buffered and flushed to disk asynchronously based on
  /// [RotatingFileWriter.flushInterval] (default: 1 second).
  ///
  /// **Important:** Error-level logs and above (error, critical, wtf) are
  /// always written synchronously to ensure they're persisted immediately,
  /// which is critical for crash debugging.
  ///
  /// **Pros:** Low overhead, reduced I/O frequency, minimal blocking.
  /// **Cons:** Small delay before non-error logs reach disk.
  ///
  /// This is the default in release mode for better performance.
  buffered,
}

/// Buffer for building plain text file output.
///
/// This provides a minimal, allocation-friendly API for formatters to build
/// log lines without allocating intermediate strings.
class FileMessageBuffer {
  final StringBuffer _buffer = StringBuffer();
  bool _endsWithNewline = false;

  /// Writes [value] to the buffer.
  void write(Object? value) {
    final text = value?.toString() ?? 'null';
    _buffer.write(text);
    if (text.isNotEmpty) {
      _endsWithNewline = text.endsWith('\n');
    }
  }

  /// Writes [value] and a newline to the buffer.
  void writeln(Object? value) {
    write(value);
    _buffer.write('\n');
    _endsWithNewline = true;
  }

  /// Writes a map as inline key-value data.
  ///
  /// Keys and values are formatted using [formatYamlKey] and [formatYamlValue]
  /// to match [InlineData] formatting.
  void writeData(
    Map<String, Object?>? data, {
    String entrySeparator = ', ',
    String keyValueSeparator = ': ',
  }) {
    if (data == null || data.isEmpty) {
      return;
    }

    var isFirst = true;
    for (final entry in data.entries) {
      if (isFirst) {
        isFirst = false;
      } else {
        write(entrySeparator);
      }

      write(formatYamlKey(entry.key));
      write(keyValueSeparator);
      write(formatYamlValue(entry.value));
    }
  }

  /// Ensures the buffer ends with a newline.
  void ensureLineBreak() {
    if (_buffer.isEmpty) {
      return;
    }

    if (_endsWithNewline) {
      return;
    }

    _buffer.write('\n');
    _endsWithNewline = true;
  }

  /// Clears the buffer contents.
  void clear() {
    _buffer.clear();
    _endsWithNewline = false;
  }

  /// Whether the buffer has no contents.
  bool get isEmpty => _buffer.isEmpty;

  /// The current character length of the buffer.
  int get length => _buffer.length;

  @override
  String toString() => _buffer.toString();
}

/// Backwards-compatible type alias.
@Deprecated('Use ChirpFormatter instead')
typedef FileMessageFormatter = ChirpFormatter;
