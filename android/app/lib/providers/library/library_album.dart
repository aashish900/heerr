import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../offline/library_cache.dart';
import '../../services/subsonic_library_service.dart';

part 'library_album.g.dart';

/// Wraps `GET /rest/getAlbum.view?id=<id>` (via [SubsonicLibraryService]).
/// Returns one [Album] with its `song` list populated. Family-keyed by id.
///
/// L5: cache-aware. On success the response is persisted to the per-server
/// library cache; on failure the cached copy is returned silently.
@riverpod
Future<Album> libraryAlbum(LibraryAlbumRef ref, String id) async {
  return cacheAware<Album>(
    ref: ref,
    cacheKey: 'album_$id',
    networkCall: () async {
      final SubsonicLibraryService service =
          await ref.watch(subsonicLibraryServiceProvider.future);
      return service.getAlbum(id);
    },
    encode: (Album a) => a.toJson(),
    decode: (Map<String, dynamic> json) => Album.fromJson(json),
  );
}
