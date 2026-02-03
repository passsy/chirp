import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';

/// Configuration for file-based log rotation.
///
/// Supports both size-based and time-based rotation strategies.
class FileRotationConfig {
  /// Maximum size of a single log file in bytes before rotation.
  ///
  /// When the current log file exceeds this size, it is rotated and a new
  /// file is created. Set to `null` to disable size-based rotation.
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
/// ## File Naming
///
/// Rotated files are named with timestamps:
/// - `app.log` - current log file
/// - `app.2024-01-15_10-30-45.log` - rotated file
/// - `app.2024-01-15_10-30-45.log.gz` - compressed rotated file
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
/// File writes are performed synchronously. For high-throughput scenarios,
/// consider wrapping with a buffering writer or using async writes.
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

  /// Current file handle for synchronous writes.
  RandomAccessFile? _file;

  /// Current file size in bytes (tracked for size-based rotation).
  int _currentFileSize = 0;

  /// Timestamp of the last rotation check (for time-based rotation).
  DateTime? _lastRotationCheck;

  /// Creates a rotating file writer.
  ///
  /// - [baseFilePath]: Path to the log file (e.g., `/var/log/app.log`)
  /// - [formatter]: How to format log records (default: [SimpleFileFormatter])
  /// - [rotationConfig]: Rotation settings, or `null` for no rotation
  /// - [encoding]: Text encoding (default: UTF-8)
  RotatingFileWriter({
    required this.baseFilePath,
    FileMessageFormatter? formatter,
    this.rotationConfig,
    this.encoding = utf8,
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
    _ensureOpen();

    // Initialize last rotation check on first write using record's timestamp
    // This ensures time-based rotation works correctly regardless of wall clock
    _lastRotationCheck ??= record.timestamp;

    // Check if rotation is needed before writing
    if (rotationConfig != null) {
      _checkRotation(record.timestamp);
    }

    // Format and write the record
    final line = formatter.format(record);
    final bytes = encoding.encode('$line\n');

    _file!.writeFromSync(bytes);
    _currentFileSize = _currentFileSize + bytes.length;
  }

  /// Checks if rotation is needed and performs it if so.
  void _checkRotation(DateTime timestamp) {
    final config = rotationConfig!;
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
      _rotate(timestamp);
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
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// Performs file rotation.
  void _rotate(DateTime timestamp) {
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
    _applyRetentionPolicy();

    // Reset state for new file
    _currentFileSize = 0;
    _lastRotationCheck = timestamp;

    // Reopen file
    _ensureOpen();
  }

  /// Generates a path for the rotated file.
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

    return '$dir/$baseName.$ts$extension';
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
  void _applyRetentionPolicy() {
    final config = rotationConfig;
    if (config == null) return;

    final rotatedFiles = _getRotatedFiles();
    if (rotatedFiles.isEmpty) return;

    // Sort by modification time (newest first)
    rotatedFiles
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    final now = clock.now();
    var filesToDelete = <File>[];

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
        // Log but don't throw - deletion failure shouldn't break logging
        print('[RotatingFileWriter] Failed to delete old log file: $e');
        print(stackTrace);
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
    _file?.flushSync();
  }

  /// Closes the file writer and releases resources.
  ///
  /// Always call this when done logging to ensure data is flushed.
  Future<void> close() async {
    _file?.flushSync();
    _file?.closeSync();
    _file = null;
  }

  /// Forces an immediate rotation regardless of size/time thresholds.
  ///
  /// Useful for log rotation triggered by external events (e.g., SIGHUP).
  void forceRotate() {
    if (_file != null) {
      _rotate(clock.now());
    }
  }
}
