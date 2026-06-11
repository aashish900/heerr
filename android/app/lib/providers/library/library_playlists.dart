import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/playlist.dart';

part 'library_playlists.g.dart';

/// Wraps `GET /rest/getPlaylists.view`. Returns the user's playlists as a
/// flat list. Each [Playlist] here has no `entry` populated — the detail
/// payload comes from `libraryPlaylist(id)`.
@riverpod
Future<List<Playlist>> libraryPlaylists(LibraryPlaylistsRef ref) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return subsonicCall<List<Playlist>>(
    () => dio.get<dynamic>(SubsonicEndpoints.getPlaylists),
    (Map<String, dynamic> env) {
      final dynamic playlists = env['playlists'];
      if (playlists is! Map<String, dynamic>) return <Playlist>[];
      final dynamic list = playlists['playlist'];
      if (list is! List) return <Playlist>[];
      return list
          .map((dynamic e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
}
