import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_marker.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/offline/offline_size_estimator.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

import '../support/cred_test_support.dart';

class _FakeStorage implements SecureStorage {
  _FakeStorage(this._data);
  final Map<String, String> _data;
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

ProviderContainer _container({
  required Directory tmp,
  required Map<String, List<Song>> albumStubs,
}) {
  final _FakeStorage store = _FakeStorage(<String, String>{
    'navidrome_base_url': 'http://navi:4533',
    'navidrome_username': 'me',
    'navidrome_password': 'pw',
  });
  final List<Album> albumList = <Album>[
    for (final String id in albumStubs.keys) Album(id: id, name: id),
  ];
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => store),
      activeProfileOverride(),
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
      libraryAlbumsProvider.overrideWith(
        (Ref<AsyncValue<List<Album>>> ref) async => albumList,
      ),
      for (final MapEntry<String, List<Song>> e in albumStubs.entries)
        libraryAlbumProvider(e.key).overrideWith(
          (Ref<AsyncValue<Album>> ref) async =>
              Album(id: e.key, name: e.key, song: e.value),
        ),
    ],
  );
}

void main() {
  initPrefsMock();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-size-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('sums sizes across multiple albums', () async {
    final ProviderContainer c = _container(
      tmp: tmp,
      albumStubs: <String, List<Song>>{
        'al-1': const <Song>[
          Song(id: 'so-1', title: 't1', size: 1000),
          Song(id: 'so-2', title: 't2', size: 2000),
        ],
        'al-2': const <Song>[
          Song(id: 'so-3', title: 't3', size: 3000),
        ],
      },
    );
    addTearDown(c.dispose);

    final int? total = await c.read(offlineSizeEstimateProvider.future);
    expect(total, 6000);
  });

  test('null sizes are skipped (do not break the walk)', () async {
    final ProviderContainer c = _container(
      tmp: tmp,
      albumStubs: <String, List<Song>>{
        'al-1': const <Song>[
          Song(id: 'so-1', title: 't1', size: 500),
          // No size — should be skipped, not added as 0 nor crash.
          Song(id: 'so-2', title: 't2'),
          Song(id: 'so-3', title: 't3', size: 700),
        ],
      },
    );
    addTearDown(c.dispose);

    final int? total = await c.read(offlineSizeEstimateProvider.future);
    expect(total, 1200);
  });

  test('caches result on manifest within TTL', () async {
    final ProviderContainer c = _container(
      tmp: tmp,
      albumStubs: <String, List<Song>>{
        'al-1': const <Song>[
          Song(id: 'so-1', title: 't1', size: 4321),
        ],
      },
    );
    addTearDown(c.dispose);

    final int? first = await c.read(offlineSizeEstimateProvider.future);
    expect(first, 4321);

    // Manifest should now hold the cached result.
    final SettingsValue settings =
        await c.read(settingsProvider.future);
    final OfflineManifestStore store =
        await c.read(offlineManifestStoreProvider.future);
    final OfflineManifest m = await store.load(settings);
    expect(m.estimatedTotalBytes, 4321);
    expect(m.estimatedAt, isNotNull);

    // Even if we corrupt the library override to a different size, the cache
    // should short-circuit the next read within TTL. Easiest way: invalidate
    // the estimate provider and re-read — the second read returns the cached
    // value (no walk).
    c.invalidate(offlineSizeEstimateProvider);
    final int? second = await c.read(offlineSizeEstimateProvider.future);
    expect(second, 4321);
  });

  test('marker mutation invalidates the cache', () async {
    final ProviderContainer c = _container(
      tmp: tmp,
      albumStubs: <String, List<Song>>{
        'al-1': const <Song>[
          Song(id: 'so-1', title: 't1', size: 1000),
        ],
      },
    );
    addTearDown(c.dispose);

    await c.read(offlineSizeEstimateProvider.future);

    // Mark an album — OfflineMarker clears estimatedTotalBytes / estimatedAt.
    await c.read(offlineMarkerProvider.notifier).markAlbum('al-1');

    final SettingsValue settings =
        await c.read(settingsProvider.future);
    final OfflineManifestStore store =
        await c.read(offlineManifestStoreProvider.future);
    final OfflineManifest m = await store.load(settings);
    expect(m.estimatedTotalBytes, isNull);
    expect(m.estimatedAt, isNull);
  });

  test('setSyncAll(true) invalidates the cache', () async {
    final ProviderContainer c = _container(
      tmp: tmp,
      albumStubs: <String, List<Song>>{
        'al-1': const <Song>[
          Song(id: 'so-1', title: 't1', size: 1000),
        ],
      },
    );
    addTearDown(c.dispose);

    await c.read(offlineSizeEstimateProvider.future);
    await c.read(offlineSettingsProvider.notifier).setSyncAll(true);

    final SettingsValue settings =
        await c.read(settingsProvider.future);
    final OfflineManifestStore store =
        await c.read(offlineManifestStoreProvider.future);
    final OfflineManifest m = await store.load(settings);
    expect(m.estimatedTotalBytes, isNull);
    expect(m.estimatedAt, isNull);
  });

  test('no Navidrome creds → returns null without walking', () async {
    final _FakeStorage store = _FakeStorage(<String, String>{});
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => store),
        applicationDocumentsDirectoryProvider
            .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
        // No libraryAlbumsProvider override — if the estimator walks, it
        // hits the real (unfaked) provider and the test fails because there
        // is no HTTP client. The assertion below proves the early return.
      ],
    );
    addTearDown(c.dispose);

    final int? v = await c.read(offlineSizeEstimateProvider.future);
    expect(v, isNull);
  });
}
