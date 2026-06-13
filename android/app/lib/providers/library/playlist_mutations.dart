import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/song.dart';
import 'favourites.dart';
import 'library_playlist.dart';
import 'library_playlists.dart';

part 'playlist_mutations.g.dart';

/// Subsonic playlist-mutation notifier. Stateless: `build()` returns void
/// and the six methods drive `createPlaylist` / `updatePlaylist` /
/// `deletePlaylist` through [subsonicCall], invalidating the affected
/// read providers ([libraryPlaylistsProvider], [libraryPlaylistProvider])
/// on success so the cache-aware wrappers refetch fresh data on the next
/// read.
///
/// Wire contract: every method goes through [subsonicDioClientProvider],
/// so auth (`u/s/t/v/c/f`) is injected by `SubsonicAuthInterceptor`. The
/// envelope shape is the standard `{"subsonic-response": {...}}`; failures
/// are surfaced as the matching [ApiError] subclass (so callers compose
/// with `reactToApiError` / `showApiError`).
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (dialogs, snackbars). Letting
/// it auto-dispose between calls would re-build the type for every tap.
@Riverpod(keepAlive: true)
class PlaylistMutations extends _$PlaylistMutations {
  @override
  void build() {}

  /// `createPlaylist.view` with the given `name` and optional `songIds`
  /// (multi-param `songId`, preserved in order). Returns the parsed
  /// [Playlist] from the response envelope. Invalidates
  /// [libraryPlaylistsProvider] on success.
  Future<Playlist> createPlaylist({
    required String name,
    List<String> songIds = const <String>[],
  }) async {
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      if (songIds.isNotEmpty) 'songId': songIds,
    };
    final Playlist created = await subsonicCall<Playlist>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.createPlaylist,
        queryParameters: params,
      ),
      (Map<String, dynamic> env) =>
          Playlist.fromJson(env['playlist'] as Map<String, dynamic>),
    );
    ref.invalidate(libraryPlaylistsProvider);
    return created;
  }

  /// `updatePlaylist.view` with `playlistId` + `name` (+ optional `public`
  /// when [makePublic] is non-null). Empty envelope on success.
  /// Invalidates [libraryPlaylistsProvider] (name changed) and
  /// [libraryPlaylistProvider]`(playlistId)` (detail changed).
  Future<void> renamePlaylist({
    required String playlistId,
    required String name,
    bool? makePublic,
  }) async {
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
    final Map<String, dynamic> params = <String, dynamic>{
      'playlistId': playlistId,
      'name': name,
      if (makePublic != null) 'public': makePublic.toString(),
    };
    await subsonicCall<void>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.updatePlaylist,
        queryParameters: params,
      ),
      (_) {},
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
  }

  /// `deletePlaylist.view?id=<playlistId>`. Invalidates
  /// [libraryPlaylistsProvider] so the row disappears from the next read.
  Future<void> deletePlaylist(String playlistId) async {
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
    await subsonicCall<void>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.deletePlaylist,
        queryParameters: <String, dynamic>{'id': playlistId},
      ),
      (_) {},
    );
    ref.invalidate(libraryPlaylistsProvider);
  }

  /// Append [songIds] to [playlistId] via `updatePlaylist.view` with
  /// `songIdToAdd` repeated in order. Deduplicates against the playlist's
  /// current entry list — songs already in the playlist are silently
  /// skipped (Subsonic happily appends duplicates if asked, so this is a
  /// client-side guarantee). Returns the number of songs actually added.
  /// Empty input or a fully-duplicate request is a no-op (no
  /// `updatePlaylist` call, no provider invalidation, returns 0).
  /// Invalidates the list provider (songCount changed) and the detail
  /// provider for [playlistId] when at least one song is added.
  Future<int> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    if (songIds.isEmpty) return 0;
    final Dio dio = await ref.read(subsonicDioClientProvider.future);

    // Fetch the playlist's current entry list directly through dio (not
    // through `libraryPlaylistProvider`) so we get a known-fresh state
    // before computing the dedupe filter — and so the call doesn't
    // perturb provider-cache bookkeeping at the call site.
    final Set<String> existingIds = await subsonicCall<Set<String>>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.getPlaylist,
        queryParameters: <String, dynamic>{'id': playlistId},
      ),
      (Map<String, dynamic> env) {
        final dynamic playlist = env['playlist'];
        if (playlist is! Map<String, dynamic>) return <String>{};
        final dynamic entries = playlist['entry'];
        if (entries is! List) return <String>{};
        return <String>{
          for (final dynamic e in entries)
            if (e is Map<String, dynamic> && e['id'] is String)
              e['id'] as String,
        };
      },
    );

    final List<String> toAdd = <String>[
      for (final String id in songIds)
        if (!existingIds.contains(id)) id,
    ];
    if (toAdd.isEmpty) return 0;

    await subsonicCall<void>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.updatePlaylist,
        queryParameters: <String, dynamic>{
          'playlistId': playlistId,
          'songIdToAdd': toAdd,
        },
      ),
      (_) {},
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
    return toAdd.length;
  }

  /// Remove the entries at the given 0-based [indices] from [playlistId]
  /// via `updatePlaylist.view` with `songIndexToRemove`. Sorts descending
  /// before sending so an earlier remove doesn't shift the indices of
  /// later ones (the Subsonic contract is "0-based against the *current*
  /// order"; safe ordering is strictly descending). Empty [indices] is a
  /// no-op. Invalidates list + detail providers.
  Future<void> removeSongsAtIndices({
    required String playlistId,
    required List<int> indices,
  }) async {
    if (indices.isEmpty) return;
    final List<int> sortedDesc = <int>[...indices]
      ..sort((int a, int b) => b.compareTo(a));
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
    await subsonicCall<void>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.updatePlaylist,
        queryParameters: <String, dynamic>{
          'playlistId': playlistId,
          'songIndexToRemove':
              sortedDesc.map((int i) => i.toString()).toList(),
        },
      ),
      (_) {},
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
  }

  /// Toggle [song]'s membership in the user's "Favourites" playlist.
  /// Lazy-creates the Favourites playlist on first toggle if it doesn't
  /// exist yet (with this song as the first entry); otherwise adds or
  /// removes the song depending on its current membership.
  ///
  /// Delegates to [createPlaylist] / [addSongs] / [removeSongsAtIndices]
  /// so the standard invalidation + ApiError contract still applies. The
  /// derived [favouriteSongIdsProvider] picks up the change via its watch
  /// chain to [libraryPlaylistProvider].
  Future<void> toggleFavourite(Song song) async {
    final Playlist? fav =
        await ref.read(favouritesPlaylistProvider.future);
    if (fav == null) {
      await createPlaylist(
        name: kFavouritesPlaylistName,
        songIds: <String>[song.id],
      );
      return;
    }
    final Playlist detail =
        await ref.read(libraryPlaylistProvider(fav.id).future);
    final int idx =
        detail.entry.indexWhere((Song s) => s.id == song.id);
    if (idx >= 0) {
      await removeSongsAtIndices(
        playlistId: fav.id,
        indices: <int>[idx],
      );
    } else {
      await addSongs(
        playlistId: fav.id,
        songIds: <String>[song.id],
      );
    }
  }

  /// Reorder [playlistId] to match [newSongIdOrder]. Subsonic 1.16.1 has
  /// no native reorder primitive — `updatePlaylist` only does append +
  /// delete-at-index. The implementation issues a single `updatePlaylist`
  /// call that removes every index (descending, see [removeSongsAtIndices])
  /// and re-adds the songs via `songIdToAdd` in the new order; Navidrome
  /// processes removes before adds within one request. Empty
  /// [newSongIdOrder] is a no-op. Invalidates list + detail providers.
  Future<void> reorder({
    required String playlistId,
    required List<String> newSongIdOrder,
  }) async {
    if (newSongIdOrder.isEmpty) return;
    final int n = newSongIdOrder.length;
    final List<String> indicesDesc = <String>[
      for (int i = n - 1; i >= 0; i--) i.toString(),
    ];
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
    await subsonicCall<void>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.updatePlaylist,
        queryParameters: <String, dynamic>{
          'playlistId': playlistId,
          'songIndexToRemove': indicesDesc,
          'songIdToAdd': newSongIdOrder,
        },
      ),
      (_) {},
    );
    ref.invalidate(libraryPlaylistsProvider);
    ref.invalidate(libraryPlaylistProvider(playlistId));
  }
}
