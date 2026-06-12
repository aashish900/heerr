import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/settings.dart';
import 'offline_paths.dart';

part 'library_cache.g.dart';

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
/// - call `networkCall`; if it succeeds, encode + write the cache, return.
/// - on any exception, attempt to read + decode the cache. Cache hit →
///   return cached value (and log it). Cache miss → rethrow the original.
///
/// Tests can override the cache via `libraryCacheProvider.overrideWith` or
/// drive both happy + degraded paths by toggling the `networkCall` body.
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
