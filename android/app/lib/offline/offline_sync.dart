import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/profile.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/artist.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../providers/library/library_album.dart';
import '../providers/library/library_albums.dart';
import '../providers/library/library_artist.dart';
import '../providers/library/library_playlist.dart';
import '../providers/library/library_playlists.dart';
import '../providers/profiles/active_profile.dart';
import '../providers/server_creds.dart';
import 'offline_downloader.dart';
import 'offline_manifest.dart';
import 'offline_paths.dart';
import 'offline_settings.dart';

part 'offline_sync.g.dart';

/// Bounded parallelism for per-tick downloads — keep the device responsive
/// during a sync-all. See ROADMAP L2 §3.
const int _kDownloadConcurrency = 3;

/// Status snapshot the UI watches. `running` is true while a tick (manual or
/// scheduled) is in flight; the counts/lastError stay populated between ticks
/// for the Settings storage-line + diagnostic snackbars.
typedef OfflineSyncStatus = ({
  bool running,
  int targetCount,
  int readyCount,
  int failedCount,
  String? lastError,
  DateTime? lastTickAt,
});

const OfflineSyncStatus _kIdle = (
  running: false,
  targetCount: 0,
  readyCount: 0,
  failedCount: 0,
  lastError: null,
  lastTickAt: null,
);

/// Per-tick result returned by [OfflineSync.syncNow]. The UI uses this to
/// emit a "Synced N songs" or "Failed: …" snackbar.
typedef OfflineSyncResult = ({
  int downloadedCount,
  int failedCount,
  int sweptCount,
  String? error,
});

/// Tiny wrapper around `connectivity_plus` so tests don't need to fake
/// the full `Connectivity` interface (its `onConnectivityChanged` stream
/// adds noise). Production impl delegates to the real package; tests
/// substitute a one-method fake via `wifiCheckProvider.overrideWithValue`.
abstract class WifiCheck {
  Future<bool> isOnWifi();
}

class _ConnectivityPlusWifiCheck implements WifiCheck {
  @override
  Future<bool> isOnWifi() async {
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
}

@Riverpod(keepAlive: true)
WifiCheck wifiCheck(WifiCheckRef ref) => _ConnectivityPlusWifiCheck();

/// Foreground polling interval. Reads from [offlineSettingsProvider] so the
/// user-facing Settings dropdown drives it directly.
Duration _intervalFromMinutes(int minutes) =>
    Duration(minutes: minutes < 1 ? 1 : minutes);

/// Reconciles the on-disk song set against the markers (or — at L4 — the
/// full library when sync-all is on). Owns its own Timer; pause()/resume()
/// is driven from `_ShellScaffold` (L3).
@Riverpod(keepAlive: true)
class OfflineSync extends _$OfflineSync {
  Timer? _timer;
  bool _paused = false;
  bool _running = false;

  @override
  Future<OfflineSyncStatus> build() async {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    // A dependency change (profile switch, settings toggle) re-runs build on
    // the same keep-alive notifier instance, so cancel any Timer left over
    // from the previous build before deciding whether to schedule a new one.
    _timer?.cancel();
    _timer = null;

    // A15: gate on an active profile. On a fresh install the user lingers on
    // /login with no creds and no per-server offline state — ticking there is
    // wasted work (every `_runTick` would early-return 'no creds'). Watching
    // the active profile rebuilds this provider the moment the user logs in,
    // at which point the enabled-check + first tick run normally.
    final Profile? active = ref.watch(activeProfileProvider);
    if (active == null) {
      return _kIdle;
    }

    final OfflineSettingsValue settings =
        await ref.watch(offlineSettingsProvider.future);
    if (!settings.enabled) {
      // Master switch OFF — no ticks, idle status.
      return _kIdle;
    }

    final OfflineSyncResult first = await _runTick();
    _scheduleNext();
    return _statusFromResult(first, await _countsFromManifest());
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    await _tick();
  }

  /// Manual "Sync now" trigger from Settings. Returns the per-tick result so
  /// the caller can show a snackbar without re-reading the status field.
  Future<OfflineSyncResult> syncNow() async {
    final OfflineSyncResult r = await _runTick();
    state = AsyncValue<OfflineSyncStatus>.data(
      _statusFromResult(r, await _countsFromManifest()),
    );
    _scheduleNext();
    return r;
  }

  void _scheduleNext() {
    if (_paused) return;
    _timer?.cancel();
    final int minutes = ref
            .read(offlineSettingsProvider)
            .valueOrNull
            ?.pollIntervalMinutes ??
        15;
    _timer = Timer(_intervalFromMinutes(minutes), _tick);
  }

  Future<void> _tick() async {
    if (_paused) return;
    final OfflineSyncResult r = await _runTick();
    state = AsyncValue<OfflineSyncStatus>.data(
      _statusFromResult(r, await _countsFromManifest()),
    );
    _scheduleNext();
  }

  /// One reconciliation pass. Returns counts + an `error` string for the
  /// fail-fast cases ("no creds" / "no wifi"). Per-song failures don't stop
  /// the tick — they land in the manifest's `lastError` and `failedCount`.
  Future<OfflineSyncResult> _runTick() async {
    if (_running) {
      // Re-entrant call (e.g. syncNow during a scheduled tick) — bail out.
      return const (
        downloadedCount: 0,
        failedCount: 0,
        sweptCount: 0,
        error: 'sync already running',
      );
    }
    _running = true;
    try {
      final ServerCreds settings = ref.read(serverCredsProvider);
      if (settings.navidromeBaseUrl == null ||
          settings.navidromeUsername == null ||
          settings.navidromePassword == null) {
        return const (
          downloadedCount: 0,
          failedCount: 0,
          sweptCount: 0,
          error: 'no creds',
        );
      }

      final OfflinePaths paths =
          await ref.read(offlinePathsProvider.future);
      final OfflineManifestStore store =
          await ref.read(offlineManifestStoreProvider.future);
      final OfflineManifest currentManifest = await store.load(settings);

      // Offline-settings snapshot used by both target resolution (syncAll)
      // and the WiFi gate below.
      final OfflineSettingsValue offline =
          ref.read(offlineSettingsProvider).valueOrNull ??
              (
                enabled: false,
                syncAll: false,
                wifiOnly: true,
                pollIntervalMinutes: 15,
                chargingOnly: false,
              );

      // Resolve target song set. Markers + (optionally) sync-all enumeration.
      final Map<String, Song> targets =
          await _resolveTargets(currentManifest, offline);
      final Set<String> targetIds = targets.keys.toSet();

      // Sweep first — removes stale files even if downloads are gated on
      // WiFi later in the tick. The user wants unmarks (or sync-all OFF) to
      // take effect even without WiFi.
      final ({Map<String, OfflineSongEntry> songs, int sweptCount}) swept =
          await _sweepUnreferenced(
        paths: paths,
        settings: settings,
        manifestSongs: currentManifest.songs,
        targetIds: targetIds,
      );
      Map<String, OfflineSongEntry> songsState = swept.songs;

      // WiFi gate.
      if (offline.wifiOnly) {
        final bool wifi = await ref.read(wifiCheckProvider).isOnWifi();
        if (!wifi) {
          // Persist the sweep but skip downloads.
          await store.save(
            settings,
            currentManifest.copyWith(songs: songsState),
          );
          ref.invalidate(offlineManifestProvider);
          return (
            downloadedCount: 0,
            failedCount: 0,
            sweptCount: swept.sweptCount,
            error: 'no wifi',
          );
        }
      }

      // Pick songs to download — anything not yet `ready`.
      final List<Song> toDownload = <Song>[];
      for (final String id in targetIds) {
        final OfflineSongEntry? entry = songsState[id];
        if (entry == null || entry.state != OfflineSongState.ready) {
          toDownload.add(targets[id]!);
        }
      }

      int downloadedCount = 0;
      int failedCount = 0;

      if (toDownload.isNotEmpty) {
        final Dio dio = ref.read(offlineDownloadDioProvider);
        final List<Future<void>> workers =
            List<Future<void>>.generate(_kDownloadConcurrency, (_) async {
          while (true) {
            Song? next;
            if (toDownload.isNotEmpty) {
              next = toDownload.removeAt(0);
            }
            if (next == null) return;
            final OfflineSongEntry result = await downloadSong(
              song: next,
              settings: settings,
              paths: paths,
              downloadDio: dio,
            );
            songsState = <String, OfflineSongEntry>{
              ...songsState,
              next.id: result,
            };
            if (result.state == OfflineSongState.ready) {
              downloadedCount += 1;
            } else {
              failedCount += 1;
            }
          }
        });
        await Future.wait(workers);
      }

      await store.save(
        settings,
        currentManifest.copyWith(songs: songsState),
      );
      ref.invalidate(offlineManifestProvider);

      return (
        downloadedCount: downloadedCount,
        failedCount: failedCount,
        sweptCount: swept.sweptCount,
        error: null,
      );
    } catch (e, st) {
      debugPrint('offline_sync: tick failed: $e');
      debugPrintStack(stackTrace: st);
      return (
        downloadedCount: 0,
        failedCount: 0,
        sweptCount: 0,
        error: 'tick error: $e',
      );
    } finally {
      _running = false;
    }
  }

  /// Resolve marker ids (and — when `offline.syncAll` is on — every library
  /// album + playlist) into the full Song objects we need to download.
  ///
  /// Dedup is by the returned map's key (`song.id`), so a song that lives in
  /// both a marked album and a marked playlist (or in the full-library walk
  /// when sync-all is on) lands in `out` exactly once.
  Future<Map<String, Song>> _resolveTargets(
    OfflineManifest manifest,
    OfflineSettingsValue offline,
  ) async {
    // Union marker ids with the full-library enumeration when sync-all is on.
    final Set<String> albumIds = <String>{...manifest.markedAlbums};
    final Set<String> playlistIds = <String>{...manifest.markedPlaylists};

    // L7: a `markedArtist` expands to every album the artist currently
    // has. New albums released by a marked artist get picked up on the
    // next tick — that's the entire reason artists are tracked as their
    // own set rather than fanned out at mark time.
    for (final String artistId in manifest.markedArtists) {
      try {
        final Artist artist =
            await ref.read(libraryArtistProvider(artistId).future);
        for (final Album a in artist.album) {
          albumIds.add(a.id);
        }
      } catch (e) {
        debugPrint('offline_sync: resolve artist $artistId failed: $e');
      }
    }

    if (offline.syncAll) {
      try {
        final List<Album> all =
            await ref.read(libraryAlbumsProvider.future);
        for (final Album a in all) {
          albumIds.add(a.id);
        }
      } catch (e) {
        // A library-list failure shouldn't strand individually-marked items.
        debugPrint('offline_sync: enumerate library albums failed: $e');
      }
      try {
        final List<Playlist> all =
            await ref.read(libraryPlaylistsProvider.future);
        for (final Playlist p in all) {
          playlistIds.add(p.id);
        }
      } catch (e) {
        debugPrint('offline_sync: enumerate library playlists failed: $e');
      }
    }

    final Map<String, Song> out = <String, Song>{};

    for (final String albumId in albumIds) {
      try {
        final Album album =
            await ref.read(libraryAlbumProvider(albumId).future);
        for (final Song s in album.song) {
          out[s.id] = s;
        }
      } catch (e) {
        // Tolerate a single album resolution failure — other markers still sync.
        debugPrint('offline_sync: resolve album $albumId failed: $e');
      }
    }

    for (final String playlistId in playlistIds) {
      try {
        final Playlist p =
            await ref.read(libraryPlaylistProvider(playlistId).future);
        for (final Song s in p.entry) {
          out[s.id] = s;
        }
      } catch (e) {
        debugPrint('offline_sync: resolve playlist $playlistId failed: $e');
      }
    }

    return out;
  }

  /// Delete `songs/*` files + manifest entries that the target set no longer
  /// references. Returns the updated song map + the swept-file count.
  Future<({Map<String, OfflineSongEntry> songs, int sweptCount})>
      _sweepUnreferenced({
    required OfflinePaths paths,
    required ServerCreds settings,
    required Map<String, OfflineSongEntry> manifestSongs,
    required Set<String> targetIds,
  }) async {
    final Directory? songsDir = paths.songsDir(settings);
    int sweptCount = 0;
    final Map<String, OfflineSongEntry> next =
        <String, OfflineSongEntry>{...manifestSongs};

    // 1) Drop manifest entries no longer in the target set + delete their file.
    final List<String> toRemove = <String>[];
    for (final MapEntry<String, OfflineSongEntry> e in next.entries) {
      if (!targetIds.contains(e.key)) {
        toRemove.add(e.key);
        final String? path = e.value.localPath;
        if (path != null) {
          try {
            final File f = File(path);
            if (await f.exists()) {
              await f.delete();
              sweptCount += 1;
            }
          } catch (_) {
            // Don't fail the tick on a stale-file delete error.
          }
        }
      }
    }
    for (final String id in toRemove) {
      next.remove(id);
    }

    // 2) Orphan-file sweep: a file on disk whose songId isn't in target +
    //    isn't tracked by the manifest (e.g. left over from a crash). Best-
    //    effort — failure to scan is non-fatal.
    if (songsDir != null) {
      try {
        if (await songsDir.exists()) {
          await for (final FileSystemEntity ent in songsDir.list()) {
            if (ent is! File) continue;
            final String basename = ent.path.split('/').last;
            final int dot = basename.lastIndexOf('.');
            final String songId =
                dot > 0 ? basename.substring(0, dot) : basename;
            // Skip in-flight .partial files — the downloader owns them.
            if (basename.endsWith('.partial')) continue;
            if (!targetIds.contains(songId)) {
              try {
                await ent.delete();
                sweptCount += 1;
              } catch (_) {/* ignored */}
            }
          }
        }
      } catch (e) {
        debugPrint('offline_sync: songsDir scan failed: $e');
      }
    }

    return (songs: next, sweptCount: sweptCount);
  }

  Future<({int readyCount, int failedCount, int targetCount})>
      _countsFromManifest() async {
    final ServerCreds settings = ref.read(serverCredsProvider);
    if (settings.navidromeBaseUrl == null) {
      return (readyCount: 0, failedCount: 0, targetCount: 0);
    }
    final OfflineManifestStore store =
        await ref.read(offlineManifestStoreProvider.future);
    final OfflineManifest m = await store.load(settings);
    int ready = 0;
    int failed = 0;
    for (final OfflineSongEntry e in m.songs.values) {
      if (e.state == OfflineSongState.ready) ready += 1;
      if (e.state == OfflineSongState.failed) failed += 1;
    }
    return (
      readyCount: ready,
      failedCount: failed,
      targetCount: m.songs.length,
    );
  }

  OfflineSyncStatus _statusFromResult(
    OfflineSyncResult r,
    ({int readyCount, int failedCount, int targetCount}) counts,
  ) {
    return (
      running: false,
      targetCount: counts.targetCount,
      readyCount: counts.readyCount,
      failedCount: counts.failedCount,
      lastError: r.error,
      lastTickAt: DateTime.now(),
    );
  }
}
