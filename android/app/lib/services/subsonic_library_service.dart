import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/artist.dart';
import '../models/subsonic/artist_index.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/search_result3.dart';
import '../models/subsonic/song.dart';

part 'subsonic_library_service.g.dart';

/// One library-side `search3` hit, reduced to the fields the recommendation
/// cross-reference needs (N4): the Navidrome song id + optional cover-art id.
class SubsonicSongMatch {
  const SubsonicSongMatch({required this.id, this.coverArt});
  final String id;
  final String? coverArt;
}

/// A10: transport+JSON seam for Subsonic *read* calls. Owns nothing but the
/// [Dio] it was handed; every method issues one Subsonic request through
/// [subsonicCall] (so auth + envelope unwrapping + [ApiError] mapping stay
/// centralised) and returns a typed model. Riverpod state lives in the
/// providers that wrap this — the service has no `Ref`, so it is unit-testable
/// against a scripted dio adapter without standing up a container.
///
/// Playlist *mutations* live in `PlaylistService`; backend (heerr REST) calls
/// live in `BackendService`.
class SubsonicLibraryService {
  const SubsonicLibraryService(this._dio);

  final Dio _dio;

  /// Whole-library album page size for the A-Z Albums sub-tab. Subsonic caps
  /// a single `getAlbumList2` page; we request the lot in one shot (pagination
  /// is K1+ work).
  static const int albumListPageSize = 500;

  /// `getAlbum.view?id=<id>` → one [Album] with its `song` list populated.
  Future<Album> getAlbum(String id) {
    return subsonicCall<Album>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.getAlbum,
        queryParameters: <String, dynamic>{'id': id},
      ),
      (Map<String, dynamic> env) =>
          Album.fromJson(env['album'] as Map<String, dynamic>),
    );
  }

  /// `getAlbumList2.view?type=alphabeticalByName&size=500` → flat A-Z list.
  Future<List<Album>> getAlbums() {
    return getAlbumList(type: 'alphabeticalByName', size: albumListPageSize);
  }

  /// `getAlbumList2.view?type=<type>&size=<size>` → album list. Shared by the
  /// Home sections (recent / frequent) and the recommendation seed builder.
  Future<List<Album>> getAlbumList({
    required String type,
    required int size,
  }) {
    return subsonicCall<List<Album>>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.getAlbumList2,
        queryParameters: <String, dynamic>{'type': type, 'size': size},
      ),
      (Map<String, dynamic> env) => _parseAlbumList2(env),
    );
  }

  /// `getArtist.view?id=<id>` → one [Artist] with its `album` list populated.
  Future<Artist> getArtist(String id) {
    return subsonicCall<Artist>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.getArtist,
        queryParameters: <String, dynamic>{'id': id},
      ),
      (Map<String, dynamic> env) =>
          Artist.fromJson(env['artist'] as Map<String, dynamic>),
    );
  }

  /// `getArtists.view` → flat [ArtistIndex] buckets (empty when no library).
  Future<List<ArtistIndex>> getArtists() {
    return subsonicCall<List<ArtistIndex>>(
      () => _dio.get<dynamic>(SubsonicEndpoints.getArtists),
      (Map<String, dynamic> env) {
        final dynamic artists = env['artists'];
        if (artists is! Map<String, dynamic>) return <ArtistIndex>[];
        final dynamic index = artists['index'];
        if (index is! List) return <ArtistIndex>[];
        return index
            .map((dynamic e) => ArtistIndex.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// `getPlaylist.view?id=<id>` → one [Playlist] with its `entry` list.
  Future<Playlist> getPlaylist(String id) {
    return subsonicCall<Playlist>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.getPlaylist,
        queryParameters: <String, dynamic>{'id': id},
      ),
      (Map<String, dynamic> env) =>
          Playlist.fromJson(env['playlist'] as Map<String, dynamic>),
    );
  }

  /// `getPlaylists.view` → the user's playlists (no `entry` populated).
  Future<List<Playlist>> getPlaylists() {
    return subsonicCall<List<Playlist>>(
      () => _dio.get<dynamic>(SubsonicEndpoints.getPlaylists),
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

  /// `search3.view?query=<q>` → the combined [SearchResult3]. [cancelToken]
  /// lets the caller abort a debounced-then-superseded request.
  Future<SearchResult3> search3(String query, {CancelToken? cancelToken}) {
    return subsonicCall<SearchResult3>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.search3,
        queryParameters: <String, dynamic>{'query': query},
        cancelToken: cancelToken,
      ),
      (Map<String, dynamic> env) {
        final dynamic payload = env['searchResult3'];
        if (payload is! Map<String, dynamic>) return const SearchResult3();
        return SearchResult3.fromJson(payload);
      },
    );
  }

  /// Single best library match for a free-text `"<artist> <title>"` query —
  /// the N4 recommendation cross-reference probe. Returns null when nothing
  /// matches. Forces `songCount=1, artistCount=0, albumCount=0`.
  Future<SubsonicSongMatch?> findLibraryMatch(String query) {
    final String q = query.trim();
    if (q.isEmpty) return Future<SubsonicSongMatch?>.value();
    return subsonicCall<SubsonicSongMatch?>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.search3,
        queryParameters: <String, dynamic>{
          'query': q,
          'songCount': 1,
          'artistCount': 0,
          'albumCount': 0,
        },
      ),
      (Map<String, dynamic> env) {
        final dynamic block = env['searchResult3'];
        if (block is! Map<String, dynamic>) return null;
        final dynamic songs = block['song'];
        if (songs is! List || songs.isEmpty) return null;
        final dynamic first = songs.first;
        if (first is! Map<String, dynamic>) return null;
        final dynamic id = first['id'];
        if (id is! String || id.isEmpty) return null;
        final dynamic cover = first['coverArt'];
        return SubsonicSongMatch(
          id: id,
          coverArt: cover is String && cover.isNotEmpty ? cover : null,
        );
      },
    );
  }

  /// `getRandomSongs.view?size=<size>` → random library songs.
  Future<List<Song>> getRandomSongs(int size) {
    return subsonicCall<List<Song>>(
      () => _dio.get<dynamic>(
        SubsonicEndpoints.getRandomSongs,
        queryParameters: <String, dynamic>{'size': size},
      ),
      (Map<String, dynamic> env) =>
          _parseSongList(env['randomSongs'], 'song'),
    );
  }

  /// `getStarred2.view` → the user's starred songs.
  Future<List<Song>> getStarredSongs() {
    return subsonicCall<List<Song>>(
      () => _dio.get<dynamic>(SubsonicEndpoints.getStarred2),
      (Map<String, dynamic> env) => _parseSongList(env['starred2'], 'song'),
    );
  }

  static List<Album> _parseAlbumList2(Map<String, dynamic> env) {
    final dynamic block = env['albumList2'];
    if (block is! Map<String, dynamic>) return <Album>[];
    final dynamic albums = block['album'];
    if (albums is! List) return <Album>[];
    return albums
        .map((dynamic e) => Album.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<Song> _parseSongList(dynamic block, String key) {
    if (block is! Map<String, dynamic>) return <Song>[];
    final dynamic songs = block[key];
    if (songs is! List) return <Song>[];
    return songs
        .map((dynamic e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Async provider so the service is built once the (profile-keyed) Subsonic
/// [Dio] is ready. Tests that override `subsonicDioClientProvider` flow through
/// here unchanged — the service uses whatever dio that provider yields.
@riverpod
Future<SubsonicLibraryService> subsonicLibraryService(
  SubsonicLibraryServiceRef ref,
) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return SubsonicLibraryService(dio);
}
