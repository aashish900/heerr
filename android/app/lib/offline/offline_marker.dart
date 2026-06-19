import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/server_creds.dart';
import 'offline_manifest.dart';

part 'offline_marker.g.dart';

/// Mark / unmark albums + playlists for offline sync.
///
/// Mutations write through [OfflineManifestStore] and invalidate
/// [offlineManifestProvider] so the next reader sees the change. The size
/// estimate cache (L4 — `estimatedTotalBytes` / `estimatedAt`) is cleared on
/// every marker change so the Settings screen doesn't show a stale "≈ 1.2
/// GB" after the user adds another album.
///
/// `OfflineSync` (L2.4) is invalidated indirectly via the manifest watch;
/// `OfflineSync.syncNow()` is the manual trigger if the user wants a sync
/// immediately after marking.
@Riverpod(keepAlive: true)
class OfflineMarker extends _$OfflineMarker {
  @override
  Future<void> build() async {
    // Stateless façade — methods read the latest manifest themselves.
  }

  Future<void> markAlbum(String albumId) async {
    await _mutate((OfflineManifest m) => m.copyWith(
          markedAlbums: <String>{...m.markedAlbums, albumId},
          estimatedTotalBytes: null,
          estimatedAt: null,
        ));
  }

  Future<void> unmarkAlbum(String albumId) async {
    await _mutate((OfflineManifest m) => m.copyWith(
          markedAlbums: <String>{...m.markedAlbums}..remove(albumId),
          estimatedTotalBytes: null,
          estimatedAt: null,
        ));
  }

  Future<void> markPlaylist(String playlistId) async {
    await _mutate((OfflineManifest m) => m.copyWith(
          markedPlaylists: <String>{...m.markedPlaylists, playlistId},
          estimatedTotalBytes: null,
          estimatedAt: null,
        ));
  }

  Future<void> unmarkPlaylist(String playlistId) async {
    await _mutate((OfflineManifest m) => m.copyWith(
          markedPlaylists: <String>{...m.markedPlaylists}..remove(playlistId),
          estimatedTotalBytes: null,
          estimatedAt: null,
        ));
  }

  Future<void> markArtist(String artistId) async {
    await _mutate((OfflineManifest m) => m.copyWith(
          markedArtists: <String>{...m.markedArtists, artistId},
          estimatedTotalBytes: null,
          estimatedAt: null,
        ));
  }

  Future<void> unmarkArtist(String artistId) async {
    await _mutate((OfflineManifest m) => m.copyWith(
          markedArtists: <String>{...m.markedArtists}..remove(artistId),
          estimatedTotalBytes: null,
          estimatedAt: null,
        ));
  }

  /// Selector helpers — UI calls these directly via `ref.watch`.
  bool isMarkedAlbum(OfflineManifest m, String albumId) =>
      m.markedAlbums.contains(albumId);

  bool isMarkedPlaylist(OfflineManifest m, String playlistId) =>
      m.markedPlaylists.contains(playlistId);

  bool isMarkedArtist(OfflineManifest m, String artistId) =>
      m.markedArtists.contains(artistId);

  Future<void> _mutate(
    OfflineManifest Function(OfflineManifest) transform,
  ) async {
    final ServerCreds settings = ref.read(serverCredsProvider);
    final OfflineManifestStore store =
        await ref.read(offlineManifestStoreProvider.future);
    final OfflineManifest current = await store.load(settings);
    final OfflineManifest next = transform(current);
    await store.save(settings, next);
    ref.invalidate(offlineManifestProvider);
  }
}
