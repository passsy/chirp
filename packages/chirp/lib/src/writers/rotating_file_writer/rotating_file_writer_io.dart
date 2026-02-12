import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:chirp/chirp.dart';
import 'package:clock/clock.dart';
import 'package:synchronized/synchronized.dart';

RotatingFileWriter createRotatingFileWriter({
  required FutureOr<String> Function() baseFilePathProvider,
  ChirpFormatter? formatter,
  FileRotationConfig? rotationConfig,
  Encoding encoding = utf8,
  FileWriterErrorHandler? onError,
  FlushStrategy? flushStrategy,
  Duration flushInterval = const Duration(seconds: 1),
}) {
  return RotatingFileWriterIo(
    baseFilePathProvider: baseFilePathProvider,
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
class RotatingFileWriterIo extends ChirpWriter implements RotatingFileWriter {
  String? _baseFilePath;
  final FutureOr<String> Function() _baseFilePathProvider;
  Future<String>? _baseFilePathFuture;

  /// Error from a failed async path resolution.
  ///
  /// When set, every subsequent [write] call throws this error
  /// synchronously so the caller knows the writer is broken.
  (Object, StackTrace)? _baseFilePathError;

  /// Base path for log files.
  ///
  /// This is the path to the current log file. Rotated files are created
  /// in the same directory with timestamps appended to the name.
  ///
  /// Throws [StateError] if the path has not been resolved yet (when using
  /// an async [baseFilePathProvider]).
  @override
  String get baseFilePath {
    final path = _baseFilePath;
    if (path == null) {
      throw StateError(
        'RotatingFileWriter.baseFilePath is not available yet. '
        'If you provided an async baseFilePathProvider, '
        'the path is resolved asynchronously.',
      );
    }
    return path;
  }

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
  final FileWriterErrorHandler? _onError;

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

  @override
  bool get requiresCallerInfo => formatter.requiresCallerInfo;

  @override
  late final RotatingFileReader reader = RotatingFileReader(
    baseFilePathProvider: _baseFilePathProvider,
    recordSeparator: formatter.recordSeparator,
  );

  /// Rotation + file I/O layer. Created when the base path resolves.
  _RotatingFileSink? _sink;

  /// Buffer + coordination layer. Created eagerly, handles both sync and
  /// buffered strategies. Owns the file lock and pending-record queue.
  _RecordBuffer get _recordBuffer {
    return _recordBufferInstance ??= _RecordBuffer(
      flushStrategy: flushStrategy,
      flushInterval: flushInterval,
    );
  }

  _RecordBuffer? _recordBufferInstance;

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
    required FutureOr<String> Function() baseFilePathProvider,
    ChirpFormatter? formatter,
    this.rotationConfig,
    this.encoding = utf8,
    FileWriterErrorHandler? onError,
    FlushStrategy? flushStrategy,
    this.flushInterval = const Duration(seconds: 1),
  })  : _baseFilePath = null,
        _baseFilePathProvider = baseFilePathProvider,
        _onError = onError,
        flushStrategy = flushStrategy ?? _defaultFlushStrategy(),
        formatter = formatter ?? const SimpleFileFormatter();

  /// Creates the sink layer and attaches it to the buffer once the base
  /// path is known. Drains any records that were queued while waiting.
  void _createLayers(String basePath) {
    _sink = _RotatingFileSink(
      basePath: basePath,
      rotationConfig: rotationConfig,
      formatter: formatter,
      encoding: encoding,
      onError: _onError,
    );
    _recordBuffer.attachSink(_sink!);
  }

  /// Tries to resolve the base file path synchronously.
  ///
  /// Returns `null` when the path is already available (or resolution failed).
  /// Returns a callback when async resolution is pending — call it and
  /// `await` the result to wait for the path. This avoids an async gap
  /// on the common sync path.
  Future<void> Function()? _tryResolveBaseFilePathSync() {
    if (_baseFilePath != null) return null;
    if (_baseFilePathFuture != null) return () => _baseFilePathFuture!;

    try {
      final result = _baseFilePathProvider();

      if (result is Future<String>) {
        _baseFilePathFuture = result.then((path) {
          try {
            _validateBaseFilePath(path);
          } catch (e, stackTrace) {
            _baseFilePathError = (e, stackTrace);
            _callOnError(e, stackTrace, null);
            return path;
          }
          _baseFilePath = path;
          _createLayers(path);
          return path;
        }, onError: (Object error, StackTrace stackTrace) {
          _baseFilePathError = (error, stackTrace);
          _callOnError(error, stackTrace, null);
          // Return normally so the future doesn't stay rejected.
          // The stored error is thrown synchronously on every subsequent write.
          return '';
        });
        return () => _baseFilePathFuture!;
      }

      _validateBaseFilePath(result);
      _baseFilePath = result;
      _createLayers(result);
      _baseFilePathFuture = Future<String>.value(result);
      return null;
    } catch (e, stackTrace) {
      _callOnError(e, stackTrace, null);
      return null;
    }
  }

  /// Validates that [path] points to a file, not a directory.
  void _validateBaseFilePath(String path) {
    if (path.endsWith('/') || path.endsWith(r'\')) {
      throw ArgumentError.value(
        path,
        'baseFilePathProvider',
        'must return a file path, not a directory. '
            'Example: "/var/log/app.log" instead of "/var/log/"',
      );
    }
    if (Directory(path).existsSync()) {
      throw ArgumentError.value(
        path,
        'baseFilePathProvider',
        'path "$path" is an existing directory, not a file. '
            'Provide a file path like "${path}app.log"',
      );
    }
  }

  /// Waits for async path resolution if pending.
  ///
  /// Returns `true` if the path is available, `false` if it could not be
  /// resolved (provider not called yet, or resolution failed).
  Future<bool> _waitForBaseFilePath() async {
    final waitForPath = _tryResolveBaseFilePathSync();
    if (waitForPath != null) {
      await waitForPath();
    }
    return _baseFilePath != null;
  }

  /// Like [_waitForBaseFilePath], but throws if the path is not available.
  ///
  /// Use for operations where the caller expects an action to happen
  /// (clearLogs, forceRotate). Throws the stored provider error if one
  /// exists, or a [StateError] if the path simply isn't available.
  Future<void> _ensureBaseFilePath() async {
    if (await _waitForBaseFilePath()) return;

    final pathError = _baseFilePathError;
    if (pathError != null) {
      Error.throwWithStackTrace(pathError.$1, pathError.$2);
    }
    throw StateError(
      'RotatingFileWriter base file path could not be resolved.',
    );
  }

  /// Handles write errors by calling [_onError] or the default handler.
  void _callOnError(Object error, StackTrace stackTrace, LogRecord? record) {
    final handler = _onError ?? defaultFileWriterErrorHandler;
    handler(error, stackTrace, record);
  }

  @override
  void write(LogRecord record) {
    final pathError = _baseFilePathError;
    if (pathError != null) {
      Error.throwWithStackTrace(pathError.$1, pathError.$2);
    }

    // Try to resolve the path so the sink gets attached before the write.
    // If the provider is sync, this resolves immediately and the write
    // proceeds. If async, the record is queued in Layer 2 until the sink
    // is attached.
    if (_baseFilePath == null) {
      _tryResolveBaseFilePathSync();
    }

    _recordBuffer.write(record);
  }

  /// Flushes buffered data to disk.
  ///
  /// Call this to ensure all logged data is persisted.
  @override
  Future<void> flush() async {
    if (!await _waitForBaseFilePath()) return;
    await _sink!.synchronized(() => _recordBuffer.flush());
  }

  /// Closes the file writer and releases resources.
  ///
  /// Always call this when done logging to ensure data is flushed.
  @override
  Future<void> close() async {
    if (!await _waitForBaseFilePath()) return;
    await _sink!.synchronized(() => _recordBuffer.close());
  }

  /// Forces an immediate rotation regardless of size/time thresholds.
  ///
  /// Useful for log rotation triggered by external events (e.g., SIGHUP).
  /// Flushes all buffered records to the current file before rotating so
  /// they end up in the correct (pre-rotation) file.
  @override
  Future<void> forceRotate() {
    // Resolve path synchronously if possible to avoid an async gap
    // before the lock is acquired. This ensures that a synchronous
    // write() after forceRotate() sees the lock as held and queues
    // the record (instead of dispatching it before rotation).
    final waitForPath = _tryResolveBaseFilePathSync();
    if (waitForPath != null) {
      return waitForPath().then((_) {
        if (_baseFilePath == null) {
          final pathError = _baseFilePathError;
          if (pathError != null) {
            Error.throwWithStackTrace(pathError.$1, pathError.$2);
          }
          throw StateError(
            'RotatingFileWriter base file path could not be resolved.',
          );
        }
        return _sink!.synchronized(() async {
          await _recordBuffer.flushForRotation();
          _sink!.forceRotate();
        });
      });
    }

    return _sink!.synchronized(() async {
      await _recordBuffer.flushForRotation();
      _sink!.forceRotate();
    });
  }

  @override
  Future<void> clearLogs() async {
    await _ensureBaseFilePath();
    await _sink!.synchronized(() async {
      // Drop any records that were buffered before the clear.
      _recordBuffer.clearPending();

      // Flush and close the current file handle.
      await _recordBuffer.close();

      // Delete all log files (current + rotated + compressed).
      await _sink!.deleteAllFiles();
    });
  }
}

// ---------------------------------------------------------------------------
// Layer 2 – Record buffering and coordination
// ---------------------------------------------------------------------------

/// Manages record buffering and dispatch to the sink layer.
///
/// Created eagerly (before the sink exists) to hold records while the
/// base path is resolving or the file lock is held. Handles both
/// [FlushStrategy.synchronous] and [FlushStrategy.buffered] modes.
class _RecordBuffer {
  final FlushStrategy _flushStrategy;
  final Duration _flushInterval;

  /// The sink to dispatch records to. `null` until the base path resolves.
  _RotatingFileSink? _sink;

  /// Records queued before the sink is available or while the file lock is held.
  final List<LogRecord> _pendingRecords = [];

  // --- Buffered-mode state (unused in synchronous mode) ---

  /// Buffer for accumulating records in buffered mode.
  List<LogRecord>? _buffer;

  /// Timer for periodic buffer flushing.
  Timer? _flushTimer;

  /// Future that completes when the current async flush operation finishes.
  /// Used to wait for pending writes before close/flush.
  Future<void>? _pendingFlush;

  /// Records that must be written synchronously as soon as [_pendingFlush]
  /// completes. Set when an error-level record arrives while an async flush
  /// is in-flight — we can't call `writeSyncRecords` on a handle that has
  /// a pending async operation, so we defer until it finishes.
  List<LogRecord>? _syncFlushAfterPending;

  _RecordBuffer({
    required FlushStrategy flushStrategy,
    required Duration flushInterval,
  })  : _flushStrategy = flushStrategy,
        _flushInterval = flushInterval;

  /// Sets the sink and drains any queued records.
  void attachSink(_RotatingFileSink sink) {
    _sink = sink;
    _drainPendingRecords();
  }

  /// Clears all queued records (used by clearLogs before closing).
  void clearPending() {
    _pendingRecords.clear();
  }

  /// Accepts a record for writing.
  ///
  /// If the lock is held or no sink is attached yet, the record is queued.
  /// Otherwise, drains any previously queued records and dispatches
  /// everything in chronological order.
  void write(LogRecord record) {
    if (_sink == null || _sink!.locked) {
      _pendingRecords.add(record);
      return;
    }
    final records = [..._pendingRecords, record];
    _pendingRecords.clear();
    _dispatch(records);
  }

  /// Drains pending records, flushes all buffers, and ensures data is on disk.
  Future<void> flush() async {
    _drainPendingRecords();
    switch (_flushStrategy) {
      case FlushStrategy.synchronous:
        _sink!.flushSync();
      case FlushStrategy.buffered:
        _flushTimer?.cancel();
        _flushTimer = null;
        // Wait for any pending async flush to complete
        if (_pendingFlush != null) {
          await _pendingFlush;
        }
        // Flush remaining buffer (includes any just-drained records)
        if (_buffer != null && _buffer!.isNotEmpty) {
          final recordsToFlush = _buffer!;
          _buffer = [];
          await _sink!.writeAsyncRecords(recordsToFlush);
        }
        await _sink!.flushAsync();
    }
  }

  /// Drains pending records, flushes all buffers, closes the sink,
  /// and waits for any pending background compressions.
  Future<void> close() async {
    _drainPendingRecords();
    switch (_flushStrategy) {
      case FlushStrategy.synchronous:
        _sink!.closeSync();
      case FlushStrategy.buffered:
        _flushTimer?.cancel();
        _flushTimer = null;
        // Wait for any pending async flush to complete
        if (_pendingFlush != null) {
          await _pendingFlush;
        }
        // Flush remaining buffer (includes any just-drained records)
        if (_buffer != null && _buffer!.isNotEmpty) {
          final recordsToFlush = _buffer!;
          _buffer = [];
          await _sink!.writeAsyncRecords(recordsToFlush);
        }
        await _sink!.closeAsync();
    }
    await _sink!.waitForCompressions();
  }

  /// Flushes all records synchronously before a rotation.
  ///
  /// Waits for any pending async flush, then writes remaining records
  /// synchronously so they end up in the pre-rotation file.
  Future<void> flushForRotation() async {
    switch (_flushStrategy) {
      case FlushStrategy.synchronous:
        _drainPendingRecords();
      case FlushStrategy.buffered:
        // Wait for in-flight async flush to complete so we don't close
        // _file while writeAsyncRecords is writing to it.
        if (_pendingFlush != null) {
          await _pendingFlush;
        }
        _flushTimer?.cancel();
        _flushTimer = null;
        _drainPendingRecords();
        if (_buffer != null && _buffer!.isNotEmpty) {
          final recordsToFlush = _buffer!;
          _buffer = [];
          _sink!.writeSyncRecords(recordsToFlush);
        }
    }
  }

  // -- Private helpers -------------------------------------------------------

  /// Dispatches records based on the flush strategy.
  void _dispatch(List<LogRecord> records) {
    switch (_flushStrategy) {
      case FlushStrategy.synchronous:
        _sink!.writeSyncRecords(records);
      case FlushStrategy.buffered:
        _dispatchBuffered(records);
    }
  }

  /// Writes all records that were queued while the sink was unavailable
  /// or the lock was held.
  void _drainPendingRecords() {
    if (_pendingRecords.isEmpty) return;

    final records = List<LogRecord>.from(_pendingRecords);
    _pendingRecords.clear();
    _dispatch(records);
  }

  /// Buffered dispatch — accumulates records and flushes at error boundaries.
  ///
  /// Error-level logs and above are written synchronously to ensure they're
  /// persisted immediately (important for crash debugging). When an error
  /// record is encountered, all previously buffered records plus everything
  /// up to and including the error are flushed in a single sync write,
  /// minimizing the number of flushes.
  ///
  /// If an async flush is in-flight ([_pendingFlush] is set), the sync
  /// batch is deferred to [_syncFlushAfterPending] because Dart's
  /// [RandomAccessFile] does not allow sync writes while an async operation
  /// is pending on the same handle.
  void _dispatchBuffered(List<LogRecord> records) {
    for (final record in records) {
      if (record.level.severity >= ChirpLogLevel.error.severity) {
        // Collect buffer + current record into one sync batch.
        // Continue scanning — more errors may follow.
        _buffer ??= [];
        _buffer!.add(record);
        continue;
      }

      // Non-error record: if we accumulated an error batch, flush it first.
      if (_buffer != null && _buffer!.isNotEmpty &&
          _buffer!.last.level.severity >= ChirpLogLevel.error.severity) {
        _syncFlushBuffer();
      }

      _buffer ??= [];
      _buffer!.add(record);
    }

    // If the last record(s) were errors, flush immediately.
    if (_buffer != null && _buffer!.isNotEmpty &&
        _buffer!.last.level.severity >= ChirpLogLevel.error.severity) {
      _syncFlushBuffer();
      return;
    }

    // Only non-error records remain in the buffer — start the flush timer.
    if (_buffer != null && _buffer!.isNotEmpty) {
      _flushTimer ??= Timer(_flushInterval, _flushBuffer);
    }
  }

  /// Writes all buffered records synchronously.
  ///
  /// If an async flush is in-flight, defers the batch to
  /// [_syncFlushAfterPending] which is drained as soon as the async
  /// flush completes.
  void _syncFlushBuffer() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final batch = _buffer!;
    _buffer = [];

    if (_pendingFlush != null) {
      // Can't write sync while async I/O is pending on the same handle.
      // Defer until the async flush completes.
      _syncFlushAfterPending ??= [];
      _syncFlushAfterPending!.addAll(batch);
      return;
    }

    _sink!.writeSyncRecords(batch);
  }

  /// Flushes the buffer to disk asynchronously.
  void _flushBuffer() {
    // Clear timer - it either fired (one-shot) or was cancelled
    _flushTimer = null;

    if (_pendingFlush != null || _buffer == null || _buffer!.isEmpty) return;

    final recordsToFlush = _buffer!;
    _buffer = [];

    // Run async I/O without blocking the caller
    _pendingFlush = _sink!.writeAsyncRecords(recordsToFlush).whenComplete(() {
      _pendingFlush = null;

      // Drain error records that were deferred because the async flush was
      // in-flight. Write them synchronously now that the handle is free.
      final deferred = _syncFlushAfterPending;
      if (deferred != null && deferred.isNotEmpty) {
        _syncFlushAfterPending = null;
        _sink!.writeSyncRecords(deferred);
      }

      // Restart timer if new records arrived during the async flush.
      // Without this, records sit in _buffer indefinitely because the
      // one-shot timer already fired and no new timer was started.
      if (_buffer != null && _buffer!.isNotEmpty && _flushTimer == null) {
        _flushTimer = Timer(_flushInterval, _flushBuffer);
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Layer 3 – File I/O, rotation, formatting, compression, retention
// ---------------------------------------------------------------------------

/// Handles rotation, formatting, compression, retention, and file I/O.
///
/// Owns the [RandomAccessFile] handle directly. Detects externally-deleted
/// files and reopens automatically.
///
/// Owns the [_fileLock] that serializes file operations (appending, rotation,
/// deletion). Callers use [synchronized] for exclusive access and check
/// [locked] to avoid blocking on the sync write path.
class _RotatingFileSink {
  final String basePath;
  final FileRotationConfig? rotationConfig;
  final ChirpFormatter formatter;
  final Encoding encoding;
  final FileWriterErrorHandler? onError;

  /// Lock to serialize file operations (appending, rotation, deletion).
  final Lock _fileLock = Lock();

  /// The open file handle, or `null` when closed.
  RandomAccessFile? _file;

  /// Current file size in bytes (tracked for size-based rotation).
  int _currentFileSize = 0;

  /// Timestamp of the last rotation check (for time-based rotation).
  DateTime? _lastRotationCheck;

  /// Pending file compression futures.
  /// Tracked so [close] can wait for all compressions to complete.
  final List<Future<void>> _pendingCompressions = [];

  /// `true` while [writeAsyncRecords] is executing. Prevents
  /// [writeSyncRecords] from rotating (which would close the file handle
  /// that the async write is using).
  bool _asyncWriteInProgress = false;

  _RotatingFileSink({
    required this.basePath,
    required this.rotationConfig,
    required this.formatter,
    required this.encoding,
    required this.onError,
  });

  /// Whether the file lock is currently held.
  bool get locked => _fileLock.locked;

  /// Runs [fn] while holding the file lock.
  Future<T> synchronized<T>(Future<T> Function() fn) {
    return _fileLock.synchronized(fn);
  }

  /// Opens the file for appending if needed, creating parent directories
  /// if they don't exist.
  ///
  /// If the file was deleted externally, closes the stale handle and reopens.
  /// Syncs [_currentFileSize] on (re)open so size-based rotation works
  /// correctly when appending to an existing file.
  void _ensureOpen() {
    if (_file != null) {
      // Check if the underlying file was deleted externally.
      // On Unix, the file descriptor remains valid after unlink but writes
      // go to the orphaned inode — data is silently lost. Detect this and
      // reopen so future writes land on a new file at the expected path.
      if (File(basePath).existsSync()) {
        return;
      }
      try {
        _file!.closeSync();
      } catch (_) {
        // Ignore errors closing a stale handle
      }
      _file = null;
    }

    final file = File(basePath);

    // Create parent directories if they don't exist
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    _currentFileSize = file.existsSync() ? file.lengthSync() : 0;
    _file = file.openSync(mode: FileMode.append);
  }

  /// Synchronous write implementation.
  ///
  /// Writes all [records] to disk and flushes once at the end, avoiding
  /// redundant `fsync` syscalls when writing multiple records.
  void writeSyncRecords(List<LogRecord> records) {
    try {
      _ensureOpen();

      for (final record in records) {
        // Initialize last rotation check on first write using record's
        // timestamp. This ensures time-based rotation works correctly
        // regardless of wall clock.
        _lastRotationCheck ??= record.timestamp;

        // Check if rotation is needed before writing.
        // Rotation flushes and reopens the file internally.
        // Skip rotation when an async flush is in progress to avoid
        // closing _file while writeAsyncRecords is writing to it.
        if (rotationConfig != null && !_asyncWriteInProgress) {
          _checkRotation(record);
        }

        // Format and write the record
        final line = _formatRecord(record);
        final bytes = encoding.encode('$line${formatter.recordSeparator}');

        _file!.writeFromSync(bytes);
        _currentFileSize = _currentFileSize + bytes.length;
      }

      _file?.flushSync();
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, records.lastOrNull);
    }
  }

  /// Async write implementation.
  ///
  /// Formats records into byte batches and writes them asynchronously.
  /// When rotation occurs mid-batch, the accumulated pre-rotation bytes are
  /// flushed to the current file before rotating so they don't end up in
  /// the wrong file.
  Future<void> writeAsyncRecords(List<LogRecord> records) async {
    _asyncWriteInProgress = true;
    try {
      _ensureOpen();

      final batch = BytesBuilder(copy: false);

      for (final record in records) {
        // Initialize last rotation check on first write
        _lastRotationCheck ??= record.timestamp;

        // Flush the pre-rotation batch before rotating so records land in
        // the correct file.
        if (_needsRotation(record)) {
          if (batch.isNotEmpty) {
            await _file!.writeFrom(batch.takeBytes());
            await _file?.flush();
          }
          _rotate(record);
        }

        // Format and write the record
        final line = _formatRecord(record);
        final bytes = encoding.encode('$line${formatter.recordSeparator}');
        batch.add(bytes);
        _currentFileSize = _currentFileSize + bytes.length;
      }

      if (batch.isNotEmpty) {
        await _file!.writeFrom(batch.takeBytes());
        await _file?.flush();
      }
    } catch (e, stackTrace) {
      // Report error for the batch (no specific record)
      _handleError(e, stackTrace, null);
    } finally {
      _asyncWriteInProgress = false;
    }
  }

  void flushSync() {
    _file?.flushSync();
  }

  Future<void> flushAsync() async {
    await _file?.flush();
  }

  void closeSync() {
    _file?.flushSync();
    _file?.closeSync();
    _file = null;
  }

  Future<void> closeAsync() async {
    await _file?.flush();
    await _file?.close();
    _file = null;
  }

  /// Forces an immediate rotation regardless of size/time thresholds.
  void forceRotate() {
    if (_file != null) {
      _rotate(null);
    }
  }

  /// Waits for all pending background compressions to complete.
  Future<void> waitForCompressions() async {
    if (_pendingCompressions.isNotEmpty) {
      await Future.wait(List.of(_pendingCompressions));
    }
  }

  /// Deletes the current log file and all rotated files.
  ///
  /// Waits for pending compressions first so .gz files exist on disk
  /// before deletion.
  Future<void> deleteAllFiles() async {
    await waitForCompressions();

    final currentFile = File(basePath);
    if (currentFile.existsSync()) {
      currentFile.deleteSync();
    }

    for (final entry in getRotatedFiles()) {
      try {
        File(entry.path).deleteSync();
      } catch (e, stackTrace) {
        _handleError(e, stackTrace, null);
      }
    }
  }

  /// Gets all rotated log files (not the current one).
  List<_FileEntry> getRotatedFiles() {
    final currentFile = File(basePath);
    final dir = currentFile.parent;
    final name = currentFile.uri.pathSegments.last;

    // Extract base name for matching rotated files
    final dotIndex = name.lastIndexOf('.');
    final baseName = dotIndex > 0 ? name.substring(0, dotIndex) : name;

    if (!dir.existsSync()) return [];

    return dir.listSync().whereType<File>().where((file) {
      final fileName = file.uri.pathSegments.last;
      return fileName != name && isRotatedLogFile(fileName, baseName: baseName);
    }).map((file) {
      final stat = file.statSync();
      return (path: file.path, modified: stat.modified);
    }).toList();
  }

  // -- Private helpers -------------------------------------------------------

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

  /// Returns `true` when the current file should be rotated before writing
  /// [record], based on size and/or time thresholds.
  bool _needsRotation(LogRecord record) {
    final config = rotationConfig;
    if (config == null) return false;

    final timestamp = record.timestamp;

    // Check size-based rotation
    if (config.maxFileSize != null && _currentFileSize >= config.maxFileSize!) {
      return true;
    }

    // Check time-based rotation
    if (config.rotationInterval != null && _lastRotationCheck != null) {
      return _shouldRotateByTime(timestamp, config.rotationInterval!);
    }

    return false;
  }

  /// Checks if rotation is needed and performs it if so.
  void _checkRotation(LogRecord record) {
    if (_needsRotation(record)) {
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

    // Flush and close current file
    _file?.flushSync();
    _file?.closeSync();
    _file = null;

    // Generate rotated filename using the last rotation timestamp
    // (the file contains logs from the previous period)
    final rotatedPath = _generateRotatedPath(_lastRotationCheck ?? timestamp);
    final currentFile = File(basePath);

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
    final file = File(basePath);
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

    final rotatedFiles = getRotatedFiles();
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
}

// ---------------------------------------------------------------------------
// Top-level helpers
// ---------------------------------------------------------------------------

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
  File('$path.gz').writeAsBytesSync(compressed, flush: true);
  file.deleteSync();
}

typedef _FileEntry = ({String path, DateTime modified});

// Matches baseName.YYYY-MM-DD_HH-MM-SS[_N].ext[.gz] after stripping
// the "baseName." prefix.
final _rotatedTimestampPattern =
    RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}(_\d+)?');

/// Returns `true` if [fileName] (without directory path) matches the
/// rotation pattern for [baseName] (without extension).
///
/// ```dart
/// isRotatedLogFile('app.2024-01-15_10-30-45.log', baseName: 'app') // true
/// isRotatedLogFile('app.log', baseName: 'app') // false
/// ```
bool isRotatedLogFile(String fileName, {required String baseName}) {
  if (!fileName.startsWith('$baseName.')) return false;
  final rest = fileName.substring(baseName.length + 1); // skip "baseName."
  return _rotatedTimestampPattern.hasMatch(rest);
}
