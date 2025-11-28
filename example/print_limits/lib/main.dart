import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const PrintLimitsApp());
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

class PrintLimitsApp extends StatelessWidget {
  const PrintLimitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Print Limits Test',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const PrintLimitsPage(),
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
