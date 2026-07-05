import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/background_sync.dart';
import 'package:heerr/offline/offline_downloader.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/models/subsonic/lyrics.dart';
import 'package:heerr/services/lyrics_service.dart';

// ---------------------------------------------------------------------------
// Stubs (mirror offline_sync_test.dart so the Q1 test exercises the same
// surface the foreground sync is verified against).
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

class _FakeWifi implements WifiCheck {
  @override
  Future<bool> isOnWifi() async => true;

  @override
  Stream<bool> get onWifiChanged => const Stream<bool>.empty();
}

class _RecordingScheduler implements BackgroundSyncScheduler {
  final List<String> calls = <String>[];
  Constraints? lastConstraints;
  Duration? lastFrequency;

  @override
  Future<void> schedule({
    required Constraints constraints,
    required Duration frequency,
  }) async {
    calls.add('schedule');
    lastConstraints = constraints;
    lastFrequency = frequency;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }
}

class _BytesAdapter implements HttpClientAdapter {
  int requestCount = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestCount += 1;
    return ResponseBody.fromBytes(
      List<int>.filled(64, 0),
      200,
      headers: <String, List<String>>{
        'content-type': <String>['audio/mpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _buildContainer({
  required Directory tmp,
  required _BytesAdapter adapter,
  Map<String, List<Song>> albums = const <String, List<Song>>{},
}) {
  // A1: Navidrome creds come from the active profile. A5: offline prefs in
  // the (same fake) prefs store.
  final _FakeSecureStorage store = _FakeSecureStorage(<String, String>{
    'offline_enabled': 'true',
    'offline_sync_all': 'false',
    'offline_wifi_only': 'true',
    'offline_poll_interval_min': '15',
  });

  final DateTime t = DateTime.utc(2026, 6, 19);
  final Profile profile = Profile(
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

  final Dio dio = Dio()..httpClientAdapter = adapter;

  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => store),
      prefsStorageProvider.overrideWith((Ref<PrefsStorage> ref) => store),
      activeProfileProvider.overrideWith((Ref<Profile?> ref) => profile),
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
      offlineDownloadDioProvider
          .overrideWith((OfflineDownloadDioRef ref) => dio),
      wifiCheckProvider.overrideWith((WifiCheckRef ref) => _FakeWifi()),
      libraryAlbumsProvider.overrideWith(
        (Ref<AsyncValue<List<Album>>> ref) async => <Album>[
          for (final String id in albums.keys) Album(id: id, name: id),
        ],
      ),
      libraryPlaylistsProvider.overrideWith(
        (Ref<AsyncValue<List<Playlist>>> ref) async => const <Playlist>[],
      ),
      for (final MapEntry<String, List<Song>> e in albums.entries)
        libraryAlbumProvider(e.key).overrideWith(
          (Ref<AsyncValue<Album>> ref) async =>
              Album(id: e.key, name: e.key, song: e.value),
        ),
      // #26: stub the sync tick's lyrics hook — no lyrics, no network.
      lyricsServiceProvider.overrideWith(
        (Ref<AsyncValue<LyricsService>> ref) async => _NullLyricsService(),
      ),
    ],
  );
}

/// #26: no-lyrics stub so the download hook never touches real network.
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

Future<void> _seedMarker(ProviderContainer c, String albumId) async {
  final ServerCreds settings = c.read(serverCredsProvider);
  final OfflineManifestStore store =
      await c.read(offlineManifestStoreProvider.future);
  await store.save(
    settings,
    OfflineManifest(markedAlbums: <String>{albumId}),
  );
  c.invalidate(offlineManifestProvider);
}

const Song _s1 = Song(id: 'so-1', title: 't1', suffix: 'mp3');
const Song _s2 = Song(id: 'so-2', title: 't2', suffix: 'mp3');

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-bg-sync-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('runBackgroundSyncTask', () {
    test('delegates to OfflineSync.syncNow on the provided container',
        () async {
      final _BytesAdapter adapter = _BytesAdapter();
      final ProviderContainer container = _buildContainer(
        tmp: tmp,
        adapter: adapter,
        albums: <String, List<Song>>{
          'al-1': <Song>[_s1, _s2],
        },
      );
      addTearDown(container.dispose);

      await container.read(offlineSettingsProvider.future);
      await _seedMarker(container, 'al-1');

      final bool ok = await runBackgroundSyncTask(container: container);

      expect(ok, isTrue);
      // Two songs in the marked album → two HTTP requests against the
      // download dio, identical to the foreground sync path.
      expect(adapter.requestCount, 2);

      final OfflineManifest m =
          await container.read(offlineManifestProvider.future);
      expect(m.songs.length, 2);
      expect(m.songs['so-1']!.state, OfflineSongState.ready);
      expect(m.songs['so-2']!.state, OfflineSongState.ready);
    });

    test('returns false (does not throw) on container error', () async {
      // A6: creds now resolve via the synchronous `serverCredsProvider`, which
      // degrades to null on a registry miss — so a bare container no-ops to
      // `true` instead of throwing. To still exercise the infra-error → retry
      // contract, give the tick valid creds (so it passes the creds gate) but
      // make a downstream provider throw. The runner must swallow it and
      // surface a `false` retry signal.
      final DateTime t = DateTime.utc(2026, 6, 19);
      final Profile profile = Profile(
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
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          activeProfileProvider.overrideWith((Ref<Profile?> ref) => profile),
          applicationDocumentsDirectoryProvider.overrideWith(
            (ApplicationDocumentsDirectoryRef ref) async =>
                throw StateError('docs dir unavailable'),
          ),
        ],
      );
      addTearDown(c.dispose);
      final bool ok = await runBackgroundSyncTask(container: c);
      expect(ok, isFalse);
    });
  });

  group('constraintsFor', () {
    test('wifi-only + charging-only → unmetered + requiresCharging', () {
      final Constraints c =
          constraintsFor(wifiOnly: true, chargingOnly: true);
      expect(c.networkType, NetworkType.unmetered);
      expect(c.requiresCharging, isTrue);
    });

    test('wifi-only + no charging gate → unmetered + no charging required',
        () {
      final Constraints c =
          constraintsFor(wifiOnly: true, chargingOnly: false);
      expect(c.networkType, NetworkType.unmetered);
      expect(c.requiresCharging, isFalse);
    });

    test('any network + charging-only → connected + requiresCharging', () {
      final Constraints c =
          constraintsFor(wifiOnly: false, chargingOnly: true);
      expect(c.networkType, NetworkType.connected);
      expect(c.requiresCharging, isTrue);
    });

    test('any network + no charging gate → connected, no charging required',
        () {
      final Constraints c =
          constraintsFor(wifiOnly: false, chargingOnly: false);
      expect(c.networkType, NetworkType.connected);
      expect(c.requiresCharging, isFalse);
    });

    test('constraintsForSettings passes both knobs through', () {
      const OfflineSettingsValue s = (
        enabled: true,
        syncAll: false,
        wifiOnly: false,
        pollIntervalMinutes: 30,
        chargingOnly: true,
      );
      final Constraints c = constraintsForSettings(s);
      expect(c.networkType, NetworkType.connected);
      expect(c.requiresCharging, isTrue);
    });
  });

  group('backgroundIntervalMinutesFor', () {
    test('values below 15 clamp up to the WorkManager floor', () {
      expect(backgroundIntervalMinutesFor(1), 15);
      expect(backgroundIntervalMinutesFor(5), 15);
      expect(backgroundIntervalMinutesFor(14), 15);
    });

    test('15 and above pass through unchanged', () {
      expect(backgroundIntervalMinutesFor(15), 15);
      expect(backgroundIntervalMinutesFor(30), 30);
      expect(backgroundIntervalMinutesFor(60), 60);
    });
  });

  group('hasPendingSyncTargets', () {
    const OfflineSettingsValue enabledNoSyncAll = (
      enabled: true,
      syncAll: false,
      wifiOnly: true,
      pollIntervalMinutes: 30,
      chargingOnly: false,
    );
    const OfflineSettingsValue enabledSyncAll = (
      enabled: true,
      syncAll: true,
      wifiOnly: true,
      pollIntervalMinutes: 30,
      chargingOnly: false,
    );

    test('empty manifest + no sync-all → false', () {
      expect(
        hasPendingSyncTargets(
          offline: enabledNoSyncAll,
          manifest: const OfflineManifest(),
        ),
        isFalse,
      );
    });

    test('any marker → true', () {
      expect(
        hasPendingSyncTargets(
          offline: enabledNoSyncAll,
          manifest: const OfflineManifest(markedAlbums: <String>{'al-1'}),
        ),
        isTrue,
      );
      expect(
        hasPendingSyncTargets(
          offline: enabledNoSyncAll,
          manifest: const OfflineManifest(markedPlaylists: <String>{'pl-1'}),
        ),
        isTrue,
      );
      expect(
        hasPendingSyncTargets(
          offline: enabledNoSyncAll,
          manifest: const OfflineManifest(markedArtists: <String>{'ar-1'}),
        ),
        isTrue,
      );
    });

    test('sync-all bypasses the empty-manifest check', () {
      expect(
        hasPendingSyncTargets(
          offline: enabledSyncAll,
          manifest: const OfflineManifest(),
        ),
        isTrue,
      );
    });
  });

  group('lifecycle handoff', () {
    const OfflineSettingsValue onWifiOnly30 = (
      enabled: true,
      syncAll: false,
      wifiOnly: true,
      pollIntervalMinutes: 30,
      chargingOnly: false,
    );

    test('onAppForegrounded cancels and does not schedule', () async {
      final _RecordingScheduler s = _RecordingScheduler();
      await onAppForegrounded(s);
      expect(s.calls, <String>['cancel']);
    });

    test('onAppBackgrounded with offline disabled → no-op', () async {
      final _RecordingScheduler s = _RecordingScheduler();
      await onAppBackgrounded(
        scheduler: s,
        offline: const (
          enabled: false,
          syncAll: false,
          wifiOnly: true,
          pollIntervalMinutes: 30,
          chargingOnly: false,
        ),
        manifest: const OfflineManifest(markedAlbums: <String>{'al-1'}),
      );
      expect(s.calls, isEmpty);
    });

    test('onAppBackgrounded with no pending targets → no-op', () async {
      final _RecordingScheduler s = _RecordingScheduler();
      await onAppBackgrounded(
        scheduler: s,
        offline: onWifiOnly30,
        manifest: const OfflineManifest(),
      );
      expect(s.calls, isEmpty);
    });

    test('onAppBackgrounded with markers → schedule with constraints + clamp',
        () async {
      final _RecordingScheduler s = _RecordingScheduler();
      // Use a sub-15 interval to exercise the floor clamp at the same time.
      const OfflineSettingsValue underFloor = (
        enabled: true,
        syncAll: false,
        wifiOnly: true,
        pollIntervalMinutes: 5,
        chargingOnly: true,
      );
      await onAppBackgrounded(
        scheduler: s,
        offline: underFloor,
        manifest: const OfflineManifest(markedAlbums: <String>{'al-1'}),
      );
      expect(s.calls, <String>['schedule']);
      expect(s.lastFrequency, const Duration(minutes: 15));
      expect(s.lastConstraints!.networkType, NetworkType.unmetered);
      expect(s.lastConstraints!.requiresCharging, isTrue);
    });

    test('onAppBackgrounded with sync-all + empty manifest still schedules',
        () async {
      final _RecordingScheduler s = _RecordingScheduler();
      await onAppBackgrounded(
        scheduler: s,
        offline: const (
          enabled: true,
          syncAll: true,
          wifiOnly: false,
          pollIntervalMinutes: 60,
          chargingOnly: false,
        ),
        manifest: const OfflineManifest(),
      );
      expect(s.calls, <String>['schedule']);
      expect(s.lastFrequency, const Duration(minutes: 60));
      expect(s.lastConstraints!.networkType, NetworkType.connected);
      expect(s.lastConstraints!.requiresCharging, isFalse);
    });

    test('handoff order: schedule on background, cancel on next foreground',
        () async {
      final _RecordingScheduler s = _RecordingScheduler();
      await onAppBackgrounded(
        scheduler: s,
        offline: onWifiOnly30,
        manifest: const OfflineManifest(markedAlbums: <String>{'al-1'}),
      );
      await onAppForegrounded(s);
      expect(s.calls, <String>['schedule', 'cancel']);
    });
  });

  group('manifest atomic-write invariant under fg/bg contention', () {
    // Two separate containers point at the same on-disk server-key
    // (same baseUrl + username + appDocs root). Sequential syncNow() calls
    // from each container must leave the manifest in a valid state and no
    // `.tmp` file behind — the L1 atomic-write contract is the only thing
    // protecting fg + bg from corrupting each other's writes.
    test('sequential ticks from two containers leave manifest valid + no tmp',
        () async {
      final _BytesAdapter adapter1 = _BytesAdapter();
      final _BytesAdapter adapter2 = _BytesAdapter();
      final ProviderContainer fg = _buildContainer(
        tmp: tmp,
        adapter: adapter1,
        albums: <String, List<Song>>{'al-1': <Song>[_s1]},
      );
      final ProviderContainer bg = _buildContainer(
        tmp: tmp,
        adapter: adapter2,
        albums: <String, List<Song>>{'al-1': <Song>[_s1, _s2]},
      );
      addTearDown(fg.dispose);
      addTearDown(bg.dispose);

      await fg.read(offlineSettingsProvider.future);
      await bg.read(offlineSettingsProvider.future);
      await _seedMarker(fg, 'al-1');

      // Foreground tick first.
      await runBackgroundSyncTask(container: fg);

      // Background tick second — same server-key, expanded album payload.
      // Must read the manifest the fg just wrote and add the new song.
      await runBackgroundSyncTask(container: bg);

      // Resolve the on-disk manifest path the same way OfflinePaths does.
      final ServerCreds settings = bg.read(serverCredsProvider);
      final OfflinePaths paths =
          await bg.read(offlinePathsProvider.future);
      final File manifestFile = paths.manifestFile(settings)!;
      final Directory serverRoot = manifestFile.parent;

      // Invariant 1: the file exists, parses as JSON, and round-trips through
      // OfflineManifest.fromJson without throwing.
      expect(await manifestFile.exists(), isTrue);
      final Map<String, dynamic> json =
          jsonDecode(await manifestFile.readAsString())
              as Map<String, dynamic>;
      final OfflineManifest parsed = OfflineManifest.fromJson(json);
      expect(parsed.markedAlbums, contains('al-1'));
      // Bg's expanded view (two songs) is the last writer; both song entries
      // present + ready.
      expect(parsed.songs['so-1']!.state, OfflineSongState.ready);
      expect(parsed.songs['so-2']!.state, OfflineSongState.ready);

      // Invariant 2: no `.tmp` sidecar leaked from a half-finished write.
      final List<FileSystemEntity> dirEntries =
          await serverRoot.list().toList();
      final Iterable<String> names =
          dirEntries.map((FileSystemEntity e) => e.path.split('/').last);
      expect(names.any((String n) => n.endsWith('.tmp')), isFalse,
          reason: 'tmp file leaked: $names');
    });
  });
}
