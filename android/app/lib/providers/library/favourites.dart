import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/song.dart';
import '../server_creds.dart';
import 'library_playlist.dart';
import 'library_playlists.dart';

part 'favourites.g.dart';

/// Name of the per-user Favourites playlist. UK spelling per user
/// preference. Used by both the lookup providers below and by
/// `PlaylistMutations.toggleFavourite` when lazy-creating the playlist.
const String kFavouritesPlaylistName = 'Favourites';

/// Locates the user's Favourites playlist by matching
/// [kFavouritesPlaylistName] against [libraryPlaylistsProvider] for the
/// current `settings.navidromeUsername`. Returns `null` when:
///   - the Favourites playlist hasn't been lazy-created yet (first
///     ever heart-tap creates it via `toggleFavourite`),
///   - or no Navidrome username is configured.
///
/// Cache-aware via the underlying [libraryPlaylistsProvider] — fresh
/// after every `PlaylistMutations.createPlaylist` / `addSongs` /
/// `removeSongsAtIndices` invalidation.
@riverpod
Future<Playlist?> favouritesPlaylist(FavouritesPlaylistRef ref) async {
  final ServerCreds settings = ref.watch(serverCredsProvider);
  final String? username = settings.navidromeUsername;
  if (username == null) return null;
  final List<Playlist> playlists =
      await ref.watch(libraryPlaylistsProvider.future);
  for (final Playlist p in playlists) {
    if (p.name == kFavouritesPlaylistName && p.owner == username) {
      return p;
    }
  }
  return null;
}

/// Set of song ids currently in the user's Favourites playlist. Empty
/// when no Favourites playlist exists yet. UI surfaces (heart icon)
/// watch this provider to know whether to render the filled-red heart.
///
/// Derived: watches [favouritesPlaylistProvider] → then
/// [libraryPlaylistProvider] with the favourites id to pull the entry
/// list. Both layers carry the invalidation chain from mutations so the
/// heart UI updates after a toggle without an explicit refresh.
@riverpod
Future<Set<String>> favouriteSongIds(FavouriteSongIdsRef ref) async {
  final Playlist? fav = await ref.watch(favouritesPlaylistProvider.future);
  if (fav == null) return const <String>{};
  final Playlist detail =
      await ref.watch(libraryPlaylistProvider(fav.id).future);
  return <String>{
    for (final Song s in detail.entry) s.id,
  };
}
