import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/artist.dart';

part 'library_artist.g.dart';

/// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
/// `album` list populated. Family-keyed by artist id so the album-detail
/// route can subscribe directly.
@riverpod
Future<Artist> libraryArtist(LibraryArtistRef ref, String id) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return subsonicCall<Artist>(
    () => dio.get<dynamic>(
      SubsonicEndpoints.getArtist,
      queryParameters: <String, dynamic>{'id': id},
    ),
    (Map<String, dynamic> env) =>
        Artist.fromJson(env['artist'] as Map<String, dynamic>),
  );
}
