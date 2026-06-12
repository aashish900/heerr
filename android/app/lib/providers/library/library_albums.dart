import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/album.dart';
import '../../offline/library_cache.dart';

part 'library_albums.g.dart';

/// Max page Subsonic accepts in a single `getAlbumList2.view` call. We
/// request the whole library in one shot for v1 — pagination is K1+ work.
const int _kAlbumListPageSize = 500;

/// Wraps `GET /rest/getAlbumList2.view?type=alphabeticalByName&size=500`.
/// Returns a flat A-Z album list for the Library tab's Albums sub-tab.
/// `getArtist(id)` gives per-artist albums but the Albums sub-tab needs a
/// global view, which Subsonic only exposes through `getAlbumList2`.
///
/// L5: cache-aware. List responses encode as `{'items': [a.toJson(), ...]}`.
@riverpod
Future<List<Album>> libraryAlbums(LibraryAlbumsRef ref) async {
  return cacheAware<List<Album>>(
    ref: ref,
    cacheKey: 'albums',
    networkCall: () async {
      final Dio dio = await ref.watch(subsonicDioClientProvider.future);
      return subsonicCall<List<Album>>(
        () => dio.get<dynamic>(
          SubsonicEndpoints.getAlbumList2,
          queryParameters: <String, dynamic>{
            'type': 'alphabeticalByName',
            'size': _kAlbumListPageSize,
          },
        ),
        (Map<String, dynamic> env) {
          final dynamic list = env['albumList2'];
          if (list is! Map<String, dynamic>) return <Album>[];
          final dynamic albums = list['album'];
          if (albums is! List) return <Album>[];
          return albums
              .map((dynamic e) => Album.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
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
