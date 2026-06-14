import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/recommend_health.dart';
import '../models/recommended_track.dart';
import '../models/seed_track.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import 'library/favourites.dart';
import 'library/library_playlist.dart';

part 'recommendations.g.dart';

/// Default `limit` sent to the backend's `POST /api/v1/recommend`. Matches
/// the screen's typical viewport — enough variety, short enough to be
/// scrollable without pagination.
const int _kRecommendationsLimit = 20;

/// Optional override seed for [recommendationsProvider]. When non-null, the
/// recommendations notifier uses it as the **sole** seed instead of pulling
/// from [seedCollectionProvider].
///
/// Set by the "Find similar →" long-press affordance (N4) which routes to
/// `/library/recommendations` with a specific song as the seed. The screen
/// resets this back to null when popped so the next visit returns to the
/// general "For You" feed.
final manualSeedProvider = StateProvider<SeedTrack?>((Ref ref) => null);

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

/// Recommendation results from the heerr backend (`POST /api/v1/recommend`).
///
/// Reads the user's seed collection via [seedCollectionProvider] (N2),
/// POSTs `{seeds, limit: 20}` to the backend, returns the parsed
/// [RecommendedTrack] list for the UI.
///
/// When the seed collection is empty (no starred / frequent / Favourites
/// data on the server yet), still calls the backend with `seeds: []` —
/// the listenbrainz engine drives its own history-based results, so the
/// empty-seed case is meaningful for users running that engine. ytmusic
/// and lastfm engines will return `[]` for empty seeds; the screen
/// renders the empty-state widget.
///
/// `inLibrary` cross-reference is not done in v1 — it lands at N4. v1
/// results all render with `inLibrary: false` and the Download button.
@riverpod
class Recommendations extends _$Recommendations {
  @override
  Future<List<RecommendedTrack>> build() async {
    final SeedTrack? manual = ref.watch(manualSeedProvider);
    final List<SeedTrack> seeds;
    if (manual != null) {
      seeds = <SeedTrack>[manual];
    } else {
      seeds = await ref.watch(seedCollectionProvider.future);
    }

    final Dio dio = await ref.watch(dioClientProvider.future);

    final Map<String, dynamic> body = <String, dynamic>{
      'seeds': seeds.map((SeedTrack s) => s.toJson()).toList(),
      'limit': _kRecommendationsLimit,
    };

    final List<RecommendedTrack> base = await apiCall<List<RecommendedTrack>>(
      () => dio.post<dynamic>(Endpoints.recommend, data: body),
      (dynamic data) {
        final Map<String, dynamic> json = data as Map<String, dynamic>;
        final dynamic results = json['results'];
        if (results is! List) return <RecommendedTrack>[];
        return results
            .map((dynamic e) =>
                RecommendedTrack.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );

    if (base.isEmpty) return base;

    // Cross-reference each result against the Subsonic library via
    // `search3.view?query=<artist> <title>&songCount=1`. Library-side
    // failures are swallowed per result so one bad search3 doesn't kill
    // the whole list — the result just falls through as inLibrary=false.
    return _hydrateLibraryMatches(base);
  }

  Future<List<RecommendedTrack>> _hydrateLibraryMatches(
    List<RecommendedTrack> base,
  ) async {
    final Dio sub;
    try {
      sub = await ref.watch(subsonicDioClientProvider.future);
    } catch (_) {
      // Navidrome not configured — every row stays remote-only.
      return base;
    }

    Future<RecommendedTrack> resolveOne(RecommendedTrack r) async {
      try {
        final _LibraryMatch? match = await _searchLibraryForMatch(sub, r);
        if (match == null) return r;
        return r.copyWith(
          inLibrary: true,
          subsonicSongId: match.id,
          coverArt: match.coverArt,
        );
      } catch (_) {
        return r;
      }
    }

    return Future.wait(base.map(resolveOne));
  }

  Future<_LibraryMatch?> _searchLibraryForMatch(
    Dio sub,
    RecommendedTrack r,
  ) async {
    final String query = '${r.artist} ${r.title}'.trim();
    if (query.isEmpty) return null;
    return subsonicCall<_LibraryMatch?>(
      () => sub.get<dynamic>(
        SubsonicEndpoints.search3,
        queryParameters: <String, dynamic>{
          'query': query,
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
        return _LibraryMatch(
          id: id,
          coverArt: cover is String && cover.isNotEmpty ? cover : null,
        );
      },
    );
  }

  /// UI helper for pull-to-refresh. Invalidates self so seedCollection
  /// + recommend are both re-fetched on the next read.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Result of one row's `search3` library probe: the Navidrome song id +
/// (optionally) the album-cover id to render on the Home recommendation
/// card without a second `getSong` round-trip.
class _LibraryMatch {
  const _LibraryMatch({required this.id, this.coverArt});
  final String id;
  final String? coverArt;
}

/// Default freshness window for [RecommendHealthNotifier]. Calls to
/// `refreshIfStale` newer than this no-op; older ones invalidate the
/// provider so the next read re-fetches.
const Duration _kHealthMaxAge = Duration(seconds: 60);

/// Health of the configured recommendation engine. Backed by the backend's
/// `GET /api/v1/recommend/health` (shipped at I4).
///
/// Lifecycle:
///   - Keep-alive so the cached payload survives Settings tab switches.
///   - [refreshIfStale] is the hook for "events that should trigger a
///     re-fetch" — currently called on Settings screen open and on app
///     resume (router shell). 60 s TTL prevents thrashing when those
///     events fire in rapid succession.
///
/// Failures propagate as `AsyncError`; the Settings widget renders an
/// "unknown" chip in that case rather than a hard error pane.
@Riverpod(keepAlive: true)
class RecommendHealthNotifier extends _$RecommendHealthNotifier {
  DateTime? _lastFetchAt;

  @override
  Future<RecommendHealth> build() async {
    _lastFetchAt = DateTime.now();
    final Dio dio = await ref.watch(dioClientProvider.future);
    return apiCall<RecommendHealth>(
      () => dio.get<dynamic>(Endpoints.recommendHealth),
      (dynamic data) =>
          RecommendHealth.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Re-fetch when the cached payload is older than [maxAge]. No-ops
  /// when the cache is fresh — cheap to call from app-resume / screen-
  /// open paths without thrashing the backend.
  void refreshIfStale({Duration maxAge = _kHealthMaxAge}) {
    final DateTime? last = _lastFetchAt;
    if (last != null && DateTime.now().difference(last) < maxAge) return;
    ref.invalidateSelf();
  }
}
