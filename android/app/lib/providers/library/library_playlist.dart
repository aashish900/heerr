import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/playlist.dart';
import '../../offline/library_cache.dart';

part 'library_playlist.g.dart';

/// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
/// its `entry` list populated (each entry is a song).
///
/// L5: cache-aware. See [libraryAlbum] for the contract.
@riverpod
Future<Playlist> libraryPlaylist(LibraryPlaylistRef ref, String id) async {
  return cacheAware<Playlist>(
    ref: ref,
    cacheKey: 'playlist_$id',
    networkCall: () async {
      final Dio dio = await ref.watch(subsonicDioClientProvider.future);
      return subsonicCall<Playlist>(
        () => dio.get<dynamic>(
          SubsonicEndpoints.getPlaylist,
          queryParameters: <String, dynamic>{'id': id},
        ),
        (Map<String, dynamic> env) =>
            Playlist.fromJson(env['playlist'] as Map<String, dynamic>),
      );
    },
    encode: (Playlist p) => p.toJson(),
    decode: (Map<String, dynamic> json) => Playlist.fromJson(json),
  );
}
