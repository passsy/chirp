import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const PrintLimitsApp());
}

/// Index for navigation
enum AppPage {
  printLimits('Print Limits'),
  throttling('Throttling');

  const AppPage(this.label);
  final String label;
}

enum PrintMethod {
  print('print()'),
  debugPrint('debugPrintThrottled()'),
  developerLog('developer.log()'),
  stdout('stdout.writeln()');

  const PrintMethod(this.label);
  final String label;
}

/// Generates a string with clear position markers to identify truncation points.
///
/// Format: Every 100 bytes has a marker like `[0100]`, `[0200]`, etc.
/// Between markers: `...XXX...` where XXX is the current byte position.
///
/// Example output:
/// `[0000]...010...020...030...040...050...060...070...080...090...[0100]...110...`
String generateMarkedString(int totalBytes) {
  final buffer = StringBuffer();

  while (buffer.length < totalBytes) {
    final pos = buffer.length;

    // Every 100 bytes, add a prominent marker
    if (pos % 100 == 0) {
      final marker = '[${pos.toString().padLeft(4, '0')}]';
      buffer.write(marker);
    } else if (pos % 10 == 0) {
      // Every 10 bytes, add position number
      final marker = pos.toString().padLeft(3, '0');
      // Only write what fits
      final remaining = 10 - (buffer.length % 10);
      if (remaining >= marker.length) {
        buffer.write(marker);
      } else {
        buffer.write('.' * remaining);
      }
    } else {
      buffer.write('.');
    }
  }

  return buffer.toString().substring(0, totalBytes);
}

/// Alternative: generates a ruler-style string
/// `0         1         2         3         4         5`
/// `0123456789012345678901234567890123456789012345678901234567890`
String generateRulerString(int totalBytes) {
  final buffer = StringBuffer();

  // Line 1: hundreds markers
  for (int i = 0; i < totalBytes; i++) {
    if (i % 100 == 0) {
      buffer.write((i ~/ 100) % 10);
    } else if (i % 10 == 0) {
      buffer.write(' ');
    } else {
      buffer.write(' ');
    }
  }
  buffer.writeln();

  // Line 2: tens markers
  for (int i = 0; i < totalBytes; i++) {
    if (i % 10 == 0) {
      buffer.write((i ~/ 10) % 10);
    } else {
      buffer.write(' ');
    }
  }
  buffer.writeln();

  // Line 3: ones
  for (int i = 0; i < totalBytes; i++) {
    buffer.write(i % 10);
  }

  return buffer.toString();
}

/// Compact version: just shows position every 50 chars
/// `=====[00050]=====...=====[00100]=====...=====[00150]=====`
String generateCompactMarkedString(int totalBytes) {
  final buffer = StringBuffer();

  while (buffer.length < totalBytes) {
    final pos = buffer.length;

    // Every 50 bytes, add a marker
    if (pos % 50 == 0) {
      final marker = '=====[${pos.toString().padLeft(5, '0')}]=====';
      buffer.write(marker);
    } else {
      buffer.write('.');
    }
  }

  return buffer.toString().substring(0, totalBytes);
}

class PrintLimitsApp extends StatefulWidget {
  const PrintLimitsApp({super.key});

  @override
  State<PrintLimitsApp> createState() => _PrintLimitsAppState();
}

class _PrintLimitsAppState extends State<PrintLimitsApp> {
  AppPage _currentPage = AppPage.printLimits;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Print Limits Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        body: switch (_currentPage) {
          AppPage.printLimits => const PrintLimitsPage(),
          AppPage.throttling => const ThrottlingTestPage(),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentPage.index,
          onDestinationSelected: (index) {
            setState(() {
              _currentPage = AppPage.values[index];
            });
          },
          destinations: [
            for (final page in AppPage.values)
              NavigationDestination(
                icon: Icon(
                  page == AppPage.printLimits ? Icons.text_fields : Icons.speed,
                ),
                label: page.label,
              ),
          ],
        ),
      ),
    );
  }
}

class PrintLimitsPage extends StatefulWidget {
  const PrintLimitsPage({super.key});

  @override
  State<PrintLimitsPage> createState() => _PrintLimitsPageState();
}

class _PrintLimitsPageState extends State<PrintLimitsPage> {
  String _lastPrintedInfo = 'Press a button to print';
  PrintMethod _selectedMethod = PrintMethod.print;

  void _doPrint(String message) {
    switch (_selectedMethod) {
      case PrintMethod.print:
        // ignore: avoid_print
        print(message);
      case PrintMethod.debugPrint:
        debugPrintThrottled(message, wrapWidth: 1024);
      case PrintMethod.developerLog:
        developer.log(message, name: 'myapp');
      case PrintMethod.stdout:
        stdout.writeln(message);
    }
  }

  void _printString(int length, String Function(int) generator, String name) {
    final testString = generator(length);
    _doPrint(
      '--- START $name ($length bytes) via ${_selectedMethod.label} ---',
    );
    _doPrint(testString);
    _doPrint('--- END $name ---');

    setState(() {
      _lastPrintedInfo =
          'Printed $name: $length bytes via ${_selectedMethod.label}\n'
          'First 50 chars: ${testString.substring(0, 50.clamp(0, testString.length))}...\n'
          'Last 50 chars: ...${testString.substring((testString.length - 50).clamp(0, testString.length))}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Print Limits Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Console Print Limits',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Each button prints a marked string to the console. '
              'Look for markers like [01024] or =====[01024]===== to see '
              'where truncation occurs.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Print Method:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PrintMethod>(
              segments: [
                for (final method in PrintMethod.values)
                  ButtonSegment(value: method, label: Text(method.label)),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedMethod = selected.first;
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_lastPrintedInfo),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Compact Format:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in [512, 1024, 2048, 4096, 8192, 16384])
                  ElevatedButton(
                    onPressed: () => _printString(
                      size,
                      generateCompactMarkedString,
                      'Compact $size',
                    ),
                    child: Text('$size'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Detailed Format:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in [512, 1024, 2048, 4096, 8192, 16384])
                  ElevatedButton(
                    onPressed: () => _printString(
                      size,
                      generateMarkedString,
                      'Detailed $size',
                    ),
                    child: Text('$size'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Tests:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Print multiple sizes in sequence to find the limit
                for (final size in [900, 1000, 1024, 1100, 1200]) {
                  final s = generateCompactMarkedString(size);
                  _doPrint('[$size bytes] $s');
                }
              },
              child: const Text('Test around 1024'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Print multiple sizes in sequence to find the limit
                for (final size in [3900, 4000, 4096, 4100, 4200]) {
                  final s = generateCompactMarkedString(size);
                  _doPrint('[$size bytes] $s');
                }
              },
              child: const Text('Test around 4096'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Test page for rate limiting - sends bursts of messages to check for
/// Android's "chatty" log collapsing behavior.
///
/// Testing showed no observable rate limiting even when sending 4MB of log
/// data without any throttling on modern Android devices.
class ThrottlingTestPage extends StatefulWidget {
  const ThrottlingTestPage({super.key});

  @override
  State<ThrottlingTestPage> createState() => _ThrottlingTestPageState();
}

class _ThrottlingTestPageState extends State<ThrottlingTestPage> {
  // Message sizes in bytes
  static const _messageSizes = [100, 500, 1000, 2000, 4000];

  // Number of messages to send
  static const _messageCounts = [10, 50, 100, 500, 1000];

  int _selectedMessageSize = 1000;
  int _selectedMessageCount = 100;

  bool _isRunning = false;
  String _status =
      'Ready\n\nWatch logcat for "chatty" messages indicating rate limiting.';

  void _startTest() {
    setState(() {
      _isRunning = true;
      _status = 'Running...';
    });

    final stopwatch = Stopwatch()..start();
    var totalBytes = 0;

    // Send messages using plain print() to test raw Android rate limiting
    for (int i = 0; i < _selectedMessageCount; i++) {
      final message = _generateTestMessage(i, _selectedMessageSize);
      // ignore: avoid_print
      print(message);
      totalBytes += message.length;
    }

    stopwatch.stop();

    setState(() {
      _isRunning = false;
      final elapsed = stopwatch.elapsedMilliseconds;
      final rate = elapsed > 0
          ? totalBytes / (elapsed / 1000)
          : double.infinity;
      _status =
          'Sent $_selectedMessageCount messages ($totalBytes bytes) in ${elapsed}ms\n'
          'Rate: ${(rate / 1024).toStringAsFixed(1)} KB/s\n\n'
          'Check logcat for "chatty" messages. If none appear, rate limiting is not active.';
    });
  }

  String _generateTestMessage(int index, int targetSize) {
    final prefix = '[MSG #${index.toString().padLeft(4, '0')}] ';
    final suffix = ' [END]';
    final fillLength = targetSize - prefix.length - suffix.length;
    if (fillLength <= 0) {
      return prefix.substring(0, targetSize);
    }
    final fill = generateCompactMarkedString(fillLength);
    return '$prefix$fill$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Rate Limit Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Android Rate Limiting',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send bursts of log messages to test if Android\'s logd daemon '
              'triggers "chatty" log collapsing. Testing showed no rate limiting '
              'even with 4MB of data on modern Android devices.',
            ),
            const SizedBox(height: 24),

            // Message size selector
            const Text(
              'Message Size (bytes):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in _messageSizes)
                  ChoiceChip(
                    label: Text('$size'),
                    selected: _selectedMessageSize == size,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedMessageSize = size);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Message count selector
            const Text(
              'Message Count:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in _messageCounts)
                  ChoiceChip(
                    label: Text('$count'),
                    selected: _selectedMessageCount == count,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedMessageCount = count);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Calculated totals
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Total data: ${(_selectedMessageSize * _selectedMessageCount / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _startTest,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Burst Test'),
            ),
            const SizedBox(height: 16),

            // Status
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_status),
              ),
            ),
            const SizedBox(height: 24),

            // Quick tests
            const Text(
              'Quick Tests:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isRunning
                  ? null
                  : () {
                      _selectedMessageSize = 1000;
                      _selectedMessageCount = 100;
                      setState(() {});
                      _startTest();
                    },
              child: const Text('100KB burst (100 × 1KB)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isRunning
                  ? null
                  : () {
                      _selectedMessageSize = 4000;
                      _selectedMessageCount = 1000;
                      setState(() {});
                      _startTest();
                    },
              child: const Text('4MB burst (1000 × 4KB)'),
            ),
          ],
        ),
      ),
    );
  }
}
