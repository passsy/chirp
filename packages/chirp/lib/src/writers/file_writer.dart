import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';

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

/// Default error handler that prints errors to stderr.
///
/// This is used when [RotatingFileWriter.onError] is `null`.
void defaultFileWriterErrorHandler(
  Object error,
  StackTrace stackTrace,
  LogRecord? record,
) {
  stderr.writeln('[RotatingFileWriter] Write failed: $error');
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

  /// Maximum number of rotated log files to keep.
  ///
  /// When the number of log files exceeds this limit, the oldest files are
  /// deleted. Set to `null` to keep all files (no limit).
  ///
  /// The count includes the current log file. For example, `maxFileCount: 5`
  /// keeps the current file plus 4 rotated files.
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
  /// - [maxFileCount] to limit the number of files
  /// - [maxAge] to delete files older than a duration
  const FileRotationConfig({
    this.maxFileSize,
    this.maxFileCount,
    this.maxAge,
    this.rotationInterval,
    this.compress = false,
  });

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
  const FileRotationConfig.size({
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
  const FileRotationConfig.daily({
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
  const FileRotationConfig.hourly({
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
enum FileWriteMode {
  /// Synchronous writes - blocks on every write.
  ///
  /// This is the default mode. Every log record is immediately written to disk
  /// synchronously, which blocks the main thread until the I/O completes.
  ///
  /// **Pros:** Simple, guaranteed durability, no buffering delays.
  /// **Cons:** Can cause frame drops in UI applications with heavy logging.
  sync,

  /// Buffered async - accumulates records and flushes periodically.
  ///
  /// Records are buffered in the main isolate and flushed to disk
  /// asynchronously after a debounce interval or when the buffer is full.
  ///
  /// **Pros:** Low overhead, reduced I/O frequency, minimal blocking.
  /// **Cons:** Small delay before logs reach disk, potential data loss on crash.
  buffered,

  /// Isolate-based - offloads all I/O to a background isolate.
  ///
  /// Records are sent to a dedicated background isolate via [SendPort].
  /// The background isolate handles formatting and writing, so the main
  /// isolate never performs file I/O.
  ///
  /// **Pros:** Zero main-thread I/O blocking, best for 60fps apps.
  /// **Cons:** Higher memory overhead, isolate startup cost, message passing.
  isolate,
}

/// Formatter for converting [LogRecord] to plain text for file output.
///
/// Unlike [ConsoleMessageFormatter], this produces plain text without
/// ANSI color codes, suitable for log files.
abstract class FileMessageFormatter {
  /// Formats a [LogRecord] to a string for file output.
  ///
  /// The returned string should be a complete log line (without trailing
  /// newline - the writer adds that).
  String format(LogRecord record);
}

/// Default formatter that produces simple, readable log lines.
///
/// Output format: `2024-01-15T10:30:45.123 [INFO] Message`
///
/// With error: `2024-01-15T10:30:45.123 [ERROR] Message\nError: Something failed\n<stacktrace>`
class SimpleFileFormatter implements FileMessageFormatter {
  /// Whether to include the logger name in output.
  final bool includeLoggerName;

  /// Whether to include structured data in output.
  final bool includeData;

  /// Creates a simple file formatter.
  const SimpleFileFormatter({
    this.includeLoggerName = true,
    this.includeData = true,
  });

  @override
  String format(LogRecord record) {
    final buffer = StringBuffer();

    // Timestamp
    buffer.write(record.timestamp.toIso8601String());
    buffer.write(' ');

    // Level
    buffer.write('[');
    buffer.write(record.level.name.toUpperCase().padRight(8));
    buffer.write('] ');

    // Logger name
    if (includeLoggerName && record.loggerName != null) {
      buffer.write('[');
      buffer.write(record.loggerName);
      buffer.write('] ');
    }

    // Message
    buffer.write(record.message);

    // Structured data
    if (includeData && record.data.isNotEmpty) {
      buffer.write(' ');
      buffer.write(record.data);
    }

    // Error
    if (record.error != null) {
      buffer.write('\nError: ');
      buffer.write(record.error);
    }

    // Stack trace
    if (record.stackTrace != null) {
      buffer.write('\n');
      buffer.write(record.stackTrace);
    }

    return buffer.toString();
  }
}

/// JSON formatter for structured log files.
///
/// Produces one JSON object per line (JSONL/NDJSON format), suitable for
/// log aggregation systems like Elasticsearch, Splunk, or CloudWatch.
///
/// Use `.jsonl` or `.ndjson` file extension when using this formatter:
///
/// ```dart
/// final writer = RotatingFileWriter(
///   baseFilePath: '/var/log/app.jsonl',
///   formatter: JsonFileFormatter(),
/// );
/// ```
class JsonFileFormatter implements FileMessageFormatter {
  /// Creates a JSON file formatter.
  const JsonFileFormatter();

  @override
  String format(LogRecord record) {
    final map = <String, Object?>{
      'timestamp': record.timestamp.toIso8601String(),
      'level': record.level.name,
      'message': record.message?.toString(),
    };

    if (record.loggerName != null) {
      map['logger'] = record.loggerName;
    }

    if (record.data.isNotEmpty) {
      map['data'] = record.data;
    }

    if (record.error != null) {
      map['error'] = record.error.toString();
    }

    if (record.stackTrace != null) {
      map['stackTrace'] = record.stackTrace.toString();
    }

    // Simple JSON encoding without external dependency
    return _encodeJson(map);
  }

  String _encodeJson(Map<String, Object?> map) {
    final pairs = <String>[];
    for (final entry in map.entries) {
      final key = _escapeString(entry.key);
      final value = _encodeValue(entry.value);
      pairs.add('"$key":$value');
    }
    return '{${pairs.join(',')}}';
  }

  String _encodeValue(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is String) return '"${_escapeString(value)}"';
    if (value is Map) {
      final pairs = <String>[];
      for (final entry in value.entries) {
        final key = _escapeString(entry.key.toString());
        final val = _encodeValue(entry.value);
        pairs.add('"$key":$val');
      }
      return '{${pairs.join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_encodeValue).join(',')}]';
    }
    return '"${_escapeString(value.toString())}"';
  }

  String _escapeString(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }
}

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
///   baseFilePath: '/var/log/app.log',
/// );
/// ```
///
/// ## Size-Based Rotation
///
/// ```dart
/// // Rotate when file reaches 10 MB, keep 5 files
/// final writer = RotatingFileWriter(
///   baseFilePath: '/var/log/app.log',
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
///   baseFilePath: '/var/log/app.log',
///   rotationConfig: FileRotationConfig.daily(maxFiles: 7),
/// );
/// ```
///
/// ## JSON Lines Format
///
/// ```dart
/// // Write structured JSON logs
/// final writer = RotatingFileWriter(
///   baseFilePath: '/var/log/app.jsonl',
///   formatter: JsonFileFormatter(),
///   rotationConfig: FileRotationConfig.daily(maxFiles: 7),
/// );
/// ```
///
/// ## File Extensions
///
/// Choose the file extension based on the formatter:
/// - `.log` for [SimpleFileFormatter] (plain text)
/// - `.jsonl` or `.ndjson` for [JsonFileFormatter] (JSON Lines format)
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
/// scenarios, use [FileWriteMode.buffered] or [FileWriteMode.isolate].
///
/// ## Async Write Modes
///
/// Use [writeMode] to control how I/O is performed:
///
/// ```dart
/// // Buffered: accumulates records and flushes periodically
/// final writer = RotatingFileWriter(
///   baseFilePath: '/var/log/app.log',
///   writeMode: FileWriteMode.buffered,
///   flushInterval: Duration(milliseconds: 100),
/// );
///
/// // Isolate: offloads all I/O to a background isolate
/// final writer = RotatingFileWriter(
///   baseFilePath: '/var/log/app.log',
///   writeMode: FileWriteMode.isolate,
/// );
/// ```
class RotatingFileWriter extends ChirpWriter {
  /// Base path for log files.
  ///
  /// This is the path to the current log file. Rotated files are created
  /// in the same directory with timestamps appended to the name.
  final String baseFilePath;

  /// Formatter for converting log records to text.
  final FileMessageFormatter formatter;

  /// Rotation configuration, or `null` for no rotation.
  final FileRotationConfig? rotationConfig;

  /// Encoding for writing text to files.
  final Encoding encoding;

  /// Error handler for write failures.
  ///
  /// Called when a log record cannot be written due to I/O errors.
  /// Defaults to [defaultFileWriterErrorHandler] which prints to stderr.
  final FileWriterErrorHandler? onError;

  /// Mode for how file I/O is performed.
  ///
  /// - [FileWriteMode.sync]: Immediate synchronous writes (default)
  /// - [FileWriteMode.buffered]: Buffered async writes with periodic flushing
  /// - [FileWriteMode.isolate]: Dedicated background isolate for I/O
  final FileWriteMode writeMode;

  /// Interval between automatic buffer flushes in [FileWriteMode.buffered].
  ///
  /// Records are buffered and flushed to disk after this interval.
  /// Shorter intervals reduce data loss risk but increase I/O frequency.
  /// Default is 100ms.
  final Duration flushInterval;

  /// Maximum number of records to buffer before forcing a flush.
  ///
  /// When the buffer reaches this size, it is flushed immediately regardless
  /// of [flushInterval]. This prevents memory growth during logging bursts.
  /// Default is 1000 records.
  final int maxBufferSize;

  /// Current file handle for synchronous writes.
  RandomAccessFile? _file;

  /// Current file size in bytes (tracked for size-based rotation).
  int _currentFileSize = 0;

  /// Timestamp of the last rotation check (for time-based rotation).
  DateTime? _lastRotationCheck;

  // --- Buffered mode state ---

  /// Buffer for accumulating records in buffered mode.
  List<LogRecord>? _buffer;

  /// Timer for periodic buffer flushing.
  Timer? _flushTimer;

  /// Future that completes when the current async flush operation finishes.
  /// Used to wait for pending writes before close/flush.
  Future<void>? _pendingFlush;

  // --- Isolate mode state ---

  /// Send port to the background isolate.
  SendPort? _isolateSendPort;

  /// The background isolate instance.
  Isolate? _isolate;

  /// Completer that completes when the isolate is ready.
  Completer<void>? _isolateReady;

  /// Creates a rotating file writer.
  ///
  /// - [baseFilePath]: Path to the log file (e.g., `/var/log/app.log`)
  /// - [formatter]: How to format log records (default: [SimpleFileFormatter])
  /// - [rotationConfig]: Rotation settings, or `null` for no rotation
  /// - [encoding]: Text encoding (default: UTF-8)
  /// - [onError]: Handler for write failures (default: prints to stderr)
  /// - [writeMode]: How I/O is performed (default: [FileWriteMode.sync])
  /// - [flushInterval]: Buffer flush interval for buffered mode (default: 100ms)
  /// - [maxBufferSize]: Max buffer size before forced flush (default: 1000)
  RotatingFileWriter({
    required this.baseFilePath,
    FileMessageFormatter? formatter,
    this.rotationConfig,
    this.encoding = utf8,
    this.onError,
    this.writeMode = FileWriteMode.sync,
    this.flushInterval = const Duration(milliseconds: 100),
    this.maxBufferSize = 1000,
  }) : formatter = formatter ?? const SimpleFileFormatter();

  /// Opens the log file for writing.
  ///
  /// Called automatically on first write. Creates parent directories if needed.
  void _ensureOpen() {
    if (_file != null) return;

    final file = File(baseFilePath);

    // Create parent directories if they don't exist
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    // Get current file size for size-based rotation
    if (file.existsSync()) {
      _currentFileSize = file.lengthSync();
    } else {
      _currentFileSize = 0;
    }

    _file = file.openSync(mode: FileMode.append);
    // Note: _lastRotationCheck is set on first write to use the record's timestamp
  }

  @override
  void write(LogRecord record) {
    switch (writeMode) {
      case FileWriteMode.sync:
        _writeSync(record);
      case FileWriteMode.buffered:
        _writeBuffered(record);
      case FileWriteMode.isolate:
        _writeIsolate(record);
    }
  }

  /// Synchronous write implementation - blocks on every write.
  void _writeSync(LogRecord record) {
    try {
      _ensureOpen();

      // Initialize last rotation check on first write using record's timestamp
      // This ensures time-based rotation works correctly regardless of wall clock
      _lastRotationCheck ??= record.timestamp;

      // Check if rotation is needed before writing
      if (rotationConfig != null) {
        _checkRotation(record);
      }

      // Format and write the record
      final line = formatter.format(record);
      final bytes = encoding.encode('$line\n');

      _file!.writeFromSync(bytes);
      _currentFileSize = _currentFileSize + bytes.length;
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, record);
    }
  }

  /// Buffered write implementation - accumulates records and flushes periodically.
  void _writeBuffered(LogRecord record) {
    _buffer ??= [];
    _buffer!.add(record);

    // Start flush timer if not already running
    _flushTimer ??= Timer.periodic(flushInterval, (_) => _flushBuffer());

    // Force flush if buffer is full
    if (_buffer!.length >= maxBufferSize) {
      _flushBuffer();
    }
  }

  /// Flushes the buffer to disk asynchronously.
  void _flushBuffer() {
    if (_pendingFlush != null || _buffer == null || _buffer!.isEmpty) return;

    final recordsToFlush = _buffer!;
    _buffer = [];

    // Run async I/O without blocking the caller
    _pendingFlush = _flushBufferAsync(recordsToFlush).whenComplete(() {
      _pendingFlush = null;
    });
  }

  /// Async implementation of buffer flushing.
  Future<void> _flushBufferAsync(List<LogRecord> records) async {
    try {
      _ensureOpen();

      for (final record in records) {
        // Initialize last rotation check on first write
        _lastRotationCheck ??= record.timestamp;

        // Check if rotation is needed before writing
        if (rotationConfig != null) {
          _checkRotation(record);
        }

        // Format and write the record
        final line = formatter.format(record);
        final bytes = encoding.encode('$line\n');

        // Use async write
        await _file!.writeFrom(bytes);
        _currentFileSize = _currentFileSize + bytes.length;
      }
    } catch (e, stackTrace) {
      // Report error for the batch (no specific record)
      _handleError(e, stackTrace, null);
    }
  }

  /// Isolate-based write implementation - offloads I/O to background isolate.
  void _writeIsolate(LogRecord record) {
    // Start isolate if not already running
    if (_isolateReady == null) {
      _isolateReady = Completer<void>();
      _startIsolate();
    }

    // Format the record in the main isolate (formatter may not be isolate-safe)
    final line = formatter.format(record);

    // Send to isolate (fire and forget)
    if (_isolateSendPort != null) {
      _isolateSendPort!.send(_IsolateWriteMessage(
        line: line,
        timestamp: record.timestamp,
      ));
    } else {
      // Queue for when isolate is ready
      _isolateReady!.future.then((_) {
        _isolateSendPort?.send(_IsolateWriteMessage(
          line: line,
          timestamp: record.timestamp,
        ));
      });
    }
  }

  /// Starts the background isolate for I/O operations.
  Future<void> _startIsolate() async {
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateInitMessage(
        sendPort: receivePort.sendPort,
        baseFilePath: baseFilePath,
        encoding: encoding.name,
        rotationConfig: rotationConfig,
      ),
    );

    // Wait for isolate to send back its SendPort
    final response = await receivePort.first;
    if (response is SendPort) {
      _isolateSendPort = response;
      _isolateReady?.complete();
    } else if (response is _IsolateErrorMessage) {
      _handleError(response.error, response.stackTrace, null);
      _isolateReady?.completeError(response.error);
    }
  }

  /// Handles write errors by calling [onError] or the default handler.
  void _handleError(Object error, StackTrace stackTrace, LogRecord? record) {
    final handler = onError ?? defaultFileWriterErrorHandler;
    handler(error, stackTrace, record);
  }

  /// Checks if rotation is needed and performs it if so.
  void _checkRotation(LogRecord record) {
    final config = rotationConfig!;
    final timestamp = record.timestamp;
    var shouldRotate = false;

    // Check size-based rotation
    if (config.maxFileSize != null && _currentFileSize >= config.maxFileSize!) {
      shouldRotate = true;
    }

    // Check time-based rotation
    if (config.rotationInterval != null && _lastRotationCheck != null) {
      shouldRotate = shouldRotate ||
          _shouldRotateByTime(timestamp, config.rotationInterval!);
    }

    if (shouldRotate) {
      _rotate(record);
    }
  }

  /// Determines if time-based rotation is needed.
  bool _shouldRotateByTime(DateTime now, FileRotationInterval interval) {
    final last = _lastRotationCheck!;

    return switch (interval) {
      FileRotationInterval.hourly => now.year != last.year ||
          now.month != last.month ||
          now.day != last.day ||
          now.hour != last.hour,
      FileRotationInterval.daily =>
        now.year != last.year || now.month != last.month || now.day != last.day,
      FileRotationInterval.weekly =>
        _weekNumber(now) != _weekNumber(last) || now.year != last.year,
      FileRotationInterval.monthly =>
        now.year != last.year || now.month != last.month,
    };
  }

  /// Calculates ISO week number.
  int _weekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// Performs file rotation.
  ///
  /// [record] may be null when called from [forceRotate].
  void _rotate(LogRecord? record) {
    final timestamp = record?.timestamp ?? clock.now();

    // Flush and close current file synchronously
    _file?.flushSync();
    _file?.closeSync();
    _file = null;

    // Generate rotated filename using the last rotation timestamp
    // (the file contains logs from the previous period)
    final rotatedPath = _generateRotatedPath(_lastRotationCheck ?? timestamp);
    final currentFile = File(baseFilePath);

    if (currentFile.existsSync()) {
      // Rename current file to rotated name
      currentFile.renameSync(rotatedPath);

      // Compress if configured
      if (rotationConfig?.compress == true) {
        _compressFile(rotatedPath);
      }
    }

    // Clean up old files based on retention policy
    _applyRetentionPolicy(record);

    // Reset state for new file
    _currentFileSize = 0;
    _lastRotationCheck = timestamp;

    // Reopen file
    _ensureOpen();
  }

  /// Generates a path for the rotated file.
  ///
  /// If a file with the timestamp already exists (multiple rotations in the
  /// same second), appends a counter suffix: `app.2024-01-15_10-30-45_1.log`
  String _generateRotatedPath(DateTime timestamp) {
    final file = File(baseFilePath);
    final dir = file.parent.path;
    final name = file.uri.pathSegments.last;

    // Split name into base and extension
    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    final extension = dotIndex > 0 ? name.substring(dotIndex) : '';

    // Format timestamp for filename
    final ts = timestamp
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('T', '_')
        .split('.')[0];

    // Check if file already exists, add counter suffix if needed
    var path = '$dir/$baseName.$ts$extension';
    var counter = 1;
    while (File(path).existsSync()) {
      path = '$dir/$baseName.${ts}_$counter$extension';
      counter++;
    }

    return path;
  }

  /// Compresses a file using gzip.
  void _compressFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return;

    final bytes = file.readAsBytesSync();
    final compressed = gzip.encode(bytes);
    File('$path.gz').writeAsBytesSync(compressed);
    file.deleteSync();
  }

  /// Applies retention policy to remove old log files.
  void _applyRetentionPolicy(LogRecord? record) {
    final config = rotationConfig;
    if (config == null) return;

    final rotatedFiles = _getRotatedFiles();
    if (rotatedFiles.isEmpty) return;

    // Sort by modification time (newest first)
    rotatedFiles
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    final now = clock.now();
    final filesToDelete = <File>[];

    // Apply max file count policy
    if (config.maxFileCount != null) {
      // -1 because maxFileCount includes the current file
      final maxRotated = config.maxFileCount! - 1;
      if (rotatedFiles.length > maxRotated) {
        filesToDelete.addAll(rotatedFiles.sublist(maxRotated));
      }
    }

    // Apply max age policy
    if (config.maxAge != null) {
      final cutoff = now.subtract(config.maxAge!);
      for (final file in rotatedFiles) {
        final modified = file.statSync().modified;
        if (modified.isBefore(cutoff) && !filesToDelete.contains(file)) {
          filesToDelete.add(file);
        }
      }
    }

    // Delete files
    for (final file in filesToDelete) {
      try {
        file.deleteSync();
      } catch (e, stackTrace) {
        _handleError(e, stackTrace, record);
      }
    }
  }

  /// Gets all rotated log files (not the current one).
  List<File> _getRotatedFiles() {
    final currentFile = File(baseFilePath);
    final dir = currentFile.parent;
    final name = currentFile.uri.pathSegments.last;

    // Extract base name for matching rotated files
    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;

    if (!dir.existsSync()) return [];

    return dir.listSync().whereType<File>().where((f) {
      final fileName = f.uri.pathSegments.last;
      // Match rotated files: baseName.TIMESTAMP.extension or baseName.TIMESTAMP.extension.gz
      return fileName.startsWith('$baseName.') &&
          fileName != name &&
          (fileName.contains(RegExp(r'\d{4}-\d{2}-\d{2}')) ||
              fileName.endsWith('.gz'));
    }).toList();
  }

  /// Flushes buffered data to disk.
  ///
  /// Call this to ensure all logged data is persisted.
  Future<void> flush() async {
    switch (writeMode) {
      case FileWriteMode.sync:
        _file?.flushSync();
      case FileWriteMode.buffered:
        // Cancel the periodic timer
        _flushTimer?.cancel();
        _flushTimer = null;
        // Wait for any pending async flush to complete
        if (_pendingFlush != null) {
          await _pendingFlush;
        }
        // Flush remaining buffer
        if (_buffer != null && _buffer!.isNotEmpty) {
          final recordsToFlush = _buffer!;
          _buffer = [];
          await _flushBufferAsync(recordsToFlush);
        }
        // Use async flush since we use async writes in buffered mode
        await _file?.flush();
      case FileWriteMode.isolate:
        // Wait for isolate to be ready first
        if (_isolateReady != null) {
          await _isolateReady!.future;
        }
        if (_isolateSendPort != null) {
          final completer = Completer<void>();
          final receivePort = ReceivePort();
          receivePort.listen((message) {
            if (message == 'flushed') {
              completer.complete();
              receivePort.close();
            }
          });
          _isolateSendPort!.send(_IsolateFlushMessage(receivePort.sendPort));
          await completer.future;
        }
    }
  }

  /// Closes the file writer and releases resources.
  ///
  /// Always call this when done logging to ensure data is flushed.
  Future<void> close() async {
    switch (writeMode) {
      case FileWriteMode.sync:
        _file?.flushSync();
        _file?.closeSync();
        _file = null;
      case FileWriteMode.buffered:
        // Cancel the periodic timer
        _flushTimer?.cancel();
        _flushTimer = null;
        // Wait for any pending async flush to complete
        if (_pendingFlush != null) {
          await _pendingFlush;
        }
        // Flush remaining buffer
        if (_buffer != null && _buffer!.isNotEmpty) {
          final recordsToFlush = _buffer!;
          _buffer = [];
          await _flushBufferAsync(recordsToFlush);
        }
        // Use async flush/close since we use async writes in buffered mode
        await _file?.flush();
        await _file?.close();
        _file = null;
      case FileWriteMode.isolate:
        // Wait for isolate to be ready first
        if (_isolateReady != null) {
          await _isolateReady!.future;
        }
        if (_isolateSendPort != null) {
          final completer = Completer<void>();
          final receivePort = ReceivePort();
          receivePort.listen((message) {
            if (message == 'closed') {
              completer.complete();
              receivePort.close();
            }
          });
          _isolateSendPort!.send(_IsolateCloseMessage(receivePort.sendPort));
          await completer.future;
        }
        _isolate?.kill();
        _isolate = null;
        _isolateSendPort = null;
        _isolateReady = null;
    }
  }

  /// Forces an immediate rotation regardless of size/time thresholds.
  ///
  /// Useful for log rotation triggered by external events (e.g., SIGHUP).
  Future<void> forceRotate() async {
    switch (writeMode) {
      case FileWriteMode.sync:
      case FileWriteMode.buffered:
        if (_file != null) {
          _rotate(null);
        }
      case FileWriteMode.isolate:
        // Wait for isolate to be ready first
        if (_isolateReady != null) {
          await _isolateReady!.future;
        }
        if (_isolateSendPort != null) {
          final completer = Completer<void>();
          final receivePort = ReceivePort();
          receivePort.listen((message) {
            if (message == 'rotated') {
              completer.complete();
              receivePort.close();
            }
          });
          _isolateSendPort!.send(_IsolateRotateMessage(receivePort.sendPort));
          await completer.future;
        }
    }
  }
}

// --- Isolate message classes ---

/// Message to initialize the background isolate.
class _IsolateInitMessage {
  final SendPort sendPort;
  final String baseFilePath;
  final String encoding;
  final FileRotationConfig? rotationConfig;

  _IsolateInitMessage({
    required this.sendPort,
    required this.baseFilePath,
    required this.encoding,
    required this.rotationConfig,
  });
}

/// Message to write a log line to the file.
class _IsolateWriteMessage {
  final String line;
  final DateTime timestamp;

  _IsolateWriteMessage({required this.line, required this.timestamp});
}

/// Message to flush the file.
class _IsolateFlushMessage {
  final SendPort replyPort;

  _IsolateFlushMessage(this.replyPort);
}

/// Message to close the file.
class _IsolateCloseMessage {
  final SendPort replyPort;

  _IsolateCloseMessage(this.replyPort);
}

/// Message to force rotation.
class _IsolateRotateMessage {
  final SendPort replyPort;

  _IsolateRotateMessage(this.replyPort);
}

/// Message to report an error from the isolate.
class _IsolateErrorMessage {
  final Object error;
  final StackTrace stackTrace;

  _IsolateErrorMessage(this.error, this.stackTrace);
}

/// Entry point for the background isolate.
void _isolateEntryPoint(_IsolateInitMessage init) {
  final receivePort = ReceivePort();
  final encoding = Encoding.getByName(init.encoding) ?? utf8;

  RandomAccessFile? file;
  int currentFileSize = 0;
  DateTime? lastRotationCheck;

  void ensureOpen() {
    if (file != null) return;

    final f = File(init.baseFilePath);
    final parent = f.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    if (f.existsSync()) {
      currentFileSize = f.lengthSync();
    } else {
      currentFileSize = 0;
    }

    file = f.openSync(mode: FileMode.append);
  }

  bool shouldRotateByTime(DateTime now, FileRotationInterval interval) {
    final last = lastRotationCheck!;

    return switch (interval) {
      FileRotationInterval.hourly => now.year != last.year ||
          now.month != last.month ||
          now.day != last.day ||
          now.hour != last.hour,
      FileRotationInterval.daily =>
        now.year != last.year || now.month != last.month || now.day != last.day,
      FileRotationInterval.weekly =>
        _isolateWeekNumber(now) != _isolateWeekNumber(last) ||
            now.year != last.year,
      FileRotationInterval.monthly =>
        now.year != last.year || now.month != last.month,
    };
  }

  String generateRotatedPath(DateTime timestamp) {
    final f = File(init.baseFilePath);
    final dir = f.parent.path;
    final name = f.uri.pathSegments.last;

    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    final extension = dotIndex > 0 ? name.substring(dotIndex) : '';

    final ts = timestamp
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('T', '_')
        .split('.')[0];

    var path = '$dir/$baseName.$ts$extension';
    var counter = 1;
    while (File(path).existsSync()) {
      path = '$dir/$baseName.${ts}_$counter$extension';
      counter++;
    }

    return path;
  }

  void rotate(DateTime timestamp) {
    file?.flushSync();
    file?.closeSync();
    file = null;

    final rotatedPath = generateRotatedPath(lastRotationCheck ?? timestamp);
    final currentFile = File(init.baseFilePath);

    if (currentFile.existsSync()) {
      currentFile.renameSync(rotatedPath);

      if (init.rotationConfig?.compress == true) {
        final f = File(rotatedPath);
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          final compressed = gzip.encode(bytes);
          File('$rotatedPath.gz').writeAsBytesSync(compressed);
          f.deleteSync();
        }
      }
    }

    currentFileSize = 0;
    lastRotationCheck = timestamp;

    ensureOpen();
  }

  void checkRotation(DateTime timestamp) {
    final config = init.rotationConfig;
    if (config == null) return;

    var shouldRotate = false;

    if (config.maxFileSize != null && currentFileSize >= config.maxFileSize!) {
      shouldRotate = true;
    }

    if (config.rotationInterval != null && lastRotationCheck != null) {
      shouldRotate =
          shouldRotate || shouldRotateByTime(timestamp, config.rotationInterval!);
    }

    if (shouldRotate) {
      rotate(timestamp);
    }
  }

  // Send our receive port back to main isolate
  init.sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    try {
      if (message is _IsolateWriteMessage) {
        ensureOpen();
        lastRotationCheck ??= message.timestamp;
        checkRotation(message.timestamp);

        final bytes = encoding.encode('${message.line}\n');
        file!.writeFromSync(bytes);
        currentFileSize = currentFileSize + bytes.length;
      } else if (message is _IsolateFlushMessage) {
        file?.flushSync();
        message.replyPort.send('flushed');
      } else if (message is _IsolateCloseMessage) {
        file?.flushSync();
        file?.closeSync();
        file = null;
        message.replyPort.send('closed');
      } else if (message is _IsolateRotateMessage) {
        if (file != null) {
          rotate(DateTime.now());
        }
        message.replyPort.send('rotated');
      }
    } catch (e, stackTrace) {
      init.sendPort.send(_IsolateErrorMessage(e, stackTrace));
    }
  });
}

/// Week number calculation for isolate (cannot access instance methods).
int _isolateWeekNumber(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}
