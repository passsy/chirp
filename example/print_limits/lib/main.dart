import 'dart:developer' as developer;
import 'dart:io';

import 'package:chirp/chirp.dart';
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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
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
                icon: Icon(page == AppPage.printLimits ? Icons.text_fields : Icons.speed),
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
    _doPrint('--- START $name ($length bytes) via ${_selectedMethod.label} ---');
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
            const Text('Test Console Print Limits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Each button prints a marked string to the console. '
              'Look for markers like [01024] or =====[01024]===== to see '
              'where truncation occurs.',
            ),
            const SizedBox(height: 16),
            const Text('Print Method:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<PrintMethod>(
              segments: [
                for (final method in PrintMethod.values) ButtonSegment(value: method, label: Text(method.label)),
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
              child: Padding(padding: const EdgeInsets.all(12), child: Text(_lastPrintedInfo)),
            ),
            const SizedBox(height: 24),
            const Text('Compact Format:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in [512, 1024, 2048, 4096, 8192, 16384])
                  ElevatedButton(
                    onPressed: () => _printString(size, generateCompactMarkedString, 'Compact $size'),
                    child: Text('$size'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Detailed Format:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in [512, 1024, 2048, 4096, 8192, 16384])
                  ElevatedButton(
                    onPressed: () => _printString(size, generateMarkedString, 'Detailed $size'),
                    child: Text('$size'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Quick Tests:', style: TextStyle(fontWeight: FontWeight.bold)),
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

/// Test page for throttling with different KB/s rates and message sizes
class ThrottlingTestPage extends StatefulWidget {
  const ThrottlingTestPage({super.key});

  @override
  State<ThrottlingTestPage> createState() => _ThrottlingTestPageState();
}

class _ThrottlingTestPageState extends State<ThrottlingTestPage> {
  // Throttle rates in KB/s
  static const _throttleRates = [null, 4, 8, 12, 16, 24, 48];

  // Message sizes in bytes
  static const _messageSizes = [100, 500, 1000, 2000, 4000];

  // Number of messages to send
  static const _messageCounts = [10, 50, 100, 500];

  int? _selectedThrottleRate = 12; // KB/s, null = no throttling
  int _selectedMessageSize = 500;
  int _selectedMessageCount = 100;

  PrintConsoleWriter? _writer;
  bool _isRunning = false;
  int _messagesSent = 0;
  int _totalBytes = 0;
  Stopwatch? _stopwatch;
  String _status = 'Ready';

  @override
  void dispose() {
    _writer?.dispose();
    super.dispose();
  }

  void _startTest() {
    _writer?.dispose();

    final throttleRate = _selectedThrottleRate;
    _writer = PrintConsoleWriter(
      maxChunkLength: null, // No chunking for this test
      maxBytesPerSecond: throttleRate != null ? throttleRate * 1024 : null,
      useColors: false,
    );

    setState(() {
      _isRunning = true;
      _messagesSent = 0;
      _totalBytes = 0;
      _status = 'Running...';
    });

    _stopwatch = Stopwatch()..start();

    // Send messages
    for (int i = 0; i < _selectedMessageCount; i++) {
      final message = _generateTestMessage(i, _selectedMessageSize);
      _writer!.write(LogRecord(
        message: message,
        level: ChirpLogLevel.info,
        date: DateTime.now(),
      ));
      _messagesSent++;
      _totalBytes += message.length;
    }

    _stopwatch!.stop();

    setState(() {
      _isRunning = false;
      final elapsed = _stopwatch!.elapsedMilliseconds;
      final rate = _totalBytes / (elapsed / 1000);
      _status = 'Sent $_messagesSent messages ($_totalBytes bytes) in ${elapsed}ms\n'
          'Effective rate: ${(rate / 1024).toStringAsFixed(1)} KB/s\n'
          'Throttle: ${throttleRate != null ? "$throttleRate KB/s" : "disabled"}';
    });
  }

  void _stopAndFlush() {
    _writer?.dispose();
    _writer = null;
    setState(() {
      _status = 'Flushed and disposed';
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
        title: const Text('Throttling Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Throttling',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure throttle rate, message size, and count to test '
              'how PrintConsoleWriter handles rate limiting. Watch logcat '
              'for dropped or "chatty" messages.',
            ),
            const SizedBox(height: 24),

            // Throttle rate selector
            const Text('Throttle Rate (KB/s):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rate in _throttleRates)
                  ChoiceChip(
                    label: Text(rate == null ? 'Off' : '$rate'),
                    selected: _selectedThrottleRate == rate,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedThrottleRate = rate);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Message size selector
            const Text('Message Size (bytes):', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Message Count:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total data: ${(_selectedMessageSize * _selectedMessageCount / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedThrottleRate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expected time: ${(_selectedMessageSize * _selectedMessageCount / (_selectedThrottleRate! * 1024)).toStringAsFixed(1)}s',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _startTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Test'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopAndFlush,
                    icon: const Icon(Icons.stop),
                    label: const Text('Flush & Stop'),
                  ),
                ),
              ],
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
            const Text('Quick Tests:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Burst test: send 100KB as fast as possible with no throttle
                _selectedThrottleRate = null;
                _selectedMessageSize = 4000;
                _selectedMessageCount = 1000;
                setState(() {});
                _startTest();
              },
              child: const Text('Burst: 4000KB no throttle'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Throttled test: send 100KB at 12KB/s
                _selectedThrottleRate = 12;
                _selectedMessageSize = 1000;
                _selectedMessageCount = 100;
                setState(() {});
                _startTest();
              },
              child: const Text('Throttled: 100KB @ 12KB/s'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Stress test: send 500KB at 48KB/s
                _selectedThrottleRate = 48;
                _selectedMessageSize = 2000;
                _selectedMessageCount = 250;
                setState(() {});
                _startTest();
              },
              child: const Text('Stress: 500KB @ 48KB/s'),
            ),
          ],
        ),
      ),
    );
  }
}
