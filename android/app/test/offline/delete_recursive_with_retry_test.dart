import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/offline/delete_recursive_with_retry.dart';

// Regression for the "Clear all downloads" bug (Settings → Downloads &
// Storage): `Directory.delete(recursive: true)` snapshots the tree once,
// then deletes bottom-up. A concurrent writer (cover art / library cache /
// lyrics caching, all of which write under the same per-server directory
// while the user is simply browsing) dropping a file into a subdirectory
// mid-walk makes that subdirectory's delete fail with "Directory not empty"
// — which is exactly why the user had to tap the button multiple times
// before it actually worked. Plain `test()` (not `testWidgets()`) — no
// FakeAsync involved, so the real `Timer`/`Future.delayed` calls below
// behave exactly as they do in production.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('heerr-delete-retry-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('deletes a directory with no concurrent writer on the first try', () async {
    final Directory sub = Directory('${tmp.path}/songs')..createSync(recursive: true);
    File('${sub.path}/song1.mp3').writeAsStringSync('audio');

    await deleteRecursiveWithRetry(tmp);

    expect(tmp.existsSync(), isFalse);
  });

  test('no-ops when the directory is already gone', () async {
    final Directory gone = Directory('${tmp.path}/already-deleted');
    await deleteRecursiveWithRetry(gone);
    expect(gone.existsSync(), isFalse);
  });

  test(
    'recovers when a concurrent writer races the delete '
    '(regression: "Directory not empty")',
    () async {
      final Directory songsDir = Directory('${tmp.path}/songs')
        ..createSync(recursive: true);
      File('${songsDir.path}/song1.mp3').writeAsStringSync('audio');
      final Directory coversDir = Directory('${tmp.path}/covers_hi')
        ..createSync(recursive: true);

      // Simulates the app's other writers (cover art / library cache /
      // lyrics caching) dropping fresh files into the tree while the
      // recursive delete's tree-walk is in flight.
      final Timer racer = Timer.periodic(const Duration(milliseconds: 5), (_) {
        if (!coversDir.existsSync()) return;
        try {
          File(
            '${coversDir.path}/race_${DateTime.now().microsecondsSinceEpoch}.jpg',
          ).writeAsStringSync('x');
        } catch (_) {
          // tmp may already be gone by the time this fires.
        }
      });
      addTearDown(racer.cancel);

      await deleteRecursiveWithRetry(tmp);
      racer.cancel();

      expect(tmp.existsSync(), isFalse);
    },
  );

  test(
    'rethrows once attempts are exhausted against a permanent failure',
    () async {
      // A read-only parent directory can never allow removing its child no
      // matter how many times it's retried — proves the retry loop still
      // surfaces a genuine (non-transient) failure instead of swallowing it.
      final Directory sub = Directory('${tmp.path}/locked')
        ..createSync(recursive: true);
      File('${sub.path}/song1.mp3').writeAsStringSync('audio');
      Process.runSync('chmod', <String>['555', sub.path]);
      addTearDown(() => Process.runSync('chmod', <String>['755', sub.path]));

      await expectLater(
        deleteRecursiveWithRetry(sub, attempts: 2),
        throwsA(isA<FileSystemException>()),
      );
    },
    skip: Platform.isWindows,
  );
}
