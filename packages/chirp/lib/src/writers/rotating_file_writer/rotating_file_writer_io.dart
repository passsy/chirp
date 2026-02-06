import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';

RotatingFileWriter createRotatingFileWriter({
  required String baseFilePath,
  ChirpFormatter? formatter,
  FileRotationConfig? rotationConfig,
  Encoding encoding = utf8,
  FileWriterErrorHandler? onError,
  FlushStrategy? flushStrategy,
  Duration flushInterval = const Duration(seconds: 1),
}) {
  return RotatingFileWriterIo(
    baseFilePath: baseFilePath,
    formatter: formatter,
    rotationConfig: rotationConfig,
    encoding: encoding,
    onError: onError,
    flushStrategy: flushStrategy,
    flushInterval: flushInterval,
  );
}

/// Returns the default [FlushStrategy] based on the build mode.
///
/// - Debug mode (asserts enabled): [FlushStrategy.synchronous] for immediate logs
/// - Release mode: [FlushStrategy.buffered] for better performance
FlushStrategy _defaultFlushStrategy() {
  var isDebug = false;
  assert(() {
    isDebug = true;
    return true;
  }());
  return isDebug ? FlushStrategy.synchronous : FlushStrategy.buffered;
}

/// Writes log records to files with optional rotation.
///
/// Supports both size-based and time-based rotation, with configurable
/// retention policies (max files, max age).
class RotatingFileWriterIo extends RotatingFileWriter {
  /// Base path for log files.
  ///
  /// This is the path to the current log file. Rotated files are created
  /// in the same directory with timestamps appended to the name.
  @override
  final String baseFilePath;

  /// Formatter for converting log records to text.
  @override
  final ChirpFormatter formatter;

  /// Rotation configuration, or `null` for no rotation.
  @override
  final FileRotationConfig? rotationConfig;

  /// Encoding for writing text to files.
  @override
  final Encoding encoding;

  /// Error handler for write failures.
  ///
  /// Called when a log record cannot be written due to I/O errors.
  /// Defaults to [defaultFileWriterErrorHandler] which prints errors.
  @override
  final FileWriterErrorHandler? onError;

  /// Mode for how file I/O is performed.
  ///
  /// - [FlushStrategy.synchronous]: Immediate synchronous writes
  /// - [FlushStrategy.buffered]: Buffered async writes with periodic flushing
  ///
  /// Defaults to [FlushStrategy.synchronous] in debug mode (asserts enabled) for
  /// immediate log visibility, and [FlushStrategy.buffered] in release mode
  /// for better performance. See [_defaultFlushStrategy].
  @override
  final FlushStrategy flushStrategy;

  /// Interval between automatic buffer flushes in [FlushStrategy.buffered].
  ///
  /// Records are buffered and flushed to disk after this interval.
  /// Shorter intervals reduce data loss risk but increase I/O frequency.
  /// Default is 1 second.
  ///
  /// Note: Error-level logs and above are always written synchronously,
  /// regardless of this interval.
  @override
  final Duration flushInterval;

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

  /// Pending file compression futures.
  /// Tracked so [close] can wait for all compressions to complete.
  final List<Future<void>> _pendingCompressions = [];

  /// Creates a rotating file writer.
  ///
  /// - [baseFilePath]: Path to the log file (e.g., `/var/log/app.log`)
  /// - [formatter]: How to format log records (default: [SimpleFileFormatter])
  /// - [rotationConfig]: Rotation settings, or `null` for no rotation
  /// - [encoding]: Text encoding (default: UTF-8)
  /// - [onError]: Handler for write failures (default: prints to stdout)
  /// - [flushStrategy]: How I/O is performed (default: [_defaultFlushStrategy])
  /// - [flushInterval]: Buffer flush interval for buffered mode (default: 100ms)
  RotatingFileWriterIo({
    required this.baseFilePath,
    ChirpFormatter? formatter,
    this.rotationConfig,
    this.encoding = utf8,
    this.onError,
    FlushStrategy? flushStrategy,
    this.flushInterval = const Duration(seconds: 1),
  })  : flushStrategy = flushStrategy ?? _defaultFlushStrategy(),
        formatter = formatter ?? const SimpleFileFormatter(),
        super.internal();

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
    switch (flushStrategy) {
      case FlushStrategy.synchronous:
        _writeSync(record);
      case FlushStrategy.buffered:
        _writeBuffered(record);
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
      final line = _formatRecord(record);
      final bytes = encoding.encode('$line\n');

      _file!.writeFromSync(bytes);
      _currentFileSize = _currentFileSize + bytes.length;
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, record);
    }
  }

  /// Buffered write implementation - accumulates records and flushes periodically.
  ///
  /// Error-level logs and above are written synchronously to ensure they're
  /// persisted immediately (important for crash debugging). When an error
  /// occurs, any buffered records are flushed first to maintain chronological
  /// order.
  void _writeBuffered(LogRecord record) {
    // Write errors synchronously - they need to be visible immediately,
    // especially if the app is about to crash
    if (record.level.severity >= ChirpLogLevel.error.severity) {
      // Flush buffered records first to maintain chronological order
      _flushBufferSync();
      _writeSync(record);
      return;
    }

    _buffer ??= [];
    _buffer!.add(record);

    // Start one-shot timer on first buffered record.
    // Timer fires after flushInterval, flushes all accumulated records.
    // Next write will start a new timer.
    _flushTimer ??= Timer(flushInterval, _flushBuffer);
  }

  /// Flushes the buffer to disk synchronously.
  ///
  /// Used when an error-level log needs to be written immediately,
  /// ensuring buffered records are written first to maintain order.
  void _flushBufferSync() {
    // Cancel pending timer since we're flushing now
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_buffer == null || _buffer!.isEmpty) return;

    final recordsToFlush = _buffer!;
    _buffer = [];

    for (final record in recordsToFlush) {
      _writeSync(record);
    }
  }

  /// Flushes the buffer to disk asynchronously.
  void _flushBuffer() {
    // Clear timer - it either fired (one-shot) or was cancelled
    _flushTimer = null;

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
        final line = _formatRecord(record);
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

  /// Handles write errors by calling [onError] or the default handler.
  void _handleError(Object error, StackTrace stackTrace, LogRecord? record) {
    final handler = onError ?? defaultFileWriterErrorHandler;
    handler(error, stackTrace, record);
  }

  String _formatRecord(LogRecord record) {
    final buffer = FileMessageBuffer();
    formatter.format(record, MessageBuffer(buffer));
    return buffer.toString();
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

      // Compress if configured (runs in separate isolate, non-blocking)
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

  /// Compresses a file using gzip in a separate isolate.
  ///
  /// Runs compression asynchronously to avoid blocking the main isolate
  /// during large file compression. Errors are reported via [onError].
  void _compressFile(String path) {
    // Capture error handler before async gap to avoid capturing 'this'
    // or any zone-bound objects in the isolate closure.
    final errorHandler = onError ?? defaultFileWriterErrorHandler;
    final future = _compressFileInIsolate(path).then(
      (_) {},
      onError: (Object e, StackTrace stackTrace) {
        errorHandler(e, stackTrace, null);
      },
    );
    _pendingCompressions.add(future);
    future.whenComplete(() => _pendingCompressions.remove(future));
  }

  /// Applies retention policy to remove old log files.
  void _applyRetentionPolicy(LogRecord? record) {
    final config = rotationConfig;
    if (config == null) return;

    final rotatedFiles = _getRotatedFiles();
    if (rotatedFiles.isEmpty) return;

    // Sort by modification time (newest first)
    rotatedFiles.sort((a, b) => b.modified.compareTo(a.modified));

    final now = clock.now();
    final filesToDelete = <_FileEntry>[];

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
        final modified = file.modified;
        if (modified.isBefore(cutoff) && !filesToDelete.contains(file)) {
          filesToDelete.add(file);
        }
      }
    }

    // Delete files
    for (final file in filesToDelete) {
      try {
        File(file.path).deleteSync();
      } catch (e, stackTrace) {
        _handleError(e, stackTrace, record);
      }
    }
  }

  /// Gets all rotated log files (not the current one).
  List<_FileEntry> _getRotatedFiles() {
    final currentFile = File(baseFilePath);
    final dir = currentFile.parent;
    final name = currentFile.uri.pathSegments.last;

    // Extract base name for matching rotated files
    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;

    if (!dir.existsSync()) return [];

    return dir.listSync().whereType<File>().map((file) {
      final stat = file.statSync();
      return (path: file.path, modified: stat.modified);
    }).where((entry) {
      final fileName = File(entry.path).uri.pathSegments.last;
      // Match rotated files: baseName.TIMESTAMP.extension or baseName.TIMESTAMP.extension.gz
      return fileName.startsWith('$baseName.') &&
          fileName != name &&
          (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(fileName) ||
              fileName.endsWith('.gz'));
    }).toList();
  }

  /// Flushes buffered data to disk.
  ///
  /// Call this to ensure all logged data is persisted.
  @override
  Future<void> flush() async {
    switch (flushStrategy) {
      case FlushStrategy.synchronous:
        _file?.flushSync();
      case FlushStrategy.buffered:
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
    }
  }

  /// Closes the file writer and releases resources.
  ///
  /// Always call this when done logging to ensure data is flushed.
  @override
  Future<void> close() async {
    switch (flushStrategy) {
      case FlushStrategy.synchronous:
        _file?.flushSync();
        _file?.closeSync();
        _file = null;
      case FlushStrategy.buffered:
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
    }

    // Wait for any pending compressions to complete
    if (_pendingCompressions.isNotEmpty) {
      await Future.wait(_pendingCompressions);
    }
  }

  /// Forces an immediate rotation regardless of size/time thresholds.
  ///
  /// Useful for log rotation triggered by external events (e.g., SIGHUP).
  @override
  Future<void> forceRotate() async {
    if (_file != null) {
      _rotate(null);
    }
  }
}

/// Runs file compression in a separate isolate.
///
/// Top-level function to avoid capturing any class context or zone-bound
/// objects that can't be sent across isolate boundaries.
Future<void> _compressFileInIsolate(String path) {
  return Isolate.run(() => _compressFileSync(path));
}

/// Compresses a file using gzip synchronously.
///
/// This is a top-level function so it can be passed to [Isolate.run].
void _compressFileSync(String path) {
  final file = File(path);
  if (!file.existsSync()) return;

  final bytes = file.readAsBytesSync();
  final compressed = gzip.encode(bytes);
  File('$path.gz').writeAsBytesSync(compressed);
  file.deleteSync();
}

typedef _FileEntry = ({String path, DateTime modified});
