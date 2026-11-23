import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader_io.dart'
    as io_impl;
import 'package:chirp/src/writers/rotating_file_writer/rotating_file_reader_stub.dart'
    as stub_impl;
import 'package:clock/clock.dart';
import 'package:test/test.dart';

import 'test_log_record.dart';

void main() {
  /// Creates a temp directory and registers cleanup.
  Directory createTempDir() {
    final dir = Directory.systemTemp.createTempSync('chirp-log-reader-');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  test('createRotatingFileReader has same signature in io and stub', () {
    // Both conditional import files must have identical signatures.
    // Cross-assigning verifies they are the same type. A signature mismatch
    // in either file causes a compile error here.
    // ignore: unused_local_variable
    var fn = io_impl.createRotatingFileReader;
    fn = stub_impl.createRotatingFileReader;

    var fn2 = stub_impl.createRotatingFileReader;
    fn2 = io_impl.createRotatingFileReader;

    // Suppress unused variable warning
    expect(fn, isNotNull);
    expect(fn2, isNotNull);
  });

  group('listFiles', () {
    test('returns rotated + current sorted oldest->newest', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated1 = File('${dir.path}/app.2024-01-01_10-00-00.log');
      final rotated2 = File('${dir.path}/app.2024-01-02_10-00-00.log');

      rotated2.writeAsStringSync('r2\n');
      rotated1.writeAsStringSync('r1\n');
      base.writeAsStringSync('current\n');

      // Make modified times deterministic.
      rotated1.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotated2.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles();
      expect(files, [rotated1.path, rotated2.path, base.path]);
    });

    test('excludes current file when includeCurrent is false', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old\n');
      base.writeAsStringSync('current\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles(includeCurrent: false);
      expect(files, [rotated.path]);
    });

    test('returns empty list when directory does not exist', () async {
      final reader = RotatingFileReader(
        baseFilePathProvider: () => '/tmp/chirp-nonexistent-dir/app.log',
      );
      final files = await reader.listFiles();
      expect(files, isEmpty);
    });

    test('returns empty list when no matching files exist', () async {
      final dir = createTempDir();

      // Create an unrelated file
      File('${dir.path}/unrelated.txt').writeAsStringSync('nope\n');

      final base = File('${dir.path}/app.log');
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles();
      expect(files, isEmpty);
    });

    test('includes compressed .gz rotated files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final gzFile = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles();
      expect(files, [gzFile.path, base.path]);
    });

    test('ignores unrelated files with similar prefix', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      // These should NOT match
      File('${dir.path}/app.log.bak').writeAsStringSync('backup\n');
      File('${dir.path}/application.log').writeAsStringSync('other\n');
      File('${dir.path}/app.2024-01-01_10-00-00.backup')
          .writeAsStringSync('other extension\n');
      File('${dir.path}/app.2024-01-01_10-00-00.log.old')
          .writeAsStringSync('other suffix\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final files = await reader.listFiles();
      expect(files, [base.path]);
    });
  });

  group('read', () {
    test('reads all files in order', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old1\nold2\n');
      base.writeAsStringSync('new1\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['old1', 'old2', 'new1']);
    });

    test('returns empty stream when no files exist', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('returns empty stream when directory does not exist', () async {
      final reader = RotatingFileReader(
        baseFilePathProvider: () => '/tmp/chirp-nonexistent-dir/app.log',
      );
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('reads only current file when no rotated files exist', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('line1\nline2\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['line1', 'line2']);
    });

    test('reads empty current file', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, isEmpty);
    });

    test('reads file without trailing newline', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('no-trailing-newline');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['no-trailing-newline']);
    });

    test('preserves empty lines', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n\n\nlast\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['first', '', '', 'last']);
    });

    test('reads compressed .gz files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final gzFile = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(gzip.encode(utf8.encode('old1\nold2\n')));

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['old1', 'old2', 'current']);
    });

    test('reads mix of plain and compressed files in order', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final rotatedPlain = File('${dir.path}/app.2024-01-02_10-00-00.log');
      rotatedPlain.writeAsStringSync('plain\n');

      final rotatedGz = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      rotatedGz.writeAsBytesSync(gzip.encode(utf8.encode('compressed\n')));

      rotatedGz.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotatedPlain.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['compressed', 'plain', 'current']);
    });

    test('reads multiple rotated files across many rotations', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('e\n');

      final r1 = File('${dir.path}/app.2024-01-01_10-00-00.log');
      r1.writeAsStringSync('a\n');
      final r2 = File('${dir.path}/app.2024-01-02_10-00-00.log');
      r2.writeAsStringSync('b\n');
      final r3 = File('${dir.path}/app.2024-01-03_10-00-00.log');
      r3.writeAsStringSync('c\n');
      final r4 = File('${dir.path}/app.2024-01-04_10-00-00.log');
      r4.writeAsStringSync('d\n');

      r1.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      r2.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      r3.setLastModifiedSync(DateTime(2024, 1, 3, 10));
      r4.setLastModifiedSync(DateTime(2024, 1, 4, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 5, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read().toList();
      expect(lines, ['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('read with last', () {
    test('returns last N records across multiple files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('c1\nc2\n');

      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      rotated.writeAsStringSync('a1\na2\na3\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 3).toList();
      expect(lines, ['a3', 'c1', 'c2']);
    });

    test('returns all records when last exceeds total', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('one\ntwo\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 100).toList();
      expect(lines, ['one', 'two']);
    });

    test('returns exactly N records when last equals total', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('one\ntwo\nthree\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 3).toList();
      expect(lines, ['one', 'two', 'three']);
    });

    test('returns single last record', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\nthird\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 1).toList();
      expect(lines, ['third']);
    });

    test('last: 0 returns nothing', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 0).toList();
      expect(lines, isEmpty);
    });

    test('last with no files returns empty', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 5).toList();
      expect(lines, isEmpty);
    });

    test('last spanning compressed and plain files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('new1\nnew2\n');

      final gzFile = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      gzFile.writeAsBytesSync(
        gzip.encode(utf8.encode('old1\nold2\nold3\n')),
      );

      gzFile.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 4).toList();
      expect(lines, ['old2', 'old3', 'new1', 'new2']);
    });

    test('last with empty files in between', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final emptyRotated = File('${dir.path}/app.2024-01-02_10-00-00.log');
      emptyRotated.writeAsStringSync('');

      final oldRotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      oldRotated.writeAsStringSync('old\n');

      oldRotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      emptyRotated.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = await reader.read(last: 2).toList();
      expect(lines, ['old', 'current']);
    });
  });

  group('tail', () {
    test('emits appended lines', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail(last: 10));
      addTearDown(lines.cancel);

      expect(await _nextLines(lines, 1), ['first']);
      base.writeAsStringSync('second\n', mode: FileMode.append, flush: true);
      expect(await _nextLines(lines, 1), ['second']);
    });

    test('emits historical lines then new lines', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

      rotated.writeAsStringSync('old1\nold2\n');
      base.writeAsStringSync('current\n');

      rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail(last: 2));
      addTearDown(lines.cancel);

      // Append only after the history arrived, or `last: 2` would rightly
      // count the appended line as history.
      final received = await _nextLines(lines, 2);
      base.writeAsStringSync('appended\n', mode: FileMode.append, flush: true);
      received.addAll(await _nextLines(lines, 1));
      expect(received, ['old2', 'current', 'appended']);
    });

    for (final last in [null, 2]) {
      test('emits a line appended while the history is read (last: $last)',
          () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

        rotated.writeAsStringSync('old1\nold2\n');
        base.writeAsStringSync('current\n');

        rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
        base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

        final encoding = _HookedUtf8.afterReading('current', () {
          base.writeAsStringSync('appended\n',
              mode: FileMode.append, flush: true);
        });

        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines =
            StreamIterator(reader.tail(last: last, encoding: encoding));
        addTearDown(lines.cancel);

        final history = last == null ? ['old1', 'old2'] : ['old2'];
        expect(
          await _nextLines(lines, history.length + 2),
          [...history, 'current', 'appended'],
        );

        // The next line proves that nothing was emitted twice.
        base.writeAsStringSync('end\n', mode: FileMode.append, flush: true);
        expect(await _nextLines(lines, 1), ['end']);
      });

      test(
          'emits each line once when the file rotates while the history is read (last: $last)',
          () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

        rotated.writeAsStringSync('old1\nold2\n');
        base.writeAsStringSync('current\n');

        rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
        base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

        final encoding = _HookedUtf8.afterReading('current', () {
          base.renameSync('${dir.path}/app.2024-01-02_10-00-00.log');
          base.writeAsStringSync('fresh1\nfresh2\n', flush: true);
        });

        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines = StreamIterator(
          reader.tail(last: last == null ? null : 10, encoding: encoding),
        );
        addTearDown(lines.cancel);

        expect(
          await _nextLines(lines, 5),
          ['old1', 'old2', 'current', 'fresh1', 'fresh2'],
        );

        base.writeAsStringSync('end\n', mode: FileMode.append, flush: true);
        expect(await _nextLines(lines, 1), ['end']);
      });

      test(
          'emits each line once when the file is replaced while the history is read (last: $last)',
          () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');

        rotated.writeAsStringSync('old1\nold2\n');
        base.writeAsStringSync('before\n');

        rotated.setLastModifiedSync(DateTime(2024, 1, 1, 10));
        base.setLastModifiedSync(DateTime(2024, 1, 2, 10));

        // Longer than the replaced content, so the size alone looks like an
        // append.
        final encoding = _HookedUtf8.afterReading('old1', () {
          base.writeAsStringSync('new1\nnew2\nnew3\n', flush: true);
        });

        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines = StreamIterator(
          reader.tail(last: last == null ? null : 10, encoding: encoding),
        );
        addTearDown(lines.cancel);

        // With `last`, the current file is read before the rotated one, so
        // its old content is part of the history.
        final history = last == null ? <String>[] : ['before'];
        expect(
          await _nextLines(lines, history.length + 5),
          ['old1', 'old2', ...history, 'new1', 'new2', 'new3'],
        );

        base.writeAsStringSync('end\n', mode: FileMode.append, flush: true);
        expect(await _nextLines(lines, 1), ['end']);
      });
    }

    for (final last in [0, -1, 1]) {
      test('emits the lines of a file rotated in while it starts (last: $last)',
          () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        base.writeAsStringSync('current\n');

        final encoding = _HookedUtf8.afterReading('current', () {
          base.renameSync('${dir.path}/app.2024-01-02_10-00-00.log');
          base.writeAsStringSync('new1\nnew2\n', flush: true);
        });

        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines =
            StreamIterator(reader.tail(last: last, encoding: encoding));
        addTearDown(lines.cancel);

        final history = last > 0 ? ['current'] : <String>[];
        expect(
          await _nextLines(lines, history.length + 2),
          [...history, 'new1', 'new2'],
        );
      });
    }

    for (final compressed in [false, true]) {
      test(
          'emits lines appended right before a rotation (compressed: $compressed)',
          () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        base.writeAsStringSync('first\n');

        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines = StreamIterator(reader.tail());
        addTearDown(lines.cancel);
        expect(await _nextLines(lines, 1), ['first']);

        // All of this happens before the reader can look again.
        base.writeAsStringSync('missed\n', mode: FileMode.append, flush: true);
        final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
        base.renameSync(rotated.path);
        if (compressed) {
          File('${rotated.path}.gz')
              .writeAsBytesSync(gzip.encode(rotated.readAsBytesSync()));
          rotated.deleteSync();
        }
        base.writeAsStringSync('fresh\n', flush: true);

        expect(await _nextLines(lines, 2), ['missed', 'fresh']);
      });
    }

    for (final last in [-1, 0, 1, 5]) {
      test(
          'looks again when the file is rotated between its first looks (last: $last)',
          () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        base.writeAsStringSync('before\n');

        // The reader has listed the rotated files and opened the current
        // file when it lists a second time.
        final hooks = _IoHooks(dir.path);
        hooks.beforeListing[2] = () {
          base.renameSync('${dir.path}/app.2024-01-01_10-00-00.log');
          base.writeAsStringSync('new1\nnew2\n', flush: true);
        };

        await IOOverrides.runWithIOOverrides(() async {
          final reader =
              RotatingFileReader(baseFilePathProvider: () => base.path);
          // Appended when the reader has read the new file, so it is not
          // history anymore.
          final encoding = _HookedUtf8.afterReading('new1', () {
            base.writeAsStringSync('end\n', mode: FileMode.append, flush: true);
          });
          final lines =
              StreamIterator(reader.tail(last: last, encoding: encoding));
          addTearDown(lines.cancel);

          // Written while the tail started, so it is history.
          const all = ['before', 'new1', 'new2'];
          final history = all.sublist(all.length - last.clamp(0, 3));
          expect(
            await _nextLines(lines, history.length + 1),
            [...history, 'end'],
          );
        }, hooks);
      });
    }

    test('keeps the history apart when a name is reused while it starts',
        () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      rotated.writeAsStringSync('old\n');
      base.writeAsStringSync('current\n');

      // The retention policy deletes the rotated file, and two rotations
      // follow. The first one gets the name of the deleted file.
      final hooks = _IoHooks(dir.path);
      hooks.beforeListing[2] = () {
        rotated.deleteSync();
        base.renameSync(rotated.path);
        base.writeAsStringSync('middle\n', flush: true);
        base.renameSync('${dir.path}/app.2024-01-01_10-00-00_1.log');
        base.writeAsStringSync('replacement\n', flush: true);
      };

      await IOOverrides.runWithIOOverrides(() async {
        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines = StreamIterator(reader.tail(last: 5));
        addTearDown(lines.cancel);
        expect(
          await _nextLines(lines, 3),
          ['current', 'middle', 'replacement'],
        );
      }, hooks);
    });

    test('reads a rotated file again when it could not be opened', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      base.writeAsStringSync('before\n');

      final hooks = _IoHooks(dir.path);
      await IOOverrides.runWithIOOverrides(() async {
        final reader = RotatingFileReader(
          baseFilePathProvider: () => base.path,
          pollInterval: const Duration(milliseconds: 30),
        );
        final lines = StreamIterator(reader.tail());
        addTearDown(lines.cancel);
        expect(await _nextLines(lines, 1), ['before']);

        hooks.failOpenOnce.add(rotated.path);
        base.writeAsStringSync('unread\n', mode: FileMode.append, flush: true);
        base.renameSync(rotated.path);
        base.writeAsStringSync('replacement\n', flush: true);

        expect(await _nextLines(lines, 2), ['unread', 'replacement']);
        expect(hooks.failOpenOnce, isEmpty);
      }, hooks);
    });

    test('reports once that the files can not be read for a while', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('before\n');

      final hooks = _IoHooks(dir.path);
      await IOOverrides.runWithIOOverrides(() async {
        final reader = RotatingFileReader(
          baseFilePathProvider: () => base.path,
          pollInterval: const Duration(milliseconds: 30),
        );
        final lines = <String>[];
        final errors = <Object>[];
        // A StreamIterator would end at the first error.
        final subscription =
            reader.tail().listen(lines.add, onError: errors.add);
        addTearDown(subscription.cancel);

        Future<void> until(bool Function() condition) async {
          final waited = Stopwatch()..start();
          while (!condition()) {
            if (waited.elapsed > const Duration(seconds: 15)) {
              fail('Timed out with lines $lines and errors $errors');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }

        await until(() => lines.isNotEmpty);
        hooks.failListing = true;
        base.writeAsStringSync('after\n', mode: FileMode.append, flush: true);
        await until(() => errors.isNotEmpty);
        // Many polls fail meanwhile.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        hooks.failListing = false;

        await until(() => lines.length == 2);
        expect(lines, ['before', 'after']);
        expect(errors, [isA<FileSystemException>()]);
      }, hooks);
    });

    test('starts again when the current file could not be opened', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('old\nalready\n');

      final hooks = _IoHooks(dir.path);
      hooks.failOpenOnce.add(base.path);
      await IOOverrides.runWithIOOverrides(() async {
        final reader = RotatingFileReader(
          baseFilePathProvider: () => base.path,
          pollInterval: const Duration(milliseconds: 30),
        );
        final lines = StreamIterator(reader.tail(last: 1));
        addTearDown(lines.cancel);

        // Not `old`, which would be a history that ignores `last`.
        expect(await _nextLines(lines, 1), ['already']);
        expect(hooks.failOpenOnce, isEmpty);

        base.writeAsStringSync('new\n', mode: FileMode.append, flush: true);
        expect(await _nextLines(lines, 1), ['new']);
      }, hooks);
    });

    test('emits a rotated file once when it is compressed while listed',
        () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      rotated.writeAsStringSync('old\n');
      base.writeAsStringSync('current\n');

      final hooks = _IoHooks(dir.path);
      await IOOverrides.runWithIOOverrides(() async {
        final reader =
            RotatingFileReader(baseFilePathProvider: () => base.path);
        final lines = StreamIterator(reader.tail());
        addTearDown(lines.cancel);
        expect(await _nextLines(lines, 2), ['old', 'current']);

        // The next listing still holds the plain file, which is deleted
        // before the reader looks at it.
        hooks.listedOnce.add(File(rotated.path));
        File('${rotated.path}.gz')
            .writeAsBytesSync(gzip.encode(rotated.readAsBytesSync()));
        rotated.deleteSync();

        base.writeAsStringSync('end1\n', mode: FileMode.append, flush: true);
        expect(await _nextLines(lines, 1), ['end1']);
        base.writeAsStringSync('end2\n', mode: FileMode.append, flush: true);
        expect(await _nextLines(lines, 1), ['end2']);
      }, hooks);
    });

    test('emits the history behind a broken archive', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      File('${dir.path}/app.2024-01-01_10-00-00.log')
          .writeAsStringSync('older\n');
      File('${dir.path}/app.2024-01-02_10-00-00.log.gz')
          .writeAsBytesSync([1, 2, 3]);
      base.writeAsStringSync('current\n');

      final error = Completer<Object>();
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines =
          StreamIterator(reader.tail(last: 5).handleError(error.complete));
      addTearDown(lines.cancel);

      expect(await _nextLines(lines, 2), ['older', 'current']);
      expect(await error.future, isA<FormatException>());
    });

    test('emits the rotated files that are kept when the start is rotated away',
        () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated1 = File('${dir.path}/app.2024-01-01_10-00-00.log');
      final rotated2 = File('${dir.path}/app.2024-01-01_10-00-00_1.log');
      base.writeAsStringSync('seq0\n');

      // Two rotations right after the start was read, and the retention
      // policy deletes the first rotated file.
      final encoding = _HookedUtf8.afterReading('seq0', () {
        base.renameSync(rotated1.path);
        base.writeAsStringSync('seq1\n', flush: true);
        base.renameSync(rotated2.path);
        rotated1.deleteSync();
        base.writeAsStringSync('seq2\n', flush: true);
      });

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail(last: 0, encoding: encoding));
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 2), ['seq1', 'seq2']);
    });

    test('emits lines of a rotated file whose successor starts the same',
        () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('same\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['same']);

      base.writeAsStringSync('unread\n', mode: FileMode.append, flush: true);
      base.renameSync('${dir.path}/app.2024-01-01_10-00-00.log');
      base.writeAsStringSync('same\nnew\n', flush: true);

      expect(await _nextLines(lines, 3), ['unread', 'same', 'new']);
    });

    test('emits lines of a rotated file that reuses a name', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      base.writeAsStringSync('a1\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['a1']);

      // Both files of that name get the same size and modification time.
      final modified = DateTime(2024, 1, 1, 10);
      base.writeAsStringSync('a2\n', mode: FileMode.append, flush: true);
      base.renameSync(rotated.path);
      rotated.setLastModifiedSync(modified);
      base.writeAsStringSync('b1\n', flush: true);
      expect(await _nextLines(lines, 2), ['a2', 'b1']);

      // The retention policy deletes the rotated file, and the next
      // rotation of the same second gets its name.
      rotated.deleteSync();
      base.writeAsStringSync('b2\n', mode: FileMode.append, flush: true);
      base.renameSync(rotated.path);
      rotated.setLastModifiedSync(modified);
      base.writeAsStringSync('c1\n', flush: true);
      expect(await _nextLines(lines, 2), ['b2', 'c1']);
    });

    test('reads a broken archive again when it is replaced', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      rotated.writeAsBytesSync([1, 2, 3]);
      base.writeAsStringSync('current\n');

      final error = Completer<Object>();
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail().handleError(error.complete));
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['current']);
      expect(await error.future, isA<FormatException>());

      rotated.writeAsBytesSync(gzip.encode(utf8.encode('recovered\n')));
      expect(await _nextLines(lines, 1), ['recovered']);
    });

    test('orders rotated files by their names, compression changes the time',
        () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      final rotated1 = File('${dir.path}/app.2024-01-01_10-00-00.log.gz');
      final rotated2 = File('${dir.path}/app.2024-01-02_10-00-00.log');
      final rotated3 = File('${dir.path}/app.2024-01-02_10-00-00_2.log');
      final rotated4 = File('${dir.path}/app.2024-01-02_10-00-00_10.log');

      rotated1.writeAsBytesSync(gzip.encode(utf8.encode('first\n')));
      rotated2.writeAsStringSync('second\n');
      rotated3.writeAsStringSync('third\n');
      rotated4.writeAsStringSync('fourth\n');
      base.writeAsStringSync('current\n');

      rotated4.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotated3.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      rotated2.setLastModifiedSync(DateTime(2024, 1, 3, 10));
      rotated1.setLastModifiedSync(DateTime(2024, 1, 4, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      const all = ['first', 'second', 'third', 'fourth', 'current'];
      expect(await reader.read().toList(), all);
      expect(await reader.read(last: 4).toList(), all.sublist(1));

      for (final last in [null, 4]) {
        final lines = StreamIterator(reader.tail(last: last));
        addTearDown(lines.cancel);
        final expected = last == null ? all : all.sublist(1);
        expect(await _nextLines(lines, expected.length), expected);
      }
    });

    test('never joins the old and the new content of a rewritten file',
        () async {
      final dir = createTempDir();

      // Longer than one read, so the rewrite happens within the file.
      final oldRecords = [for (var i = 0; i < 20000; i++) 'old-$i'.padRight(9)];
      final newRecords = [for (var i = 0; i < 20000; i++) 'new-$i'.padRight(9)];

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('${oldRecords.join('\n')}\n');

      final encoding = _HookedUtf8.afterReading(oldRecords.first, () {
        base.writeAsStringSync('${newRecords.join('\n')}\n', flush: true);
      });

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail(encoding: encoding));
      addTearDown(lines.cancel);

      final received = <String>[];
      while (received.isEmpty || received.last != newRecords.last) {
        received.addAll(await _nextLines(lines, 1));
      }

      final known = {...oldRecords, ...newRecords};
      expect(received.where((it) => !known.contains(it)), isEmpty);
      expect(received.where(newRecords.contains), newRecords);
    });

    test('stops reading a rotated file while the listener is paused', () async {
      final dir = createTempDir();

      // Several reads long.
      final records = [for (var i = 0; i < 50000; i++) 'record-$i'];
      File('${dir.path}/app.2024-01-01_10-00-00.log')
          .writeAsStringSync('${records.join('\n')}\n');
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      var chunks = 0;
      final encoding = _HookedUtf8(onChunkDecoded: (_) => chunks++);
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);

      final received = <String>[];
      final paused = Completer<void>();
      final done = Completer<void>();
      // ignore: cancel_subscriptions
      StreamSubscription<String>? subscription;
      subscription = reader.tail(encoding: encoding).listen((record) {
        received.add(record);
        if (!paused.isCompleted) {
          subscription?.pause();
          paused.complete();
        }
        if (record == 'current') {
          done.complete();
        }
      });
      addTearDown(subscription.cancel);

      await paused.future;
      // Time to read on, if the reader ignored the pause.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The read that was running when the listener paused is the last.
      expect(chunks, lessThanOrEqualTo(2));

      subscription.resume();
      await done.future;
      expect(received, [...records, 'current']);
    });

    test('emits lines of two rotations between two looks', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['first']);

      base.writeAsStringSync('second\n', mode: FileMode.append, flush: true);
      final rotated1 = File('${dir.path}/app.2024-01-01_10-00-00.log');
      base.renameSync(rotated1.path);
      rotated1.setLastModifiedSync(DateTime(2024, 1, 1, 10));

      base.writeAsStringSync('third\nunterminated', flush: true);
      final rotated2 = File('${dir.path}/app.2024-01-02_10-00-00.log');
      base.renameSync(rotated2.path);
      rotated2.setLastModifiedSync(DateTime(2024, 1, 2, 10));

      base.writeAsStringSync('fourth\n', flush: true);

      expect(
        await _nextLines(lines, 4),
        ['second', 'third', 'unterminated', 'fourth'],
      );
    });

    test('reads a file from its start when its beginning was rewritten',
        () async {
      final dir = createTempDir();
      final sameRecord = 'x' * 64;

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('old\n$sameRecord\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 2), ['old', sameRecord]);

      // Same size and same last bytes up to where the reader was.
      base.writeAsStringSync('new\n$sameRecord\nafter\n', flush: true);
      expect(await _nextLines(lines, 3), ['new', sameRecord, 'after']);
    });

    test('stops polling when cancelled while it starts to follow', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('current\n');

      final timers = <Timer>[];
      final cancelled = Completer<void>();
      await runZoned(
        () async {
          // ignore: cancel_subscriptions
          StreamSubscription<String>? subscription;
          final encoding = _HookedUtf8.afterReading('current', () {
            cancelled.complete(subscription?.cancel());
          });
          final reader =
              RotatingFileReader(baseFilePathProvider: () => base.path);
          subscription = reader.tail(encoding: encoding).listen((_) {});
          await cancelled.future;
          // Lets the cancelled tail run to its end.
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, period, callback) {
            final timer = parent.createPeriodicTimer(zone, period, callback);
            timers.add(timer);
            return timer;
          },
        ),
      );

      expect(timers.where((it) => it.isActive), isEmpty);
    });

    test('emits lines of a new file that grew past the old one', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['first']);

      // Rotation, and the new file is already longer when the reader looks.
      base.renameSync('${dir.path}/app.2024-01-01_10-00-00.log');
      base.writeAsStringSync('second\nthird\n', flush: true);
      expect(await _nextLines(lines, 2), ['second', 'third']);
    });

    final incompleteRecords = [
      (
        name: 'record',
        separator: '\n',
        start: utf8.encode('first\nhel'),
        rest: utf8.encode('lo\n'),
        record: 'hello',
      ),
      (
        name: 'record separator',
        separator: '\r\n',
        start: utf8.encode('first\r\nhello\r'),
        rest: utf8.encode('\n'),
        record: 'hello',
      ),
      (
        name: 'character',
        separator: '\n',
        start: [...utf8.encode('first\n'), ...utf8.encode('€').take(2)],
        rest: [...utf8.encode('€').skip(2), ...utf8.encode('\n')],
        record: '€',
      ),
    ];
    for (final incomplete in incompleteRecords) {
      for (final last in [null, 0, 5]) {
        test(
            'waits for the rest of an incomplete ${incomplete.name} (last: $last)',
            () async {
          final dir = createTempDir();

          final base = File('${dir.path}/app.log');
          base.writeAsBytesSync(incomplete.start);

          final reader = RotatingFileReader(
            baseFilePathProvider: () => base.path,
            recordSeparator: incomplete.separator,
          );
          // Appends the rest right after the incomplete part was read.
          final encoding = _HookedUtf8.afterReading('first', () {
            base.writeAsBytesSync(incomplete.rest,
                mode: FileMode.append, flush: true);
          });
          final lines =
              StreamIterator(reader.tail(last: last, encoding: encoding));
          addTearDown(lines.cancel);

          final expected = [if (last != 0) 'first', incomplete.record];
          expect(await _nextLines(lines, expected.length), expected);
        });
      }
    }

    test('reports undecodable bytes and continues behind them', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final error = Completer<Object>();
      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail().handleError(error.complete));
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['first']);

      final next = _nextLines(lines, 1);
      base.writeAsBytesSync([0xff, 0x0a], mode: FileMode.append, flush: true);
      expect(await error.future, isA<FormatException>());

      base.writeAsStringSync('after\n', mode: FileMode.append, flush: true);
      expect(await next, ['after']);
    });

    test('emits lines after truncation', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\nsecond\n');

      final reader = RotatingFileReader(
        baseFilePathProvider: () => base.path,
        pollInterval: const Duration(milliseconds: 30),
      );
      final lines = StreamIterator(reader.tail(last: 2));
      addTearDown(lines.cancel);

      // The history proves the reader is past the old content.
      expect(await _nextLines(lines, 2), ['first', 'second']);

      // Truncate file to simulate rotation/truncation, then append.
      base.writeAsStringSync('', flush: true);
      base.writeAsStringSync('after\n', mode: FileMode.append, flush: true);
      expect(await _nextLines(lines, 1), ['after']);
    });

    test('works when file does not exist yet', () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');
      final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
      rotated.writeAsStringSync('old\n');

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      final lines = StreamIterator(reader.tail(last: 5));
      addTearDown(lines.cancel);

      // The history is emitted after the reader looked for the current file,
      // so it proves that the file was missing then.
      expect(await _nextLines(lines, 1), ['old']);

      base.writeAsStringSync('appeared\n');
      expect(await _nextLines(lines, 1), ['appeared']);
    });

    test('works when directory does not exist yet', () async {
      final dir = Directory('${createTempDir().path}/logs');
      final base = File('${dir.path}/app.log');

      final watchAttempts = _WatchAttempts();
      await IOOverrides.runWithIOOverrides(() async {
        final reader = RotatingFileReader(
          baseFilePathProvider: () => base.path,
          pollInterval: const Duration(milliseconds: 30),
        );
        final lines = StreamIterator(reader.tail());
        addTearDown(lines.cancel);
        final next = _nextLines(lines, 1);

        // The reader tried to watch the missing directory when it started
        // and again with a poll.
        await watchAttempts.second.future;

        dir.createSync();
        base.writeAsStringSync('appeared\n');
        expect(await next, ['appeared']);
      }, watchAttempts);
    });

    test('works when directory is replaced', () async {
      final dir = Directory('${createTempDir().path}/logs')..createSync();
      final base = File('${dir.path}/app.log');
      base.writeAsStringSync('first\n');

      final reader = RotatingFileReader(
        baseFilePathProvider: () => base.path,
        pollInterval: const Duration(milliseconds: 30),
      );
      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 1), ['first']);

      dir.deleteSync(recursive: true);
      dir.createSync();
      base.writeAsStringSync('appeared\n');
      expect(await _nextLines(lines, 1), ['appeared']);
    });
  });

  group('rotated file that is compressed after it was listed', () {
    for (final last in [null, 5]) {
      test('read(last: $last) reads its .gz', () async {
        final dir = createTempDir();

        final base = File('${dir.path}/app.log');
        final rotated = File('${dir.path}/app.2024-01-01_10-00-00.log');
        File('${rotated.path}.gz')
            .writeAsBytesSync(gzip.encode(utf8.encode('old\n')));
        base.writeAsStringSync('current\n');

        // Listed as a plain file that is gone when it is opened.
        final hooks = _IoHooks(dir.path);
        hooks.listedOnce.add(File(rotated.path));

        await IOOverrides.runWithIOOverrides(() async {
          final reader =
              RotatingFileReader(baseFilePathProvider: () => base.path);
          expect(await reader.read(last: last).toList(), ['old', 'current']);
        }, hooks);
      });
    }
  });

  group('retention with compression', () {
    test('keeps the newest files when a compression ends early', () async {
      final dir = createTempDir();
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => '${dir.path}/app.log',
        rotationConfig: FileRotationConfig.size(
          maxSize: 100 * 1024 * 1024,
          maxFiles: 2,
          compress: true,
        ),
      );

      // The older file takes longer to compress than the newer one.
      writer.write(testRecord(message: 'older ${'x' * 4 * 1024 * 1024}'));
      await writer.forceRotate();
      writer.write(testRecord(message: 'newer'));
      await writer.forceRotate();
      writer.write(testRecord(message: 'current'));
      await writer.close();

      final records = await writer.reader.read().toList();
      expect(records, [contains('newer'), contains('current')]);
    });
    test('reports a failing retention after a compression', () async {
      final dir = createTempDir();
      final errors = <Object>[];
      final hooks = _IoHooks(dir.path);

      await IOOverrides.runWithIOOverrides(() async {
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => '${dir.path}/app.log',
          rotationConfig: FileRotationConfig.size(
            maxSize: 100 * 1024 * 1024,
            maxFiles: 2,
            compress: true,
          ),
          onError: (error, stackTrace, record) => errors.add(error),
        );

        writer.write(testRecord(message: 'first ${'x' * 1024 * 1024}'));
        await writer.forceRotate();
        writer.write(testRecord(message: 'second'));
        await writer.forceRotate();

        // The directory can not be listed when the compressions are done.
        hooks.failListing = true;
        await writer.close();
      }, hooks);

      expect(errors, isNotEmpty);
      expect(errors, everyElement(isA<FileSystemException>()));
    });
  });

  group('rotated file names', () {
    test('keep the order of the rotations when the clock goes back', () async {
      final dir = createTempDir();
      var now = DateTime(2024, 1, 15, 10);

      await withClock(Clock(() => now), () async {
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => '${dir.path}/app.log',
          rotationConfig: FileRotationConfig.size(maxSize: 1024 * 1024),
        );
        addTearDown(writer.close);

        writer.write(testRecord(message: 'first', timestamp: now));
        now = now.subtract(const Duration(hours: 1));
        await writer.forceRotate();
        writer.write(testRecord(message: 'second', timestamp: now));
        await writer.forceRotate();
        writer.write(testRecord(message: 'third', timestamp: now));
        await writer.flush();

        final expected = [
          contains('first'),
          contains('second'),
          contains('third'),
        ];
        expect(await writer.reader.read().toList(), expected);
        final lines = StreamIterator(writer.reader.tail());
        addTearDown(lines.cancel);
        expect(await _nextLines(lines, 3), expected);
      });
    });

    test('are read in their order when older files are deleted', () async {
      final dir = createTempDir();
      final time = DateTime(2024, 1, 15, 10);

      await withClock(Clock.fixed(time), () async {
        final writer = RotatingFileWriter(
          baseFilePathProvider: () => '${dir.path}/app.log',
          rotationConfig: FileRotationConfig.size(
            maxSize: 1024 * 1024,
            maxFiles: 3,
          ),
        );
        addTearDown(() => writer.close());

        for (var i = 1; i <= 5; i++) {
          writer.write(testRecord(message: 'record $i', timestamp: time));
          if (i < 5) {
            await writer.forceRotate();
          }
        }
        await writer.flush();

        final records = await writer.reader.read().toList();
        expect(records, [
          contains('record 3'),
          contains('record 4'),
          contains('record 5'),
        ]);
      });
    });
  });

  group('tail of a RotatingFileWriter', () {
    for (final compress in [false, true]) {
      for (final last in [null, 1]) {
        test(
            'emits every record once and in order (compress: $compress, last: $last)',
            () async {
          final dir = createTempDir();
          final writer = RotatingFileWriter(
            baseFilePathProvider: () => '${dir.path}/app.log',
            rotationConfig: FileRotationConfig.size(
              maxSize: 1024 * 1024,
              maxFiles: 100,
              compress: compress,
            ),
          );
          addTearDown(writer.close);
          writer.write(testRecord(message: 'record 0.'));
          await writer.flush();

          final lines = StreamIterator(writer.reader.tail(last: last));
          addTearDown(lines.cancel);
          expect(await _nextLines(lines, 1), [contains('record 0.')]);

          const count = 300;
          for (var i = 1; i <= count; i++) {
            writer.write(testRecord(message: 'record $i.'));
            if (i % 10 == 0) {
              await writer.forceRotate();
            }
            if (i % 7 == 0) {
              // Lets the tail read in between.
              await Future<void>.delayed(Duration.zero);
            }
          }
          await writer.flush();

          expect(
            await _nextLines(lines, count),
            [for (var i = 1; i <= count; i++) contains('record $i.')],
          );
        });
      }
    }

    test('loses no record that the retention policy keeps', () async {
      final dir = createTempDir();
      final writer = RotatingFileWriter(
        baseFilePathProvider: () => '${dir.path}/app.log',
        rotationConfig: FileRotationConfig.size(
          maxSize: 1024 * 1024,
          maxFiles: 3,
          compress: true,
        ),
      );
      addTearDown(writer.close);

      final received = <int>[];
      final done = Completer<void>();
      final subscription = writer.reader.tail().listen((record) {
        final match = RegExp(r'record (\d+)\.').firstMatch(record);
        final number = int.parse(match!.group(1)!);
        received.add(number);
        if (number == 300) {
          done.complete();
        }
      });
      addTearDown(subscription.cancel);

      for (var i = 1; i <= 300; i++) {
        writer.write(testRecord(message: 'record $i.'));
        if (i % 10 == 0) {
          await writer.forceRotate();
        }
        if (i % 7 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      await writer.flush();
      await done.future.timeout(const Duration(seconds: 15));

      // Records of rotated files that were deleted before the tail read them
      // can be missing, but none is repeated or out of order.
      for (var i = 1; i < received.length; i++) {
        expect(received[i], greaterThan(received[i - 1]));
      }
      final kept = await writer.reader.read().toList();
      final keptNumbers = [
        for (final record in kept)
          int.parse(RegExp(r'record (\d+)\.').firstMatch(record)!.group(1)!),
      ];
      expect(received, containsAllInOrder(keptNumbers),
          reason:
              'kept: $keptNumbers files: ${dir.listSync().map((it) => it.path.split('/').last).toList()..sort()}');
      // The current file and the rotated files that are kept.
      expect(
          received, containsAllInOrder([for (var i = 281; i <= 300; i++) i]));
    });
  });

  group('log file named *.gz', () {
    test('lists and reads its plain and compressed rotated files', () async {
      final dir = createTempDir();

      final base = File('${dir.path}/other.gz');
      final rotatedPlain = File('${dir.path}/other.2024-01-02_10-00-00.gz');
      final rotatedGz = File('${dir.path}/other.2024-01-01_10-00-00.gz.gz');

      rotatedGz.writeAsBytesSync(gzip.encode(utf8.encode('old1\n')));
      rotatedPlain.writeAsStringSync('old2\n');
      base.writeAsStringSync('current\n');

      rotatedGz.setLastModifiedSync(DateTime(2024, 1, 1, 10));
      rotatedPlain.setLastModifiedSync(DateTime(2024, 1, 2, 10));
      base.setLastModifiedSync(DateTime(2024, 1, 3, 10));

      final reader = RotatingFileReader(baseFilePathProvider: () => base.path);
      expect(
        await reader.listFiles(),
        [rotatedGz.path, rotatedPlain.path, base.path],
      );
      expect(await reader.read().toList(), ['old1', 'old2', 'current']);
      expect(await reader.read(last: 3).toList(), ['old1', 'old2', 'current']);

      final lines = StreamIterator(reader.tail());
      addTearDown(lines.cancel);
      expect(await _nextLines(lines, 3), ['old1', 'old2', 'current']);
    });
  });

  group('recordSeparator', () {
    test('write and read multi-line record round-trips as single record',
        () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write a record that contains embedded newlines (like a stack trace).
      final record = testRecord(
        message: 'Something failed',
        level: ChirpLogLevel.error,
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      );
      writer.write(record);
      await writer.flush();

      // Read back through the writer's reader (uses matching separator).
      final records = await writer.reader.read().toList();
      expect(records, hasLength(1),
          reason: 'Multi-line record should be read back as a single entry');
      expect(records.first, contains('Something failed'));
      expect(records.first, contains('boom'));
      expect(records.first, contains('rotating_file_reader_test.dart'),
          reason: 'Stack trace should be part of the same record');
    });

    test('tail emits complete multi-line records', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write a multi-line record (error with stack trace).
      writer.write(testRecord(
        message: 'Error with trace',
        level: ChirpLogLevel.error,
        error: Exception('fail'),
        stackTrace: StackTrace.current,
      ));
      await writer.flush();

      // Take exactly 1 record from tail — completes once the record arrives.
      final records = await writer.reader.tail().take(1).toList();

      expect(records, hasLength(1),
          reason: 'Should emit exactly one record for a multi-line entry');
      expect(records.first, contains('Error with trace'));
      expect(records.first, contains('fail'));
    });

    test('backward compat with recordSeparator "\\n" behaves like LineSplitter',
        () async {
      final dir = createTempDir();
      final base = File('${dir.path}/app.log');

      // Write files with plain newline separator (old format).
      base.writeAsStringSync('line1\nline2\nline3\n');

      final reader = RotatingFileReader(
        baseFilePathProvider: () => base.path,
        // ignore: avoid_redundant_argument_values
        recordSeparator: '\n',
      );
      final lines = await reader.read().toList();
      expect(lines, ['line1', 'line2', 'line3']);
    });

    test('read(last: N) returns N multi-line records, not N lines', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write 5 multi-line records (each contains embedded newlines).
      for (var i = 0; i < 5; i++) {
        writer.write(testRecord(
          message: 'Heartbeat #$i\nAll systems operational.',
        ));
      }
      await writer.flush();

      // Ask for the last 3 records.
      final records = await writer.reader.read(last: 3).toList();
      expect(records, hasLength(3),
          reason: 'last: 3 should return 3 records, not 3 lines');
      for (var i = 0; i < 3; i++) {
        expect(records[i], contains('Heartbeat #${i + 2}'));
        expect(records[i], contains('All systems operational.'),
            reason: 'Each record should contain the full multi-line message');
      }
    });

    test('tail(last: N) returns N multi-line records, not N lines', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
      );
      addTearDown(() => writer.close());

      // Write 5 multi-line records.
      for (var i = 0; i < 5; i++) {
        writer.write(testRecord(
          message: 'Heartbeat #$i\nAll systems operational.',
        ));
      }
      await writer.flush();

      // Tail the last 3 records, then take only those 3 (don't wait for new).
      final records = await writer.reader.tail(last: 3).take(3).toList();
      expect(records, hasLength(3),
          reason: 'last: 3 should return 3 records, not 3 lines');
      for (var i = 0; i < 3; i++) {
        expect(records[i], contains('Heartbeat #${i + 2}'));
        expect(records[i], contains('All systems operational.'),
            reason: 'Each record should contain the full multi-line message');
      }
    });

    test('JsonLogFormatter uses newline separator (no \\x1E)', () async {
      final dir = createTempDir();
      final logPath = '${dir.path}/app.log';

      final writer = RotatingFileWriter(
        baseFilePathProvider: () => logPath,
        formatter: const JsonLogFormatter(),
      );
      addTearDown(() => writer.close());

      writer.write(testRecord(message: 'Hello'));
      writer.write(testRecord(message: 'World'));
      await writer.flush();

      final content = File(logPath).readAsStringSync();
      // JsonLogFormatter inherits default '\n' separator, no \x1E
      expect(content, isNot(contains('\x1E')));
      // Each line ends with \n
      final lines = content.split('\n')..removeWhere((s) => s.isEmpty);
      expect(lines, hasLength(2));
      expect(jsonDecode(lines[0]), containsPair('message', 'Hello'));
      expect(jsonDecode(lines[1]), containsPair('message', 'World'));
    });
  });
}

/// Awaits the next [count] lines of a tail, which never ends by itself.
Future<List<String>> _nextLines(StreamIterator<String> lines, int count) async {
  final result = <String>[];
  while (result.length < count) {
    final hasNext = await lines.moveNext().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        fail('Expected $count lines, but after 15s only got $result');
      },
    );
    if (!hasNext) {
      break;
    }
    result.add(lines.current);
  }
  return result;
}

/// UTF-8 that calls [onChunkDecoded] with every chunk of bytes it decoded,
/// which is the moment the reader has read that part of a file.
class _HookedUtf8 extends Encoding {
  final void Function(List<int> bytes) onChunkDecoded;

  _HookedUtf8({required this.onChunkDecoded});

  /// Runs [action] once, right after a chunk containing [text] was read.
  factory _HookedUtf8.afterReading(String text, void Function() action) {
    var done = false;
    return _HookedUtf8(onChunkDecoded: (bytes) {
      if (done) {
        return;
      }
      if (utf8.decode(bytes, allowMalformed: true).contains(text)) {
        done = true;
        action();
      }
    });
  }

  @override
  String get name => utf8.name;

  @override
  Converter<String, List<int>> get encoder => utf8.encoder;

  @override
  Converter<List<int>, String> get decoder {
    return _HookedUtf8Decoder(onChunkDecoded);
  }
}

class _HookedUtf8Decoder extends Converter<List<int>, String> {
  final void Function(List<int> bytes) onChunkDecoded;

  _HookedUtf8Decoder(this.onChunkDecoded);

  @override
  String convert(List<int> input) => utf8.decode(input);

  @override
  Sink<List<int>> startChunkedConversion(Sink<String> sink) {
    return _HookedSink(utf8.decoder.startChunkedConversion(sink), this);
  }
}

class _HookedSink implements Sink<List<int>> {
  final Sink<List<int>> _utf8;
  final _HookedUtf8Decoder _decoder;

  _HookedSink(this._utf8, this._decoder);

  @override
  void add(List<int> data) {
    _utf8.add(data);
    _decoder.onChunkDecoded(data);
  }

  @override
  void close() {
    _utf8.close();
  }
}

/// Completes [second] when the reader asked a second time whether it can
/// watch the directory.
final class _WatchAttempts extends IOOverrides {
  final second = Completer<void>();
  int _count = 0;

  @override
  bool fsWatchIsSupported() {
    _count++;
    if (_count == 2) {
      second.complete();
    }
    return super.fsWatchIsSupported();
  }
}

/// Runs actions right before the reader lists the directory at [path], adds
/// entries to what it gets listed and lets it fail to open files.
final class _IoHooks extends IOOverrides {
  final String path;

  /// Actions by the number of the listing they run before, starting at 1.
  final beforeListing = <int, void Function()>{};

  /// Entries that only the next listing holds, like files that are deleted
  /// right after they were listed.
  final listedOnce = <FileSystemEntity>[];

  /// Paths of files whose next open fails although they exist.
  final failOpenOnce = <String>{};

  /// Makes every listing fail.
  bool failListing = false;

  int _listings = 0;

  _IoHooks(this.path);

  @override
  Directory createDirectory(String path) {
    final directory = super.createDirectory(path);
    if (path != this.path) {
      return directory;
    }
    return _HookedDirectory(directory, this);
  }

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    if (!failOpenOnce.contains(path)) {
      return file;
    }
    return _HookedFile(file, this);
  }
}

class _HookedDirectory implements Directory {
  final Directory _directory;
  final _IoHooks _hooks;

  _HookedDirectory(this._directory, this._hooks);

  @override
  String get path => _directory.path;

  @override
  bool existsSync() => _directory.existsSync();

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (_hooks.failListing) {
      throw FileSystemException('Injected failure', path);
    }
    _hooks._listings++;
    _hooks.beforeListing[_hooks._listings]?.call();
    final entities = [
      ..._directory.listSync(recursive: recursive, followLinks: followLinks),
      ..._hooks.listedOnce,
    ];
    _hooks.listedOnce.clear();
    return entities;
  }

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    return _directory.watch(events: events, recursive: recursive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HookedFile implements File {
  final File _file;
  final _IoHooks _hooks;

  _HookedFile(this._file, this._hooks);

  @override
  String get path => _file.path;

  @override
  Uri get uri => _file.uri;

  @override
  Directory get parent => _file.parent;

  @override
  FileStat statSync() => _file.statSync();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    if (_hooks.failOpenOnce.remove(path)) {
      throw FileSystemException('Injected failure', path);
    }
    return await _file.open(mode: mode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
