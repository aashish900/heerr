import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/providers/storage_breakdown.dart';

import '../support/cred_test_support.dart';

// DL7: storage breakdown is *actual* on-disk usage (unlike
// offlineSizeEstimateProvider, which estimates a future sync-all). Music
// comes from the manifest's own size tracking; artwork/lyrics/cache are
// directory walks.

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-storage-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('dirSizeBytes', () {
    test('null directory → 0', () async {
      expect(await dirSizeBytes(null), 0);
    });

    test('missing directory → 0', () async {
      expect(await dirSizeBytes(Directory('${tmp.path}/nope')), 0);
    });

    test('sums file sizes recursively', () async {
      final Directory sub = Directory('${tmp.path}/a/b')..createSync(recursive: true);
      File('${tmp.path}/one.txt').writeAsBytesSync(List<int>.filled(10, 0));
      File('${sub.path}/two.txt').writeAsBytesSync(List<int>.filled(20, 0));

      expect(await dirSizeBytes(tmp), 30);
    });
  });

  group('storageBreakdownProvider', () {
    test('music sums ready-entry sizes from the manifest; unreadable dirs are 0',
        () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          activeProfileOverride(),
          applicationDocumentsDirectoryProvider.overrideWith((_) async => tmp),
          offlineManifestProvider.overrideWith(
            (_) async => const OfflineManifest(
              songs: <String, OfflineSongEntry>{
                's1': OfflineSongEntry(state: OfflineSongState.ready, size: 100),
                's2': OfflineSongEntry(state: OfflineSongState.ready, size: 200),
                's3': OfflineSongEntry(state: OfflineSongState.queued, size: 999),
                's4': OfflineSongEntry(state: OfflineSongState.ready),
              },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      final StorageBreakdown b = await c.read(storageBreakdownProvider.future);

      expect(b.music, 300);
      expect(b.artwork, 0);
      expect(b.lyrics, 0);
      expect(b.cache, 0);
    });

    test('artwork/lyrics/cache reflect actual files on disk', () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          activeProfileOverride(),
          applicationDocumentsDirectoryProvider.overrideWith((_) async => tmp),
          offlineManifestProvider.overrideWith((_) async => const OfflineManifest()),
        ],
      );
      addTearDown(c.dispose);

      final OfflinePaths paths = await c.read(offlinePathsProvider.future);
      final ServerCreds creds = testCreds();
      paths.coversDir(creds)!.createSync(recursive: true);
      File('${paths.coversDir(creds)!.path}/cover1.jpg')
          .writeAsBytesSync(List<int>.filled(50, 0));
      paths.lyricsDir(creds)!.createSync(recursive: true);
      File('${paths.lyricsDir(creds)!.path}/song1.json')
          .writeAsBytesSync(List<int>.filled(5, 0));

      final StorageBreakdown b = await c.read(storageBreakdownProvider.future);

      expect(b.artwork, 50);
      expect(b.lyrics, 5);
      expect(b.cache, 0);
    });
  });
}
