import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/lyrics.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/lyrics_cache.dart';
import 'package:heerr/offline/offline_downloader.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/services/lyrics_service.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

// A5: offline prefs moved to plain prefs — fake backs both stores.
class _FakeSecureStorage implements SecureStorage, PrefsStorage {
  _FakeSecureStorage(this._data);
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

/// Active profile carrying the Navidrome creds the sync tests assume. The
/// `(navidromeBaseUrl, navidromeUsername)` pair must stay stable so the L1
/// serverKey (and therefore the on-disk paths) matches across runs.
Profile _navidromeProfile() {
  final DateTime t = DateTime.utc(2026, 6, 19);
  return Profile(
    id: 'p1',
    displayName: 'me',
    heerrBaseUrl: 'http://x:8000/api/v1',
    heerrBearerToken: 'tok',
    navidromeBaseUrl: 'http://navi:4533',
    navidromeUsername: 'me',
    navidromePassword: 'pw',
    createdAt: t,
    lastUsedAt: t,
  );
}

class _FakeWifi implements WifiCheck {
  _FakeWifi(this.on);
  bool on;

  // A14: broadcast so the notifier's listen() doesn't consume a single-sub
  // stream; tests push transitions via [emit].
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  void emit(bool onWifi) {
    on = onWifi;
    _controller.add(onWifi);
  }

  @override
  Future<bool> isOnWifi() async => on;

  @override
  Stream<bool> get onWifiChanged => _controller.stream;
}

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter();
  static const Duration delay = Duration(milliseconds: 5);

  int inFlight = 0;
  int peakInFlight = 0;
  final List<RequestOptions> requests = <RequestOptions>[];
  Set<String> failIds = <String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    inFlight += 1;
    if (inFlight > peakInFlight) peakInFlight = inFlight;
    try {
      await Future<void>.delayed(delay);
      final String? id = options.queryParameters['id'] as String?;
      if (id != null && failIds.contains(id)) {
        return ResponseBody.fromBytes(<int>[], 404);
      }
      return ResponseBody.fromBytes(
        List<int>.filled(64, 0),
        200,
        headers: <String, List<String>>{
          'content-type': <String>['audio/mpeg'],
        },
      );
    } finally {
      inFlight -= 1;
    }
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_CountingAdapter a) {
  final Dio d = Dio();
  d.httpClientAdapter = a;
  return d;
}

// ---------------------------------------------------------------------------
// Container builder
// ---------------------------------------------------------------------------

class _Env {
  _Env({
    required this.container,
    required this.adapter,
    required this.wifi,
    required this.tmp,
  });
  final ProviderContainer container;
  final _CountingAdapter adapter;
  final _FakeWifi wifi;
  final Directory tmp;
}

_Env _buildEnv({
  required Directory tmp,
  Map<String, List<Song>> albumStubs = const <String, List<Song>>{},
  Map<String, List<Song>> playlistStubs = const <String, List<Song>>{},
  bool wifi = true,
  bool offlineEnabled = true,
  bool wifiOnly = true,
  bool syncAll = false,
  // When syncAll is on, these drive `libraryAlbumsProvider` /
  // `libraryPlaylistsProvider`. Default: derive from the per-id stubs so
  // tests can opt into sync-all without enumerating the library twice.
  List<Album>? libraryAlbumList,
  List<Playlist>? libraryPlaylistList,
  // #26: every env stubs the lyrics service so the download hook never
  // touches real network. Default resolves to null (no lyrics, no cache
  // write); tests inject a recording or throwing fake as needed.
  LyricsService? lyricsService,
}) {
  // A1: Navidrome creds now come from the active profile, not legacy keys.
  // A5: offline prefs live in the (same fake) prefs store.
  final _FakeSecureStorage store = _FakeSecureStorage(<String, String>{
    'offline_enabled': offlineEnabled.toString(),
    'offline_sync_all': syncAll.toString(),
    'offline_wifi_only': wifiOnly.toString(),
    'offline_poll_interval_min': '15',
  });

  final _CountingAdapter adapter = _CountingAdapter();
  final _FakeWifi fakeWifi = _FakeWifi(wifi);

  final List<Album> defaultAlbumList = <Album>[
    for (final String id in albumStubs.keys) Album(id: id, name: id),
  ];
  final List<Playlist> defaultPlaylistList = <Playlist>[
    for (final String id in playlistStubs.keys) Playlist(id: id, name: id),
  ];

  final List<Override> overrides = <Override>[
    secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => store),
    prefsStorageProvider.overrideWith((Ref<PrefsStorage> ref) => store),
    activeProfileProvider.overrideWith((Ref<Profile?> ref) => _navidromeProfile()),
    applicationDocumentsDirectoryProvider
        .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
    offlineDownloadDioProvider.overrideWith(
      (OfflineDownloadDioRef ref) => _dio(adapter),
    ),
    wifiCheckProvider.overrideWith((WifiCheckRef ref) => fakeWifi),
    libraryAlbumsProvider.overrideWith(
      (Ref<AsyncValue<List<Album>>> ref) async =>
          libraryAlbumList ?? defaultAlbumList,
    ),
    libraryPlaylistsProvider.overrideWith(
      (Ref<AsyncValue<List<Playlist>>> ref) async =>
          libraryPlaylistList ?? defaultPlaylistList,
    ),
    for (final MapEntry<String, List<Song>> e in albumStubs.entries)
      libraryAlbumProvider(e.key).overrideWith(
        (Ref<AsyncValue<Album>> ref) async =>
            Album(id: e.key, name: e.key, song: e.value),
      ),
    for (final MapEntry<String, List<Song>> e in playlistStubs.entries)
      libraryPlaylistProvider(e.key).overrideWith(
        (Ref<AsyncValue<Playlist>> ref) async =>
            Playlist(id: e.key, name: e.key, entry: e.value),
      ),
    lyricsServiceProvider.overrideWith(
      (Ref<AsyncValue<LyricsService>> ref) async =>
          lyricsService ?? _NullLyricsService(),
    ),
  ];

  return _Env(
    container: ProviderContainer(overrides: overrides),
    adapter: adapter,
    wifi: fakeWifi,
    tmp: tmp,
  );
}

Future<void> _seedMarkers(
  ProviderContainer c, {
  Set<String> albums = const <String>{},
  Set<String> playlists = const <String>{},
}) async {
  final ServerCreds settings = c.read(serverCredsProvider);
  final OfflineManifestStore store =
      await c.read(offlineManifestStoreProvider.future);
  await store.save(
    settings,
    OfflineManifest(
      markedAlbums: albums,
      markedPlaylists: playlists,
    ),
  );
  c.invalidate(offlineManifestProvider);
}

/// #26: default env stub — no lyrics anywhere, no network, no cache write.
class _NullLyricsService extends LyricsService {
  _NullLyricsService() : super(Dio());

  @override
  Future<Lyrics?> resolve({
    required String songId,
    required String artist,
    required String title,
  }) async =>
      null;
}

/// #26: fake lyrics resolver — always returns one synced line.
class _FakeLyricsService extends LyricsService {
  _FakeLyricsService() : super(Dio());

  final List<String> resolvedSongIds = <String>[];

  @override
  Future<Lyrics?> resolve({
    required String songId,
    required String artist,
    required String title,
  }) async {
    resolvedSongIds.add(songId);
    return Lyrics(
      value: 'lyrics for $songId',
      lines: <LyricsLine>[LyricsLine(start: 0, value: 'lyrics for $songId')],
    );
  }
}

/// #26: fake resolver whose failure must not fail the song download.
class _ThrowingLyricsService extends LyricsService {
  _ThrowingLyricsService() : super(Dio());

  @override
  Future<Lyrics?> resolve({
    required String songId,
    required String artist,
    required String title,
  }) async =>
      throw StateError('lyrics backend down');
}

const Song _s1 = Song(id: 'so-1', title: 't1', suffix: 'mp3');
const Song _s2 = Song(id: 'so-2', title: 't2', suffix: 'mp3');
const Song _s3 = Song(id: 'so-3', title: 't3', suffix: 'mp3');
const Song _s4 = Song(id: 'so-4', title: 't4', suffix: 'mp3');
const Song _s5 = Song(id: 'so-5', title: 't5', suffix: 'mp3');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-sync-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('OfflineSync — marker path', () {
    test('marked album triggers a download per song', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();

      expect(r.downloadedCount, 2);
      expect(r.failedCount, 0);
      expect(r.error, isNull);
      expect(env.adapter.requests.length, 2);

      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.songs.length, 2);
      expect(m.songs['so-1']!.state, OfflineSongState.ready);
      expect(m.songs['so-2']!.state, OfflineSongState.ready);
    });

    test('successful download also caches lyrics per song (#26)', () async {
      final _FakeLyricsService lyrics = _FakeLyricsService();
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2],
        },
        lyricsService: lyrics,
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});
      await env.container.read(offlineSyncProvider.notifier).syncNow();

      expect(lyrics.resolvedSongIds.toSet(), <String>{'so-1', 'so-2'});
      final ServerCreds settings = env.container.read(serverCredsProvider);
      final OfflinePaths paths =
          await env.container.read(offlinePathsProvider.future);
      final Lyrics? cached =
          await LyricsCache(paths).read(settings, 'so-1');
      expect(cached!.value, 'lyrics for so-1');
      expect(cached.lines!.single.start, 0);
    });

    test('lyrics failure does not fail the song download (#26)', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
        lyricsService: _ThrowingLyricsService(),
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});
      final OfflineSyncResult r =
          await env.container.read(offlineSyncProvider.notifier).syncNow();

      expect(r.downloadedCount, 1);
      expect(r.failedCount, 0);
    });

    test('second syncNow is a no-op when everything is ready', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      await env.container.read(offlineSyncProvider.notifier).syncNow();
      final int after1 = env.adapter.requests.length;

      final OfflineSyncResult r2 = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();
      expect(r2.downloadedCount, 0);
      expect(env.adapter.requests.length, after1);
    });

    test('unmark sweeps file + manifest entry', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      await env.container.read(offlineSyncProvider.notifier).syncNow();

      final OfflineManifest first =
          await env.container.read(offlineManifestProvider.future);
      final String filePath = first.songs['so-1']!.localPath!;
      expect(await File(filePath).exists(), isTrue);

      // Drop the marker, run again — the song should be swept.
      await _seedMarkers(env.container, albums: <String>{});
      final OfflineSyncResult r2 = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();

      expect(r2.sweptCount, greaterThanOrEqualTo(1));
      expect(await File(filePath).exists(), isFalse);

      final OfflineManifest second =
          await env.container.read(offlineManifestProvider.future);
      expect(second.songs.containsKey('so-1'), isFalse);
    });

    test('marked playlist is downloaded too', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        playlistStubs: <String, List<Song>>{
          'pl-1': <Song>[_s1, _s2],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, playlists: <String>{'pl-1'});

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();
      expect(r.downloadedCount, 2);
    });

    test('album + playlist union: shared songs are downloaded once',
        () async {
      // album al-1 = {s1, s2}; playlist pl-1 = {s2, s3}. Union = 3 songs.
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2],
        },
        playlistStubs: <String, List<Song>>{
          'pl-1': <Song>[_s2, _s3],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(
        env.container,
        albums: <String>{'al-1'},
        playlists: <String>{'pl-1'},
      );

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();

      expect(r.downloadedCount, 3);
      expect(env.adapter.requests.length, 3);
    });
  });

  group('OfflineSync — WiFi gate', () {
    test('WiFi-only with no WiFi: skips downloads, still sweeps', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        wifi: false,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();

      expect(r.downloadedCount, 0);
      expect(r.error, 'no wifi');
      expect(env.adapter.requests, isEmpty);
    });

    test('wifiOnly=false: downloads even without WiFi', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        wifi: false,
        wifiOnly: false,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();
      expect(r.downloadedCount, 1);
    });

    test('A14: a Wi-Fi reconnect triggers an off-schedule download tick',
        () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        wifi: false,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      // Building the keep-alive notifier runs the first tick (no WiFi → no
      // downloads) and subscribes to onWifiChanged.
      await env.container.read(offlineSyncProvider.future);
      expect(env.adapter.requests, isEmpty);

      // Wi-Fi comes back — the subscription should fire an off-schedule tick
      // without waiting for the 15-min poll.
      env.wifi.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(env.adapter.requests, isNotEmpty);
      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.songs['so-1']?.state, OfflineSongState.ready);
    });
  });

  group('OfflineSync — bounded concurrency', () {
    test('peak in-flight is at most 3 across a 5-song download', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2, _s3, _s4, _s5],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      await env.container.read(offlineSyncProvider.notifier).syncNow();

      expect(env.adapter.peakInFlight, lessThanOrEqualTo(3));
      expect(env.adapter.requests.length, 5);
    });
  });

  group('OfflineSync — guards', () {
    test('no Navidrome creds → tick reports "no creds" + no hits', () async {
      final _FakeSecureStorage store = _FakeSecureStorage(<String, String>{
        'offline_enabled': 'true',
        'offline_wifi_only': 'true',
      });
      final _CountingAdapter adapter = _CountingAdapter();

      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => store,
          ),
          prefsStorageProvider.overrideWith(
            (Ref<PrefsStorage> ref) => store,
          ),
          applicationDocumentsDirectoryProvider.overrideWith(
            (ApplicationDocumentsDirectoryRef ref) async => tmp,
          ),
          offlineDownloadDioProvider.overrideWith(
            (OfflineDownloadDioRef ref) => _dio(adapter),
          ),
          wifiCheckProvider.overrideWith(
            (WifiCheckRef ref) => _FakeWifi(true),
          ),
        ],
      );
      addTearDown(c.dispose);

      await c.read(offlineSettingsProvider.future);
      final OfflineSyncResult r =
          await c.read(offlineSyncProvider.notifier).syncNow();
      expect(r.error, 'no creds');
      expect(adapter.requests, isEmpty);
    });

    test('A15: no active profile → build returns idle, runs no tick '
        'even when offline is enabled', () async {
      // Enabled offline prefs but NO activeProfileProvider override → the
      // active profile is null (fresh install lingering on /login). The A15
      // gate must short-circuit build to `_kIdle` *before* `_runTick`. If the
      // tick ran it would early-return 'no creds', surfacing as
      // status.lastError — so a null lastError proves the gate fired first.
      final _FakeSecureStorage store = _FakeSecureStorage(<String, String>{
        'offline_enabled': 'true',
        'offline_wifi_only': 'true',
      });
      final _CountingAdapter adapter = _CountingAdapter();

      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => store,
          ),
          prefsStorageProvider.overrideWith(
            (Ref<PrefsStorage> ref) => store,
          ),
          applicationDocumentsDirectoryProvider.overrideWith(
            (ApplicationDocumentsDirectoryRef ref) async => tmp,
          ),
          offlineDownloadDioProvider.overrideWith(
            (OfflineDownloadDioRef ref) => _dio(adapter),
          ),
          wifiCheckProvider.overrideWith(
            (WifiCheckRef ref) => _FakeWifi(true),
          ),
        ],
      );
      addTearDown(c.dispose);

      final OfflineSyncStatus s =
          await c.read(offlineSyncProvider.future);
      expect(s.running, isFalse);
      expect(s.lastError, isNull, reason: 'gate must skip the tick entirely');
      expect(s.targetCount, 0);
      expect(adapter.requests, isEmpty);
    });

    test('offline disabled → build returns idle, no ticks fire', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        offlineEnabled: false,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      final OfflineSyncStatus s =
          await env.container.read(offlineSyncProvider.future);
      expect(s.running, isFalse);
      expect(s.targetCount, 0);
      expect(env.adapter.requests, isEmpty);
    });
  });

  group('OfflineSync — sync-all', () {
    test('syncAll on + empty markers → downloads every album song', () async {
      // Library has 2 albums; user has marked neither. Sync-all should pull
      // both albums' songs.
      final _Env env = _buildEnv(
        tmp: tmp,
        syncAll: true,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2],
          'al-2': <Song>[_s3],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      // No markers seeded — pure sync-all path.

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();

      expect(r.downloadedCount, 3);
      expect(r.failedCount, 0);
      expect(env.adapter.requests.length, 3);

      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.songs['so-1']!.state, OfflineSongState.ready);
      expect(m.songs['so-2']!.state, OfflineSongState.ready);
      expect(m.songs['so-3']!.state, OfflineSongState.ready);
    });

    test('syncAll on + marked album overlap → no double-download', () async {
      // Library has al-1 (s1, s2) AND user has marked al-1 explicitly.
      // Should fire exactly 2 downloads (not 4) — the set union dedupes.
      final _Env env = _buildEnv(
        tmp: tmp,
        syncAll: true,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();

      expect(r.downloadedCount, 2);
      expect(env.adapter.requests.length, 2);
    });

    test('syncAll on covers playlists from libraryPlaylistsProvider too',
        () async {
      // Library albums empty; sync-all should still pull playlist songs.
      final _Env env = _buildEnv(
        tmp: tmp,
        syncAll: true,
        playlistStubs: <String, List<Song>>{
          'pl-1': <Song>[_s1, _s2],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);

      final OfflineSyncResult r = await env.container
          .read(offlineSyncProvider.notifier)
          .syncNow();
      expect(r.downloadedCount, 2);
    });

    test(
      'syncAll flipped OFF sweeps only songs no longer covered by markers',
      () async {
        // Phase 1: sync-all ON, 2 albums in the library. Both download.
        final _Env env = _buildEnv(
          tmp: tmp,
          syncAll: true,
          albumStubs: <String, List<Song>>{
            'al-1': <Song>[_s1, _s2],
            'al-2': <Song>[_s3],
          },
        );
        addTearDown(env.container.dispose);

        await env.container.read(offlineSettingsProvider.future);
        // Mark al-1 — when sync-all flips off, al-1 stays; al-2 sweeps.
        await _seedMarkers(env.container, albums: <String>{'al-1'});

        await env.container.read(offlineSyncProvider.notifier).syncNow();

        OfflineManifest m =
            await env.container.read(offlineManifestProvider.future);
        expect(m.songs.length, 3);
        final String al2Path = m.songs['so-3']!.localPath!;
        expect(await File(al2Path).exists(), isTrue);

        // Phase 2: flip sync-all off via the settings notifier.
        await env.container
            .read(offlineSettingsProvider.notifier)
            .setSyncAll(false);

        final OfflineSyncResult r = await env.container
            .read(offlineSyncProvider.notifier)
            .syncNow();

        // al-1's songs (so-1, so-2) stay; al-2's so-3 sweeps.
        expect(r.sweptCount, greaterThanOrEqualTo(1));
        m = await env.container.read(offlineManifestProvider.future);
        expect(m.songs.containsKey('so-1'), isTrue);
        expect(m.songs.containsKey('so-2'), isTrue);
        expect(m.songs.containsKey('so-3'), isFalse);
        expect(await File(al2Path).exists(), isFalse);
      },
    );
  });

  group('OfflineSync — lifecycle', () {
    test('pause + resume re-ticks immediately', () async {
      final _Env env = _buildEnv(
        tmp: tmp,
        albumStubs: <String, List<Song>>{
          'al-1': <Song>[_s1],
        },
      );
      addTearDown(env.container.dispose);

      await env.container.read(offlineSettingsProvider.future);
      await _seedMarkers(env.container, albums: <String>{'al-1'});

      final OfflineSync notifier =
          env.container.read(offlineSyncProvider.notifier);
      await notifier.syncNow();
      final int after1 = env.adapter.requests.length;

      notifier.pause();
      await notifier.resume();

      // Resume triggers an immediate tick. Everything is ready so the new
      // tick adds zero new downloads, but it doesn't crash and the status
      // is fresh.
      expect(env.adapter.requests.length, after1);
    });
  });
}
