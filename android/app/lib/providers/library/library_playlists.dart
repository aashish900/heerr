import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/playlist.dart';
import '../../offline/library_cache.dart';
import '../../services/subsonic_library_service.dart';

part 'library_playlists.g.dart';

/// Wraps `GET /rest/getPlaylists.view` (via [SubsonicLibraryService]). Returns
/// the user's playlists as a flat list; each [Playlist] here has no `entry`
/// populated — the detail payload comes from `libraryPlaylist(id)`.
///
/// L5: cache-aware. See [libraryAlbums] for the list-encoding shape.
@riverpod
Future<List<Playlist>> libraryPlaylists(LibraryPlaylistsRef ref) async {
  return cacheAware<List<Playlist>>(
    ref: ref,
    cacheKey: 'playlists',
    networkCall: () async {
      final SubsonicLibraryService service =
          await ref.watch(subsonicLibraryServiceProvider.future);
      return service.getPlaylists();
    },
    encode: (List<Playlist> ps) => <String, dynamic>{
      'items': ps.map((Playlist p) => p.toJson()).toList(),
    },
    decode: (Map<String, dynamic> json) {
      final dynamic items = json['items'];
      if (items is! List) return <Playlist>[];
      return items
          .map((dynamic e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
}
