import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../offline/library_cache.dart';
import '../../services/subsonic_library_service.dart';

part 'library_albums.g.dart';

/// Wraps `GET /rest/getAlbumList2.view?type=alphabeticalByName&size=500` (via
/// [SubsonicLibraryService]). Returns a flat A-Z album list for the Library
/// tab's Albums sub-tab — `getArtist(id)` gives per-artist albums but the
/// Albums sub-tab needs the global view, which only `getAlbumList2` exposes.
///
/// L5: cache-aware. List responses encode as `{'items': [a.toJson(), ...]}`.
@riverpod
Future<List<Album>> libraryAlbums(LibraryAlbumsRef ref) async {
  return cacheAware<List<Album>>(
    ref: ref,
    cacheKey: 'albums',
    networkCall: () async {
      final SubsonicLibraryService service =
          await ref.watch(subsonicLibraryServiceProvider.future);
      return service.getAlbums();
    },
    encode: (List<Album> albums) => <String, dynamic>{
      'items': albums.map((Album a) => a.toJson()).toList(),
    },
    decode: (Map<String, dynamic> json) {
      final dynamic items = json['items'];
      if (items is! List) return <Album>[];
      return items
          .map((dynamic e) => Album.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
}
