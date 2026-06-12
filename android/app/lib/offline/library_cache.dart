import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/settings.dart';
import 'offline_paths.dart';

part 'library_cache.g.dart';

/// Lightweight connectivity probe used by [cacheAware] to short-circuit
/// the network call when the device is clearly offline — without it, the
/// wrapper would wait the full Dio connection timeout (~30–60s) before
/// falling through to the on-disk cache, which makes offline Library
/// navigation feel broken even when every screen has a cached payload.
///
/// Production impl maps `connectivity_plus` to a single boolean: wifi,
/// mobile, or ethernet → online. Tests can override
/// [onlineCheckProvider] with a fake — the abstraction is a one-method
/// interface so they don't have to mock the full Connectivity class. When
/// the probe itself throws (no platform binding in flutter_tester), the
/// wrapper assumes online so existing tests keep their behaviour.
abstract class OnlineCheck {
  Future<bool> isLikelyOnline();
}

class _ConnectivityPlusOnlineCheck implements OnlineCheck {
  @override
  Future<bool> isLikelyOnline() async {
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn);
  }
}

@Riverpod(keepAlive: true)
OnlineCheck onlineCheck(OnlineCheckRef ref) => _ConnectivityPlusOnlineCheck();

/// Per-server JSON-on-disk cache for Subsonic library responses (L5).
///
/// Stores one file per logical key under
/// `<offlineRoot>/<server-key>/library_cache/<key>.json`. The cache is
/// **navigation-only** — it powers the Library / Artist / Album / Playlist
/// screens when the backend is unreachable. Playback still goes through the
/// L2 manifest (`OfflineSongEntry.localPath`) or the L1 stream URL.
///
/// Cache hits are silent — the UI doesn't know if the data is fresh or
/// cached. The freshness contract is "prefer live, fall back to cache":
/// every successful API call overwrites the cache; the cache is only read
/// when the live call fails.
///
/// No TTL. The home-server reality is single-source so a stale-by-days
/// cache is preferable to "library blank" for the user. The next online
/// browse rewrites the file.
class LibraryCache {
  LibraryCache(this._paths);

  final OfflinePaths _paths;

  /// Returns the cached value as a `Map<String, dynamic>` (typical Subsonic
  /// response shape), or `null` when there's no cache file or it's corrupt.
  /// Never throws — corrupt cache is reported via [debugPrint] and degrades
  /// to a cache miss.
  Future<Map<String, dynamic>?> read(
    SettingsValue settings,
    String key,
  ) async {
    final File? file = _paths.libraryCacheFile(settings, key);
    if (file == null) return null;
    if (!await file.exists()) return null;
    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final dynamic json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return json;
    } catch (e, st) {
      debugPrint('library_cache: corrupt JSON for $key, miss: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  /// Atomic write via tmp-file + rename. Caller passes a JSON-serializable
  /// `Map<String, dynamic>`. No-op when Navidrome creds are missing.
  Future<void> write(
    SettingsValue settings,
    String key,
    Map<String, dynamic> value,
  ) async {
    final File? file = _paths.libraryCacheFile(settings, key);
    if (file == null) return;
    await file.parent.create(recursive: true);
    final File tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(file.path);
  }
}

@Riverpod(keepAlive: true)
Future<LibraryCache> libraryCache(LibraryCacheRef ref) async {
  final OfflinePaths paths = await ref.watch(offlinePathsProvider.future);
  return LibraryCache(paths);
}

/// Generic "try network, fall back to cache" wrapper used by each
/// `library*Provider`. The encode/decode hop lets us cache Freezed models
/// without forcing every caller to write boilerplate.
///
/// Contract:
/// 1. Probe [onlineCheckProvider]. If it reports offline AND we have a
///    cached value, return the cached value immediately — no network
///    call. This is the load-bearing change: without it, an offline
///    Library tap waits the full Dio connection timeout before
///    falling through to the cache, which feels broken (~1 minute per
///    screen on the user's Pixel).
/// 2. If online, call `networkCall`. On success → encode + write the
///    cache + return. On failure → fall through to the cache (same as
///    before).
/// 3. If offline AND no cache, throw immediately — don't burn 30s on a
///    network call that has no chance of succeeding.
///
/// The probe itself is best-effort. Any exception from
/// [OnlineCheck.isLikelyOnline] (e.g. no platform binding under
/// flutter_tester) is treated as "assume online" so the wrapper
/// degrades to the pre-fast-path behaviour.
Future<T> cacheAware<T>({
  required Ref<Object?> ref,
  required String cacheKey,
  required Future<T> Function() networkCall,
  required Map<String, dynamic> Function(T value) encode,
  required T Function(Map<String, dynamic> json) decode,
}) async {
  // Cache + settings are best-effort. If either is unreachable (no
  // path_provider in tests, no Navidrome creds yet), proceed without it —
  // the user just gets the original online-only behavior. This keeps the
  // wrapper a pure side-effect layer over the existing provider contract.
  SettingsValue? settings;
  LibraryCache? cache;
  try {
    settings = await ref.read(settingsProvider.future);
    cache = await ref.read(libraryCacheProvider.future);
  } catch (e) {
    debugPrint('library_cache: infra unavailable, bypassing for $cacheKey: $e');
  }

  // Connectivity probe. Default to "online" on any failure so existing
  // tests + the edge case where connectivity_plus refuses to answer don't
  // silently break navigation.
  bool likelyOnline = true;
  try {
    final OnlineCheck check = ref.read(onlineCheckProvider);
    likelyOnline = await check.isLikelyOnline();
  } catch (e) {
    debugPrint('library_cache: online probe failed, assuming online: $e');
  }

  // Offline fast path: serve cached → instant. No cached → fail fast so
  // the UI surfaces an error in ms, not after a 30s Dio timeout.
  if (!likelyOnline && cache != null && settings != null) {
    final Map<String, dynamic>? cached = await cache.read(settings, cacheKey);
    if (cached != null) {
      try {
        final T value = decode(cached);
        debugPrint('library_cache: offline → cache hit for $cacheKey');
        return value;
      } catch (decodeErr) {
        debugPrint(
          'library_cache: offline → cached $cacheKey failed to decode '
          '($decodeErr); falling through to network attempt',
        );
      }
    } else {
      throw const _OfflineNoCacheException();
    }
  }

  try {
    final T value = await networkCall();
    if (cache != null && settings != null) {
      try {
        await cache.write(settings, cacheKey, encode(value));
      } catch (e) {
        debugPrint('library_cache: write $cacheKey failed: $e');
      }
    }
    return value;
  } catch (e) {
    if (cache == null || settings == null) rethrow;
    final Map<String, dynamic>? cached = await cache.read(settings, cacheKey);
    if (cached != null) {
      try {
        final T value = decode(cached);
        debugPrint('library_cache: serving $cacheKey from cache: $e');
        return value;
      } catch (decodeErr) {
        debugPrint(
          'library_cache: decode $cacheKey failed ($decodeErr), '
          'falling through to original error',
        );
      }
    }
    rethrow;
  }
}

/// Thrown when the device is offline and no cached value exists for the
/// requested key. Library providers surface this as a normal error — the
/// UI's existing API-error handlers render it the same way as a real
/// network failure, just without the multi-second hang.
class _OfflineNoCacheException implements Exception {
  const _OfflineNoCacheException();
  @override
  String toString() =>
      'OfflineNoCache: device is offline and nothing is cached yet';
}
