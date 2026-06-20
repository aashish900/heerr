import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/subsonic/playlist.dart';

part 'playlist_service.g.dart';

/// A10: transport seam for Subsonic playlist *mutations*
/// (`createPlaylist` / `updatePlaylist` / `deletePlaylist`). Pure transport —
/// the dedup / index-ordering rules and provider-invalidation that used to sit
/// inline in `PlaylistMutations` stay in that notifier (they need a `Ref`);
/// this service just issues the signed Subsonic calls. No `Ref`, so it
/// unit-tests against a scripted dio adapter.
class PlaylistService {
  const PlaylistService(this._dio);

  final Dio _dio;

  /// `createPlaylist.view?name=<name>[&songId=...]` → the created [Playlist].
  Future<Playlist> createPlaylist({
    required String name,
    List<String> songIds = const <String>[],
  }) {
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      if (songIds.isNotEmpty) 'songId': songIds,
    };
    return subsonicCall<Playlist>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.createPlaylist,
        queryParameters: params,
      ),
      (Map<String, dynamic> env) =>
          Playlist.fromJson(env['playlist'] as Map<String, dynamic>),
    );
  }

  /// `updatePlaylist.view` — the Subsonic Swiss-army mutation. Covers rename
  /// ([name] / [makePublic]), append ([songIdToAdd]) and remove-by-index
  /// ([songIndexToRemove], 0-based against the *current* order). Navidrome
  /// processes removes before adds within one request, which the reorder path
  /// relies on. Empty envelope on success.
  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    bool? makePublic,
    List<String>? songIdToAdd,
    List<String>? songIndexToRemove,
  }) {
    final Map<String, dynamic> params = <String, dynamic>{
      'playlistId': playlistId,
      'name': ?name,
      if (makePublic != null) 'public': makePublic.toString(),
      if (songIdToAdd != null && songIdToAdd.isNotEmpty)
        'songIdToAdd': songIdToAdd,
      if (songIndexToRemove != null && songIndexToRemove.isNotEmpty)
        'songIndexToRemove': songIndexToRemove,
    };
    return subsonicCall<void>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.updatePlaylist,
        queryParameters: params,
      ),
      (_) {},
    );
  }

  /// `deletePlaylist.view?id=<id>`. Empty envelope on success.
  Future<void> deletePlaylist(String playlistId) {
    return subsonicCall<void>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.deletePlaylist,
        queryParameters: <String, dynamic>{'id': playlistId},
      ),
      (_) {},
    );
  }

  /// Fetch the current entry ids of [playlistId] directly (not via the cached
  /// `libraryPlaylistProvider`) so the caller can compute a known-fresh dedupe
  /// filter before appending.
  Future<Set<String>> getPlaylistEntryIds(String playlistId) {
    return subsonicCall<Set<String>>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.getPlaylist,
        queryParameters: <String, dynamic>{'id': playlistId},
      ),
      (Map<String, dynamic> env) {
        final dynamic playlist = env['playlist'];
        if (playlist is! Map<String, dynamic>) return <String>{};
        final dynamic entries = playlist['entry'];
        if (entries is! List) return <String>{};
        return <String>{
          for (final dynamic e in entries)
            if (e is Map<String, dynamic> && e['id'] is String)
              e['id'] as String,
        };
      },
    );
  }
}

/// Async provider so the service is built once the (profile-keyed) Subsonic
/// [Dio] is ready. Tests overriding `subsonicDioClientProvider` flow through.
@riverpod
Future<PlaylistService> playlistService(PlaylistServiceRef ref) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return PlaylistService(dio);
}
