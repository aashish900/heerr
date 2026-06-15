import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/now_playing_snapshot.dart';
import 'package:heerr/player/now_playing_store.dart';

void main() {
  late Directory tmp;
  late File file;
  late NowPlayingStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr_npstore_');
    file = File('${tmp.path}/now_playing.json');
    store = NowPlayingStore(file);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('NowPlayingStore', () {
    test('load returns null when the file does not exist', () async {
      expect(await store.load(), isNull);
    });

    test('load returns null on empty file', () async {
      await file.writeAsString('');
      expect(await store.load(), isNull);
    });

    test('load returns null on corrupt JSON (does not throw)', () async {
      await file.writeAsString('this is not json');
      expect(await store.load(), isNull);
    });

    test('save then load round-trips', () async {
      const NowPlayingSnapshot s = NowPlayingSnapshot(
        songs: <Song>[
          Song(id: 'so-1', title: 'X', artist: 'Y', duration: 200),
        ],
        currentIndex: 0,
        positionMs: 12_345,
        updatedAt: 1_700_000_000_000,
      );
      await store.save(s);

      final NowPlayingSnapshot? back = await store.load();
      expect(back, isNotNull);
      expect(back, s);
    });

    test('save writes atomically (no stray .tmp left behind on success)',
        () async {
      const NowPlayingSnapshot s =
          NowPlayingSnapshot(currentIndex: 0, positionMs: 1, updatedAt: 1);
      await store.save(s);

      final File tmpFile = File('${file.path}.tmp');
      expect(await tmpFile.exists(), isFalse,
          reason: '.tmp should be renamed away on success');
      expect(await file.exists(), isTrue);
    });

    test('save creates the parent directory if missing', () async {
      final File nested = File('${tmp.path}/nested/dir/now_playing.json');
      final NowPlayingStore nestedStore = NowPlayingStore(nested);
      await nestedStore.save(const NowPlayingSnapshot(updatedAt: 1));
      expect(await nested.exists(), isTrue);
    });

    test('clear removes the file; no-op when missing', () async {
      await store.save(const NowPlayingSnapshot(updatedAt: 1));
      expect(await file.exists(), isTrue);
      await store.clear();
      expect(await file.exists(), isFalse);
      // Idempotent.
      await store.clear();
      expect(await file.exists(), isFalse);
    });
  });
}
