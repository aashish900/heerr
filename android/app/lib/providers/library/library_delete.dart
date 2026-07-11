import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/song.dart';
import '../../services/backend_service.dart';
import '../downloaded_songs.dart';
import '../home/home_providers.dart';
import 'library_album.dart';
import 'starred_songs.dart';
import 'library_albums.dart';
import 'library_artists.dart';
import 'library_search.dart';

part 'library_delete.g.dart';

/// W1 (#41): server-side song deletion. Stateless notifier (same shape as
/// `PlaylistMutations`): [deleteFromServer] drives the backend
/// `DELETE /library/song` through [BackendService] and invalidates the read
/// surfaces that could still list the track.
///
/// Navidrome only drops the track on its next scan (~1 min), so an
/// invalidated provider may transiently re-serve the song from Navidrome —
/// callers word their success snackbar accordingly.
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (sheets, dialogs).
@Riverpod(keepAlive: true)
class LibraryDelete extends _$LibraryDelete {
  @override
  void build() {}

  /// Delete [song]'s file from the server library. Throws [StateError] when
  /// the song carries no Subsonic `path` (callers gate the affordance on
  /// `song.path != null`, so this is a programming error, not a UX branch).
  Future<void> deleteFromServer(Song song) async {
    final String? path = song.path;
    if (path == null || path.isEmpty) {
      throw StateError('song ${song.id} has no server path');
    }
    final BackendService service =
        await ref.read(backendServiceProvider.future);
    await service.deleteLibrarySong(path);

    ref.invalidate(librarySearchProvider);
    ref.invalidate(libraryAlbumsProvider);
    ref.invalidate(libraryArtistsProvider);
    final String? albumId = song.albumId;
    if (albumId != null) ref.invalidate(libraryAlbumProvider(albumId));
    ref.invalidate(downloadedSongsProvider);
    // Home redesign: see the matching invalidation set in library_edit.dart.
    ref.invalidate(homeNewestProvider);
    ref.invalidate(recentlyAddedFullProvider);
    ref.invalidate(starredSongsProvider);
  }
}
