/// Benchmark: Comparing file write modes for frame drop impact.
///
/// This benchmark simulates a 120Hz animation loop and measures how many
/// frames are dropped due to logging overhead with different write modes:
/// - sync: Immediate synchronous writes (blocks on every write)
/// - buffered: Buffered async writes with periodic flushing
/// - isolate: Dedicated background isolate for all I/O
///
/// Run with: dart run examples/simple/bin/file_writer_benchmark.dart
import 'dart:io';
import 'dart:math';

import 'package:chirp/chirp.dart';

/// Number of benchmark iterations per mode for statistical significance.
const int iterations = 5;

/// Number of frames per iteration (2.5 seconds at 120Hz).
const int framesPerIteration = 300;

/// Number of log calls per frame.
const int logsPerFrame = 1000;

/// Target frame time for 120Hz.
const Duration frameBudget = Duration(microseconds: 8333);

/// Simulated work time per frame (layout, paint, etc.).
const Duration workDuration = Duration(milliseconds: 4);

/// Cooldown between tests to let OS flush buffers.
const Duration cooldownBetweenTests = Duration(seconds: 2);

Future<void> main() async {
  print('=' * 70);
  print('BENCHMARK: File Write Mode Frame Drop Comparison');
  print('=' * 70);
  print('');
  print('Configuration:');
  print('  Frame rate:      120Hz (${frameBudget.inMicroseconds}µs budget)');
  print('  Work per frame:  ${workDuration.inMilliseconds}ms CPU work');
  print('  Logs per frame:  $logsPerFrame');
  print('  Frames/iter:     $framesPerIteration');
  print('  Iterations:      $iterations per mode');
  print('');

  // Randomize test order to avoid ordering bias
  final modes = List<FileWriteMode>.from(FileWriteMode.values)
    ..shuffle(Random());
  print('Test order (randomized): ${modes.map((m) => m.name).join(' -> ')}');
  print('');

  // Warmup with realistic parameters
  print('Warming up (matching test parameters)...');
  await _runWarmup();
  print('');

  final allResults = <FileWriteMode, List<IterationResult>>{};

  for (final mode in modes) {
    print('-' * 70);
    print('Testing: ${mode.name.toUpperCase()}');
    print('-' * 70);

    allResults[mode] = [];

    for (var i = 0; i < iterations; i++) {
      // Force GC before each iteration
      _forceGC();

      final result = await runIteration(
        mode: mode,
        iteration: i + 1,
      );
      allResults[mode]!.add(result);

      // Brief cooldown between iterations
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // Cooldown between modes to let OS flush disk buffers
    if (mode != modes.last) {
      print('  Cooldown ${cooldownBetweenTests.inSeconds}s...');
      await Future<void>.delayed(cooldownBetweenTests);
    }
    print('');
  }

  // Print detailed summary
  _printSummary(allResults);
}

Future<void> _runWarmup() async {
  final tempDir = Directory.systemTemp.createTempSync('chirp_warmup_');
  try {
    for (final mode in FileWriteMode.values) {
      final writer = RotatingFileWriter(
        baseFilePath: '${tempDir.path}/warmup_${mode.name}.log',
        writeMode: mode,
        flushInterval: const Duration(milliseconds: 100),
        maxBufferSize: 1000,
      );
      final logger = ChirpLogger(name: 'Warmup').addWriter(writer);

      // Run warmup with same parameters as real test
      for (var frame = 0; frame < 50; frame++) {
        _doWork(workDuration);
        for (var log = 0; log < logsPerFrame; log++) {
          logger.info('Warmup frame $frame log $log');
        }
      }

      await writer.flush();
      await writer.close();
    }
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

/// Attempts to trigger garbage collection.
void _forceGC() {
  // Allocate and discard memory to encourage GC
  final garbage = List.generate(1000000, (i) => 'garbage_$i');
  garbage.clear();
}

Future<IterationResult> runIteration({
  required FileWriteMode mode,
  required int iteration,
}) async {
  // Use separate directory per iteration to avoid disk interference
  final tempDir = Directory.systemTemp
      .createTempSync('chirp_bench_${mode.name}_${iteration}_');

  try {
    final logPath = '${tempDir.path}/benchmark.log';

    final writer = RotatingFileWriter(
      baseFilePath: logPath,
      writeMode: mode,
      flushInterval: const Duration(milliseconds: 100),
      maxBufferSize: 1000,
    );

    final logger = ChirpLogger(name: 'Benchmark').addWriter(writer);

    final frameTimes = <int>[]; // in microseconds
    var droppedFrames = 0;
    var totalOverbudgetMicros = 0;

    final totalStopwatch = Stopwatch()..start();
    final frameStopwatch = Stopwatch();

    for (var frame = 0; frame < framesPerIteration; frame++) {
      frameStopwatch
        ..reset()
        ..start();

      // Actual CPU work (widget builds, layout, paint, etc.)
      _doWork(workDuration);

      // Heavy logging during frame
      for (var log = 0; log < logsPerFrame; log++) {
        logger.info(
          'Frame $frame log $log - Processing animation update with additional context data',
          data: {
            'frame': frame,
            'log': log,
            'iteration': iteration,
            'metadata': {'key1': 'value1', 'key2': 'value2'},
          },
        );
      }

      frameStopwatch.stop();
      final frameTimeMicros = frameStopwatch.elapsedMicroseconds;
      frameTimes.add(frameTimeMicros);

      if (frameTimeMicros > frameBudget.inMicroseconds) {
        droppedFrames++;
        totalOverbudgetMicros += frameTimeMicros - frameBudget.inMicroseconds;
      }

      // Wait for next frame (if we have time remaining)
      final remainingMicros = frameBudget.inMicroseconds - frameTimeMicros;
      if (remainingMicros > 0) {
        await Future<void>.delayed(Duration(microseconds: remainingMicros));
      }
    }

    totalStopwatch.stop();

    // Flush and close
    await writer.flush();
    await writer.close();

    // Calculate statistics
    frameTimes.sort();
    final stats = FrameTimeStats(
      min: frameTimes.first,
      max: frameTimes.last,
      mean: frameTimes.reduce((a, b) => a + b) / frameTimes.length,
      p50: _percentile(frameTimes, 50),
      p95: _percentile(frameTimes, 95),
      p99: _percentile(frameTimes, 99),
      stdDev: _standardDeviation(frameTimes),
    );

    // Get file stats
    final file = File(logPath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    final result = IterationResult(
      iteration: iteration,
      droppedFrames: droppedFrames,
      totalFrames: framesPerIteration,
      totalOverbudgetMicros: totalOverbudgetMicros,
      totalTime: totalStopwatch.elapsed,
      frameTimeStats: stats,
      fileSizeBytes: fileSize,
    );

    // Print iteration result
    final dropPct =
        (droppedFrames / framesPerIteration * 100).toStringAsFixed(1);
    final avgOverbudget = droppedFrames > 0
        ? (totalOverbudgetMicros / droppedFrames / 1000).toStringAsFixed(2)
        : '0.00';
    print('  [$iteration/$iterations] Dropped: $droppedFrames ($dropPct%), '
        'p50: ${(stats.p50 / 1000).toStringAsFixed(2)}ms, '
        'p99: ${(stats.p99 / 1000).toStringAsFixed(2)}ms, '
        'avg overbudget: ${avgOverbudget}ms');

    return result;
  } finally {
    // Cleanup
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

int _percentile(List<int> sorted, int percentile) {
  final index = ((percentile / 100) * (sorted.length - 1)).round();
  return sorted[index];
}

double _standardDeviation(List<int> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
  final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
  return sqrt(variance);
}

/// Does actual CPU work for approximately [duration].
void _doWork(Duration duration) {
  final stopwatch = Stopwatch()..start();
  var n = 0;
  while (stopwatch.elapsed < duration) {
    // Calculate factorial iteratively (CPU-bound work)
    _factorial(100 + (n % 50));
    n++;
  }
}

/// Calculates factorial of [n] iteratively.
BigInt _factorial(int n) {
  var result = BigInt.one;
  for (var i = 2; i <= n; i++) {
    result *= BigInt.from(i);
  }
  return result;
}

void _printSummary(Map<FileWriteMode, List<IterationResult>> allResults) {
  print('=' * 70);
  print('RESULTS SUMMARY (across $iterations iterations)');
  print('=' * 70);
  print('');

  // Calculate aggregated stats per mode
  final summaries = <FileWriteMode, ModeSummary>{};
  for (final entry in allResults.entries) {
    summaries[entry.key] = ModeSummary.fromResults(entry.value);
  }

  // Print drop rate comparison
  print('FRAME DROPS:');
  print(
      '${'Mode'.padRight(10)} | ${'Mean'.padLeft(8)} | ${'StdDev'.padLeft(8)} | '
      '${'Min'.padLeft(8)} | ${'Max'.padLeft(8)}');
  print('-' * 52);
  for (final mode in FileWriteMode.values) {
    final s = summaries[mode]!;
    print('${mode.name.padRight(10)} | '
        '${s.dropRateMean.toStringAsFixed(1).padLeft(7)}% | '
        '${s.dropRateStdDev.toStringAsFixed(1).padLeft(7)}% | '
        '${s.dropRateMin.toStringAsFixed(1).padLeft(7)}% | '
        '${s.dropRateMax.toStringAsFixed(1).padLeft(7)}%');
  }
  print('');

  // Print frame time percentiles
  print('FRAME TIMES (milliseconds):');
  print('${'Mode'.padRight(10)} | ${'p50'.padLeft(8)} | ${'p95'.padLeft(8)} | '
      '${'p99'.padLeft(8)} | ${'Max'.padLeft(8)}');
  print('-' * 52);
  for (final mode in FileWriteMode.values) {
    final s = summaries[mode]!;
    print('${mode.name.padRight(10)} | '
        '${(s.p50Mean / 1000).toStringAsFixed(2).padLeft(8)} | '
        '${(s.p95Mean / 1000).toStringAsFixed(2).padLeft(8)} | '
        '${(s.p99Mean / 1000).toStringAsFixed(2).padLeft(8)} | '
        '${(s.maxMean / 1000).toStringAsFixed(2).padLeft(8)}');
  }
  print('');

  // Print overbudget severity
  print('OVERBUDGET SEVERITY (avg ms over budget when dropped):');
  print(
      '${'Mode'.padRight(10)} | ${'Mean'.padLeft(10)} | ${'Max'.padLeft(10)}');
  print('-' * 36);
  for (final mode in FileWriteMode.values) {
    final s = summaries[mode]!;
    print('${mode.name.padRight(10)} | '
        '${s.avgOverbudgetMean.toStringAsFixed(2).padLeft(9)}ms | '
        '${s.avgOverbudgetMax.toStringAsFixed(2).padLeft(9)}ms');
  }
  print('');

  // Print comparison vs sync
  final syncSummary = summaries[FileWriteMode.sync]!;
  print('IMPROVEMENT vs SYNC:');
  print(
      '${'Mode'.padRight(10)} | ${'Drop Rate'.padLeft(12)} | ${'p99 Time'.padLeft(12)}');
  print('-' * 40);
  for (final mode in FileWriteMode.values) {
    final s = summaries[mode]!;
    if (mode == FileWriteMode.sync) {
      print('${mode.name.padRight(10)} | ${'(baseline)'.padLeft(12)} | '
          '${'(baseline)'.padLeft(12)}');
    } else {
      final dropImprovement = s.dropRateMean > 0 && syncSummary.dropRateMean > 0
          ? '${(syncSummary.dropRateMean / s.dropRateMean).toStringAsFixed(1)}x better'
          : 'N/A';
      final p99Diff = syncSummary.p99Mean - s.p99Mean;
      final p99Improvement = p99Diff > 0
          ? '${(p99Diff / 1000).toStringAsFixed(2)}ms faster'
          : '${(-p99Diff / 1000).toStringAsFixed(2)}ms slower';
      print('${mode.name.padRight(10)} | ${dropImprovement.padLeft(12)} | '
          '${p99Improvement.padLeft(12)}');
    }
  }
  print('');
  print('Lower is better for all metrics.');
}

class IterationResult {
  final int iteration;
  final int droppedFrames;
  final int totalFrames;
  final int totalOverbudgetMicros;
  final Duration totalTime;
  final FrameTimeStats frameTimeStats;
  final int fileSizeBytes;

  double get dropRate => droppedFrames / totalFrames * 100;
  double get avgOverbudgetMs =>
      droppedFrames > 0 ? totalOverbudgetMicros / droppedFrames / 1000 : 0;

  IterationResult({
    required this.iteration,
    required this.droppedFrames,
    required this.totalFrames,
    required this.totalOverbudgetMicros,
    required this.totalTime,
    required this.frameTimeStats,
    required this.fileSizeBytes,
  });
}

class FrameTimeStats {
  final int min;
  final int max;
  final double mean;
  final int p50;
  final int p95;
  final int p99;
  final double stdDev;

  FrameTimeStats({
    required this.min,
    required this.max,
    required this.mean,
    required this.p50,
    required this.p95,
    required this.p99,
    required this.stdDev,
  });
}

class ModeSummary {
  final double dropRateMean;
  final double dropRateStdDev;
  final double dropRateMin;
  final double dropRateMax;
  final double p50Mean;
  final double p95Mean;
  final double p99Mean;
  final double maxMean;
  final double avgOverbudgetMean;
  final double avgOverbudgetMax;

  ModeSummary({
    required this.dropRateMean,
    required this.dropRateStdDev,
    required this.dropRateMin,
    required this.dropRateMax,
    required this.p50Mean,
    required this.p95Mean,
    required this.p99Mean,
    required this.maxMean,
    required this.avgOverbudgetMean,
    required this.avgOverbudgetMax,
  });

  factory ModeSummary.fromResults(List<IterationResult> results) {
    final dropRates = results.map((r) => r.dropRate).toList();
    final p50s = results.map((r) => r.frameTimeStats.p50.toDouble()).toList();
    final p95s = results.map((r) => r.frameTimeStats.p95.toDouble()).toList();
    final p99s = results.map((r) => r.frameTimeStats.p99.toDouble()).toList();
    final maxes = results.map((r) => r.frameTimeStats.max.toDouble()).toList();
    final overbudgets = results.map((r) => r.avgOverbudgetMs).toList();

    return ModeSummary(
      dropRateMean: _mean(dropRates),
      dropRateStdDev: _stdDev(dropRates),
      dropRateMin: dropRates.reduce(min),
      dropRateMax: dropRates.reduce(max),
      p50Mean: _mean(p50s),
      p95Mean: _mean(p95s),
      p99Mean: _mean(p99s),
      maxMean: _mean(maxes),
      avgOverbudgetMean: _mean(overbudgets),
      avgOverbudgetMax: overbudgets.reduce(max),
    );
  }

  static double _mean(List<double> values) {
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _stdDev(List<double> values) {
    final m = _mean(values);
    final squaredDiffs = values.map((v) => (v - m) * (v - m));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }
}
