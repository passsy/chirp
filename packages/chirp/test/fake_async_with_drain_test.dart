import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'fake_async_with_drain.dart';

void main() {
  test('drain waits for parallel file operations', () async {
    final tempDir = Directory.systemTemp.createTempSync('chirp_io_drain_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    await fakeAsyncWithDrain((async) async {
      final firstFile = File('${tempDir.path}/first.log');
      final secondFile = File('${tempDir.path}/second.log');
      final writes = [
        firstFile.writeAsString('first'),
        secondFile.writeAsString('second'),
      ];

      await async.drain();
      await Future.wait(writes);

      expect(firstFile.readAsStringSync(), 'first');
      expect(secondFile.readAsStringSync(), 'second');
    });
  });

  test('drain settles chained random access file operations', () async {
    final tempDir = Directory.systemTemp.createTempSync('chirp_io_chain_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    await fakeAsyncWithDrain((async) async {
      final file = File('${tempDir.path}/app.log');
      final handle = file.openSync(mode: FileMode.write);
      final operations = handle
          .writeFrom(utf8.encode('message'))
          .then((handle) => handle.flush())
          .then((handle) => handle.close());

      await async.drain();
      await operations;

      expect(file.readAsStringSync(), 'message');
    });
  });
}
