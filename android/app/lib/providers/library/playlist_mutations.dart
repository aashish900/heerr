import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/song.dart';
import '../../services/playlist_service.dart';
import 'favourites.dart';
import 'library_playlist.dart';
import 'library_playlists.dart';

part 'playlist_mutations.g.dart';

/// Subsonic playlist-mutation notifier. Stateless: `build()` returns void
/// and the methods drive create / update / delete through [PlaylistService],
/// invalidating the affected read providers ([libraryPlaylistsProvider],
/// [libraryPlaylistProvider]) on success so the cache-aware wrappers refetch
/// fresh data on the next read.
///
/// A10: the transport moved to [PlaylistService]; this notifier keeps the
/// rules that need a `Ref` — dedupe, index ordering, provider invalidation,
/// and the [toggleFavourite] orchestration.
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (dialogs, snackbars).
@Riverpod(keepAlive: true)
class PlaylistMutations extends _$PlaylistMutations {
  @override
  void build() {}

  Future<PlaylistService> get _service =>
      ref.read(playlistServiceProvider.future);

  /// Create a playlist with the given `name` and optional `songIds`. Returns
  /// the parsed [Playlist]. Invalidates [libraryPlaylistsProvider] on success.
  Future<Playlist> createPlaylist({
    required String name,
    List<String> songIds = const <String>[],
  }) async {
    final PlaylistService service = await _service;
    final Playlist created =
        await service.createPlaylist(name: name, songIds: songIds);
    ref.invalidate(libraryPlaylistsProvider);
    return created;
  }

  /// Rename [playlistId] (+ optional visibility via [makePublic]). Invalidates
  /// the list (name changed) and detail (detail changed) providers.
  Future<void> renamePlaylist({
    required String playlistId,
    required String name,
    bool? makePublic,
  }) async {
    final PlaylistService service = await _service;
    await service.updatePlaylist(
      playlistId: playlistId,
      name: name,
      makePublic: makePublic,
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
  }

  /// Delete [playlistId]. Invalidates [libraryPlaylistsProvider].
  Future<void> deletePlaylist(String playlistId) async {
    final PlaylistService service = await _service;
    await service.deletePlaylist(playlistId);
    ref.invalidate(libraryPlaylistsProvider);
  }

  /// Append [songIds] to [playlistId], deduplicating against the playlist's
  /// current entries (client-side guarantee — Subsonic happily appends
  /// duplicates if asked). Returns the number actually added; a no-op (empty
  /// input or fully-duplicate) returns 0 with no call / no invalidation.
  Future<int> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    if (songIds.isEmpty) return 0;
    final PlaylistService service = await _service;

    final Set<String> existingIds =
        await service.getPlaylistEntryIds(playlistId);
    final List<String> toAdd = <String>[
      for (final String id in songIds)
        if (!existingIds.contains(id)) id,
    ];
    if (toAdd.isEmpty) return 0;

    await service.updatePlaylist(playlistId: playlistId, songIdToAdd: toAdd);
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
    return toAdd.length;
  }

  /// Remove the entries at the given 0-based [indices] from [playlistId].
  /// Sorts descending before sending so an earlier remove doesn't shift the
  /// indices of later ones. Empty [indices] is a no-op.
  Future<void> removeSongsAtIndices({
    required String playlistId,
    required List<int> indices,
  }) async {
    if (indices.isEmpty) return;
    final List<int> sortedDesc = <int>[...indices]
      ..sort((int a, int b) => b.compareTo(a));
    final PlaylistService service = await _service;
    await service.updatePlaylist(
      playlistId: playlistId,
      songIndexToRemove: sortedDesc.map((int i) => i.toString()).toList(),
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
  }

  /// Toggle [song]'s membership in the user's "Favourites" playlist.
  /// Lazy-creates it on first toggle; otherwise adds or removes the song
  /// depending on current membership. Delegates to [createPlaylist] /
  /// [addSongs] / [removeSongsAtIndices] so the standard invalidation +
  /// ApiError contract still applies.
  Future<void> toggleFavourite(Song song) async {
    final Playlist? fav = await ref.read(favouritesPlaylistProvider.future);
    if (fav == null) {
      await createPlaylist(
        name: kFavouritesPlaylistName,
        songIds: <String>[song.id],
      );
      return;
    }
    final Playlist detail =
        await ref.read(libraryPlaylistProvider(fav.id).future);
    final int idx = detail.entry.indexWhere((Song s) => s.id == song.id);
    if (idx >= 0) {
      await removeSongsAtIndices(playlistId: fav.id, indices: <int>[idx]);
    } else {
      await addSongs(playlistId: fav.id, songIds: <String>[song.id]);
    }
  }

  /// Reorder [playlistId] to match [newSongIdOrder]. Subsonic 1.16.1 has no
  /// native reorder primitive — this issues a single `updatePlaylist` that
  /// removes every index (descending) and re-adds the songs in the new order;
  /// Navidrome processes removes before adds within one request. Empty input
  /// is a no-op. Invalidates list + detail providers.
  Future<void> reorder({
    required String playlistId,
    required List<String> newSongIdOrder,
  }) async {
    if (newSongIdOrder.isEmpty) return;
    final int n = newSongIdOrder.length;
    final List<String> indicesDesc = <String>[
      for (int i = n - 1; i >= 0; i--) i.toString(),
    ];
    final PlaylistService service = await _service;
    await service.updatePlaylist(
      playlistId: playlistId,
      songIndexToRemove: indicesDesc,
      songIdToAdd: newSongIdOrder,
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
  }
}
