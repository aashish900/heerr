import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/artist_index.dart';
import '../../offline/library_cache.dart';

part 'library_artists.g.dart';

/// Wraps `GET /rest/getArtists.view`. Subsonic groups artists into
/// alphabetical buckets after applying `ignoredArticles`; the envelope is:
///
/// ```
/// "artists": { "ignoredArticles": "...", "index": [{name, artist: [...]}, ...] }
/// ```
///
/// We surface the flat `List<ArtistIndex>` — UI typically renders them
/// sectioned, but the provider doesn't decide that. Returns an empty list
/// when the user has no library (no `index` field).
///
/// L5: cache-aware. See [libraryAlbums] for the list-encoding shape.
@riverpod
Future<List<ArtistIndex>> libraryArtists(LibraryArtistsRef ref) async {
  return cacheAware<List<ArtistIndex>>(
    ref: ref,
    cacheKey: 'artists',
    networkCall: () async {
      final Dio dio = await ref.watch(subsonicDioClientProvider.future);
      return subsonicCall<List<ArtistIndex>>(
        () => dio.get<dynamic>(SubsonicEndpoints.getArtists),
        (Map<String, dynamic> env) {
          final dynamic artists = env['artists'];
          if (artists is! Map<String, dynamic>) return <ArtistIndex>[];
          final dynamic index = artists['index'];
          if (index is! List) return <ArtistIndex>[];
          return index
              .map((dynamic e) =>
                  ArtistIndex.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
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
