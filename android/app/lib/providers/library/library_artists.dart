import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/artist_index.dart';
import '../../offline/library_cache.dart';
import '../../services/subsonic_library_service.dart';

part 'library_artists.g.dart';

/// Wraps `GET /rest/getArtists.view` (via [SubsonicLibraryService]). Subsonic
/// groups artists into alphabetical buckets; we surface the flat
/// `List<ArtistIndex>`. Returns an empty list when the user has no library.
///
/// L5: cache-aware. See [libraryAlbums] for the list-encoding shape.
@riverpod
Future<List<ArtistIndex>> libraryArtists(LibraryArtistsRef ref) async {
  return cacheAware<List<ArtistIndex>>(
    ref: ref,
    cacheKey: 'artists',
    networkCall: () async {
      final SubsonicLibraryService service =
          await ref.watch(subsonicLibraryServiceProvider.future);
      return service.getArtists();
    },
    encode: (List<ArtistIndex> idx) => <String, dynamic>{
      'items': idx.map((ArtistIndex e) => e.toJson()).toList(),
    },
    decode: (Map<String, dynamic> json) {
      final dynamic items = json['items'];
      if (items is! List) return <ArtistIndex>[];
      return items
          .map((dynamic e) => ArtistIndex.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
}
