import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/artist.dart';
import '../../offline/library_cache.dart';
import '../../services/subsonic_library_service.dart';

part 'library_artist.g.dart';

/// Wraps `GET /rest/getArtist.view?id=<id>` (via [SubsonicLibraryService]).
/// Returns one [Artist] with its `album` list populated. Family-keyed by id.
///
/// L5: cache-aware. See [libraryAlbum] for the contract.
@riverpod
Future<Artist> libraryArtist(LibraryArtistRef ref, String id) async {
  return cacheAware<Artist>(
    ref: ref,
    cacheKey: 'artist_$id',
    networkCall: () async {
      final SubsonicLibraryService service =
          await ref.watch(subsonicLibraryServiceProvider.future);
      return service.getArtist(id);
    },
    encode: (Artist a) => a.toJson(),
    decode: (Map<String, dynamic> json) => Artist.fromJson(json),
  );
}
