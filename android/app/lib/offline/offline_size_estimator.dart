import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/subsonic/album.dart';
import '../models/subsonic/song.dart';
import '../providers/library/library_album.dart';
import '../providers/library/library_albums.dart';
import '../providers/server_creds.dart';
import 'offline_manifest.dart';

part 'offline_size_estimator.g.dart';

/// Cache TTL for the "≈ X GB" preflight shown under the "Sync entire library"
/// row in Settings. Within the TTL re-watches return the cached value from
/// the manifest instead of refiring the album walk.
const Duration _kEstimateTtl = Duration(hours: 1);

/// Walks the full library and sums `song.size` across every album. Returns
/// `null` when there are no Navidrome creds (the Settings UI shows
/// "Calculating…" while loading and "—" on null). Caches the result on the
/// manifest (`estimatedTotalBytes` + `estimatedAt`); subsequent watches
/// within [_kEstimateTtl] short-circuit on the cache.
///
/// The cache is cleared by `OfflineMarker` mutators and by
/// `OfflineSettings.setSyncAll` per the L4 spec — even though the estimate
/// value itself is independent of markers / syncAll, the spec is what the
/// roadmap froze and the cost of an extra recompute is bounded.
@Riverpod(keepAlive: true)
class OfflineSizeEstimate extends _$OfflineSizeEstimate {
  @override
  Future<int?> build() async {
    final ServerCreds settings = ref.watch(serverCredsProvider);
    if (settings.navidromeBaseUrl == null) return null;

    final OfflineManifestStore store =
        await ref.watch(offlineManifestStoreProvider.future);
    final OfflineManifest manifest = await store.load(settings);

    final DateTime? at = manifest.estimatedAt;
    final int? cached = manifest.estimatedTotalBytes;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _kEstimateTtl) {
      return cached;
    }

    return _walkAndCache(settings, store, manifest);
  }

  /// Force a recompute regardless of cache freshness. Used by the
  /// "Sync entire library" OFF→ON dialog when the user wants fresh numbers
  /// before confirming.
  Future<int?> refresh() async {
    state = const AsyncValue<int?>.loading();
    try {
      final ServerCreds settings = ref.read(serverCredsProvider);
      if (settings.navidromeBaseUrl == null) {
        state = const AsyncValue<int?>.data(null);
        return null;
      }
      final OfflineManifestStore store =
          await ref.read(offlineManifestStoreProvider.future);
      final OfflineManifest manifest = await store.load(settings);
      final int? v = await _walkAndCache(settings, store, manifest);
      state = AsyncValue<int?>.data(v);
      return v;
    } catch (e, st) {
      state = AsyncValue<int?>.error(e, st);
      rethrow;
    }
  }

  Future<int?> _walkAndCache(
    ServerCreds settings,
    OfflineManifestStore store,
    OfflineManifest manifest,
  ) async {
    int total = 0;
    try {
      final List<Album> all =
          await ref.read(libraryAlbumsProvider.future);
      for (final Album a in all) {
        try {
          final Album detail =
              await ref.read(libraryAlbumProvider(a.id).future);
          for (final Song s in detail.song) {
            final int? sz = s.size;
            if (sz != null) total += sz;
          }
        } catch (e) {
          // Skip the broken album; the user prefers an approximate number
          // to no number at all.
          debugPrint('offline_size_estimator: album ${a.id} failed: $e');
        }
      }
    } catch (e) {
      debugPrint('offline_size_estimator: library walk failed: $e');
      return null;
    }

    await store.save(
      settings,
      manifest.copyWith(
        estimatedTotalBytes: total,
        estimatedAt: DateTime.now(),
      ),
    );
    ref.invalidate(offlineManifestProvider);
    return total;
  }
}
