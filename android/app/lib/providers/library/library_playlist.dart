import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/playlist.dart';
import '../../offline/library_cache.dart';
import '../../services/subsonic_library_service.dart';

part 'library_playlist.g.dart';

/// Wraps `GET /rest/getPlaylist.view?id=<id>` (via [SubsonicLibraryService]).
/// Returns one [Playlist] with its `entry` list populated.
///
/// L5: cache-aware. See [libraryAlbum] for the contract.
@riverpod
Future<Playlist> libraryPlaylist(LibraryPlaylistRef ref, String id) async {
  return cacheAware<Playlist>(
    ref: ref,
    cacheKey: 'playlist_$id',
    networkCall: () async {
      final SubsonicLibraryService service =
          await ref.watch(subsonicLibraryServiceProvider.future);
      return service.getPlaylist(id);
    },
    encode: (Playlist p) => p.toJson(),
    decode: (Map<String, dynamic> json) => Playlist.fromJson(json),
  );
}
