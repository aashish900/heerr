import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

import '../support/cred_test_support.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = <String, String>{};

  void seed(Map<String, String> values) => _data.addAll(values);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

SettingsValue _navidromeOnly() => (
      backendBaseUrl: null,
      bearerToken: null,
      navidromeBaseUrl: 'http://navi:4533',
      navidromeUsername: 'me',
      navidromePassword: 'pw',
      offlineEnabled: false,
      offlineSyncAll: false,
      offlineWifiOnly: true,
      offlinePollIntervalMin: 15, offlineChargingOnly: false,
    );

void main() {
  initPrefsMock();
  group('OfflineManifest model', () {
    test('default constructor — empty sets + empty song map', () {
      const OfflineManifest m = OfflineManifest();
      expect(m.markedAlbums, isEmpty);
      expect(m.markedPlaylists, isEmpty);
      expect(m.songs, isEmpty);
      expect(m.estimatedTotalBytes, isNull);
      expect(m.estimatedAt, isNull);
    });

    test('JSON round-trip preserves marker sets + song entries', () {
      final OfflineManifest m = OfflineManifest(
        markedAlbums: <String>{'al-1', 'al-2'},
        markedPlaylists: <String>{'pl-1'},
        songs: <String, OfflineSongEntry>{
          'so-1': OfflineSongEntry(
            state: OfflineSongState.ready,
            localPath: '/tmp/x/so-1.mp3',
            size: 4_200_000,
            suffix: 'mp3',
            downloadedAt: DateTime.utc(2026, 6, 12, 10, 30),
          ),
          'so-2': const OfflineSongEntry(
            state: OfflineSongState.failed,
            lastError: 'HTTP 404',
          ),
        },
        estimatedTotalBytes: 1_500_000_000,
        estimatedAt: DateTime.utc(2026, 6, 12, 10, 0),
      );

      final OfflineManifest back =
          OfflineManifest.fromJson(m.toJson());

      expect(back.markedAlbums, m.markedAlbums);
      expect(back.markedPlaylists, m.markedPlaylists);
      expect(back.songs.keys, m.songs.keys);
      expect(back.songs['so-1']!.state, OfflineSongState.ready);
      expect(back.songs['so-1']!.localPath, '/tmp/x/so-1.mp3');
      expect(back.songs['so-1']!.size, 4_200_000);
      expect(back.songs['so-1']!.downloadedAt, m.songs['so-1']!.downloadedAt);
      expect(back.songs['so-2']!.state, OfflineSongState.failed);
      expect(back.songs['so-2']!.lastError, 'HTTP 404');
      expect(back.estimatedTotalBytes, 1_500_000_000);
      expect(back.estimatedAt, m.estimatedAt);
    });
  });

  group('OfflineManifestStore', () {
    late Directory docsRoot;
    late OfflinePaths paths;
    late OfflineManifestStore store;

    setUp(() async {
      docsRoot = await Directory.systemTemp.createTemp('heerr-offline-mf-');
      paths = OfflinePaths(docsRoot);
      store = OfflineManifestStore(paths);
    });

    tearDown(() async {
      if (await docsRoot.exists()) await docsRoot.delete(recursive: true);
    });

    test('load on a fresh server-root returns empty manifest', () async {
      final OfflineManifest m = await store.load(_navidromeOnly());
      expect(m.markedAlbums, isEmpty);
      expect(m.songs, isEmpty);
    });

    test('save then load round-trips through disk', () async {
      const OfflineManifest m = OfflineManifest(
        markedAlbums: <String>{'al-1'},
        songs: <String, OfflineSongEntry>{
          'so-1': OfflineSongEntry(
            state: OfflineSongState.ready,
            localPath: '/abs/so-1.mp3',
            size: 1234,
          ),
        },
      );

      await store.save(_navidromeOnly(), m);
      final OfflineManifest back = await store.load(_navidromeOnly());

      expect(back.markedAlbums, m.markedAlbums);
      expect(back.songs['so-1']!.state, OfflineSongState.ready);
      expect(back.songs['so-1']!.localPath, '/abs/so-1.mp3');
      expect(back.songs['so-1']!.size, 1234);
    });

    test('save uses atomic write — no .tmp left behind on success', () async {
      const OfflineManifest m = OfflineManifest(
        markedAlbums: <String>{'al-1'},
      );
      await store.save(_navidromeOnly(), m);

      final File mf = paths.manifestFile(_navidromeOnly())!;
      final File tmp = File('${mf.path}.tmp');
      expect(await mf.exists(), isTrue);
      expect(await tmp.exists(), isFalse);
    });

    test('corrupt JSON on disk falls back to empty manifest', () async {
      // Pre-create the server-root + write garbage.
      final File mf = paths.manifestFile(_navidromeOnly())!;
      await mf.parent.create(recursive: true);
      await mf.writeAsString('{not-json,');

      final OfflineManifest m = await store.load(_navidromeOnly());
      expect(m.markedAlbums, isEmpty);
      expect(m.songs, isEmpty);
    });

    test('empty file on disk falls back to empty manifest', () async {
      final File mf = paths.manifestFile(_navidromeOnly())!;
      await mf.parent.create(recursive: true);
      await mf.writeAsString('');

      final OfflineManifest m = await store.load(_navidromeOnly());
      expect(m.markedAlbums, isEmpty);
    });

    test('save throws when Navidrome creds are missing', () async {
      const SettingsValue noCreds = (
        backendBaseUrl: null,
        bearerToken: null,
        navidromeBaseUrl: null,
        navidromeUsername: null,
        navidromePassword: null,
        offlineEnabled: false,
        offlineSyncAll: false,
        offlineWifiOnly: true,
        offlinePollIntervalMin: 15, offlineChargingOnly: false,
      );

      expect(
        () => store.save(noCreds, const OfflineManifest()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('offlineManifestProvider', () {
    test('first watch lazy-loads the on-disk manifest under the test docs dir',
        () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('heerr-mf-provider-');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final _FakeSecureStorage fake = _FakeSecureStorage()
        ..seed(<String, String>{
          'navidrome_base_url': 'http://navi:4533',
          'navidrome_username': 'me',
          'navidrome_password': 'pw',
        });

      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => fake,
          ),
          activeProfileOverride(),
          applicationDocumentsDirectoryProvider
              .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
        ],
      );
      addTearDown(c.dispose);

      // Cold read — nothing on disk → empty manifest.
      OfflineManifest m =
          await c.read(offlineManifestProvider.future);
      expect(m.markedAlbums, isEmpty);

      // Write through the store and re-read after invalidation.
      final OfflineManifestStore store =
          await c.read(offlineManifestStoreProvider.future);
      await store.save(
        await c.read(settingsProvider.future),
        const OfflineManifest(markedAlbums: <String>{'al-1'}),
      );
      c.invalidate(offlineManifestProvider);

      m = await c.read(offlineManifestProvider.future);
      expect(m.markedAlbums, <String>{'al-1'});
    });
  });
}
