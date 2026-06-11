import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/playlist.dart';

part 'library_playlist.g.dart';

/// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
/// its `entry` list populated (each entry is a song).
@riverpod
Future<Playlist> libraryPlaylist(LibraryPlaylistRef ref, String id) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return subsonicCall<Playlist>(
    () => dio.get<dynamic>(
      SubsonicEndpoints.getPlaylist,
      queryParameters: <String, dynamic>{'id': id},
    ),
    (Map<String, dynamic> env) =>
        Playlist.fromJson(env['playlist'] as Map<String, dynamic>),
  );
}
