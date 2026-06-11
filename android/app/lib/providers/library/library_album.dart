import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/album.dart';

part 'library_album.g.dart';

/// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
/// `song` list populated. Family-keyed by album id.
@riverpod
Future<Album> libraryAlbum(LibraryAlbumRef ref, String id) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return subsonicCall<Album>(
    () => dio.get<dynamic>(
      SubsonicEndpoints.getAlbum,
      queryParameters: <String, dynamic>{'id': id},
    ),
    (Map<String, dynamic> env) =>
        Album.fromJson(env['album'] as Map<String, dynamic>),
  );
}
