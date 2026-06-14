import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/seed_track.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import 'library/favourites.dart';
import 'library/library_playlist.dart';

part 'recommendations.g.dart';

/// Hard cap on seeds returned by [seedCollectionProvider]. Tuned to match
/// the backend's `POST /api/v1/recommend` limit ceiling (50) with headroom:
/// 20 covers enough variety to drive both Last.fm and ListenBrainz with
/// healthy aggregate signal without ballooning the request body.
const int _kMaxSeeds = 20;

/// Size requested from `getAlbumList2.view?type=frequent`. Larger than the
/// dedup-capped seed budget so we have room to lose duplicates / missing
/// artist fields before bottoming out below `_kMaxSeeds`.
const int _kFrequentAlbumSize = 30;

/// Pure merge function — kept separate from the provider so the rules
/// (starred-first ranking, case-insensitive + whitespace-tolerant dedup
/// by `title+artist`, Favourites fallback when both primary sources are
/// empty, and the [_kMaxSeeds] cap) are testable without standing up a
/// Riverpod container.
///
/// `starred` is the user's starred songs (strongest signal). `frequent`
/// is the user's most-played albums — each album contributes one seed
/// shaped as `(album.name, album.artist)`. `favourites` are the songs in
/// the lazy-created Favourites playlist (N2 fallback only — supplied as
/// `<>` when the primary sources had anything).
///
/// `favourites` is consulted only when the primary sources produced zero
/// seeds. This avoids stacking Favourites entries on top of the starred /
/// frequent ranking on every fetch.
List<SeedTrack> buildSeedCollection({
  required List<Song> starred,
  required List<Album> frequent,
  required List<Song> favourites,
  int maxSeeds = _kMaxSeeds,
}) {
  final List<SeedTrack> out = <SeedTrack>[];
  final Set<String> seen = <String>{};

  String key(String title, String artist) =>
      '${title.toLowerCase().trim()}|${artist.toLowerCase().trim()}';

  void tryAdd(String? title, String? artist) {
    if (out.length >= maxSeeds) return;
    if (title == null || title.trim().isEmpty) return;
    if (artist == null || artist.trim().isEmpty) return;
    final String k = key(title, artist);
    if (seen.contains(k)) return;
    seen.add(k);
    out.add(SeedTrack(title: title, artist: artist));
  }

  for (final Song s in starred) {
    tryAdd(s.title, s.artist);
  }
  for (final Album a in frequent) {
    tryAdd(a.name, a.artist);
  }

  if (out.isEmpty) {
    for (final Song s in favourites) {
      tryAdd(s.title, s.artist);
    }
  }

  return out;
}

/// Recommendation seed collection — input to the backend `POST /recommend`.
///
/// Order of operations:
///   1. `GET /rest/getStarred2.view` → starred songs.
///   2. `GET /rest/getAlbumList2.view?type=frequent&size=30` → frequently
///      played albums.
///   3. If both came back empty, read the Favourites playlist via the
///      existing [favouritesPlaylistProvider] + [libraryPlaylistProvider]
///      chain.
///   4. Merge via [buildSeedCollection] — starred first, dedup, cap.
///
/// Errors from the Subsonic calls propagate to the caller as `AsyncError`.
/// The Favourites fallback no-ops gracefully when no Navidrome username is
/// configured (the provider returns an empty list).
@riverpod
Future<List<SeedTrack>> seedCollection(SeedCollectionRef ref) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);

  final List<Song> starred = await _fetchStarredSongs(dio);
  final List<Album> frequent = await _fetchFrequentAlbums(dio);

  List<Song> favourites = const <Song>[];
  if (starred.isEmpty && frequent.isEmpty) {
    favourites = await _fetchFavouriteSongs(ref);
  }

  return buildSeedCollection(
    starred: starred,
    frequent: frequent,
    favourites: favourites,
  );
}

Future<List<Song>> _fetchStarredSongs(Dio dio) {
  return subsonicCall<List<Song>>(
    () => dio.get<dynamic>(SubsonicEndpoints.getStarred2),
    (Map<String, dynamic> env) {
      final dynamic block = env['starred2'];
      if (block is! Map<String, dynamic>) return <Song>[];
      final dynamic songs = block['song'];
      if (songs is! List) return <Song>[];
      return songs
          .map((dynamic e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
}

Future<List<Album>> _fetchFrequentAlbums(Dio dio) {
  return subsonicCall<List<Album>>(
    () => dio.get<dynamic>(
      SubsonicEndpoints.getAlbumList2,
      queryParameters: <String, dynamic>{
        'type': 'frequent',
        'size': _kFrequentAlbumSize,
      },
    ),
    (Map<String, dynamic> env) {
      final dynamic block = env['albumList2'];
      if (block is! Map<String, dynamic>) return <Album>[];
      final dynamic albums = block['album'];
      if (albums is! List) return <Album>[];
      return albums
          .map((dynamic e) => Album.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
}

Future<List<Song>> _fetchFavouriteSongs(SeedCollectionRef ref) async {
  final Playlist? fav = await ref.watch(favouritesPlaylistProvider.future);
  if (fav == null) return const <Song>[];
  final Playlist detail =
      await ref.watch(libraryPlaylistProvider(fav.id).future);
  return detail.entry;
}
