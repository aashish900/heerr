import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/recommend_health.dart';
import '../models/recommended_track.dart';
import '../models/seed_track.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../services/backend_service.dart';
import '../services/subsonic_library_service.dart';
import 'library/favourites.dart';
import 'library/library_playlist.dart';

part 'recommendations.g.dart';

/// `limit` sent to the backend's `POST /api/v1/recommend` — its schema cap
/// (`le=50`). Every result left after owned songs are dropped is shown: the
/// For You screen scrolls and the Home grid slides sideways, so there is no
/// display cap.
const int _kRecommendationsLimit = 50;

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

/// Size requested from `getAlbumList2.view?type=recent` (RX8).
const int _kRecentAlbumSize = 20;

/// Seed weights (RX8): a starred song is the strongest signal; an artist you
/// play a lot beats one you merely played recently.
const double _kStarredWeight = 1.0;
const double _kFrequentArtistWeight = 0.7;
const double _kRecentArtistWeight = 0.4;

/// Pure merge function — kept separate from the provider so the rules are
/// testable without standing up a Riverpod container.
///
/// Output order, capped at [maxSeeds] overall:
///   1. `starred` songs → **song seeds** at weight 1.0, deduped by
///      case-insensitive, whitespace-trimmed `title|artist`.
///   2. `frequent` albums → **artist seeds** (title null) at weight 0.7.
///   3. `recent` albums → artist seeds at weight 0.4.
///   Artist seeds dedupe by trimmed lowercase artist; the first (highest
///   weight) occurrence wins. An album never becomes a song seed — pre-RX8 the
///   album name was sent as a song title and the backend resolved it to an
///   arbitrary track.
///   4. `favourites` songs → song seeds, **only** when 1–3 produced nothing.
///
/// A song seed and an artist seed for the same artist are both kept: they
/// ask the backend different questions (similar-to-this-song vs this artist's
/// top songs).
List<SeedTrack> buildSeedCollection({
  required List<Song> starred,
  required List<Album> frequent,
  List<Album> recent = const <Album>[],
  required List<Song> favourites,
  int maxSeeds = _kMaxSeeds,
}) {
  // ponytail: starred songs fill the cap first; a user with 20+ starred songs
  // gets no artist seeds. Reserve slots per source if that starves variety.
  final List<SeedTrack> out = <SeedTrack>[];
  final Set<String> seenSongs = <String>{};
  final Set<String> seenArtists = <String>{};

  String norm(String v) => v.toLowerCase().trim();
  bool blank(String? v) => v == null || v.trim().isEmpty;

  void addSong(String? title, String? artist) {
    if (out.length >= maxSeeds || blank(title) || blank(artist)) return;
    if (!seenSongs.add('${norm(title!)}|${norm(artist!)}')) return;
    out.add(SeedTrack(title: title, artist: artist, weight: _kStarredWeight));
  }

  void addArtist(String? artist, double weight) {
    if (out.length >= maxSeeds || blank(artist)) return;
    if (!seenArtists.add(norm(artist!))) return;
    out.add(SeedTrack(artist: artist, weight: weight));
  }

  for (final Song s in starred) {
    addSong(s.title, s.artist);
  }
  for (final Album a in frequent) {
    addArtist(a.artist, _kFrequentArtistWeight);
  }
  for (final Album a in recent) {
    addArtist(a.artist, _kRecentArtistWeight);
  }

  if (out.isEmpty) {
    for (final Song s in favourites) {
      addSong(s.title, s.artist);
    }
  }

  return out;
}

/// Recommendation seed collection — input to the backend `POST /recommend`.
///
/// Order of operations:
///   1. `getStarred2.view` → starred songs.
///   2. `getAlbumList2.view?type=frequent&size=30` → frequently played albums.
///   3. `getAlbumList2.view?type=recent&size=20` → recently played albums.
///   4. If all three came back empty, read the Favourites playlist via the
///      existing [favouritesPlaylistProvider] + [libraryPlaylistProvider]
///      chain.
///   5. Merge via [buildSeedCollection] — song seeds, then artist seeds.
///
/// Errors from the Subsonic calls propagate to the caller as `AsyncError`.
@riverpod
Future<List<SeedTrack>> seedCollection(SeedCollectionRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);

  final List<Song> starred = await service.getStarredSongs();
  final List<Album> frequent =
      await service.getAlbumList(type: 'frequent', size: _kFrequentAlbumSize);
  final List<Album> recent =
      await service.getAlbumList(type: 'recent', size: _kRecentAlbumSize);

  List<Song> favourites = const <Song>[];
  if (starred.isEmpty && frequent.isEmpty && recent.isEmpty) {
    favourites = await _fetchFavouriteSongs(ref);
  }

  return buildSeedCollection(
    starred: starred,
    frequent: frequent,
    recent: recent,
    favourites: favourites,
  );
}

Future<List<Song>> _fetchFavouriteSongs(SeedCollectionRef ref) async {
  final Playlist? fav = await ref.watch(favouritesPlaylistProvider.future);
  if (fav == null) return const <Song>[];
  final Playlist detail =
      await ref.watch(libraryPlaylistProvider(fav.id).future);
  return detail.entry;
}

/// Number of seeds actually sent per `POST /recommend` request. Deliberately
/// smaller than [_kMaxSeeds]: the backend is deterministic for a given seed
/// set, so sampling a random subset per request is what makes a refresh
/// return *different* recommendations (#38).
const int kSeedSampleSize = 8;

/// Injectable RNG for [sampleSeeds] so tests can pin a seed. The single
/// instance is stateful on purpose — successive refreshes draw successive
/// shuffles from it, guaranteeing variety even when the underlying seed
/// collection is unchanged.
final recommendationRngProvider = Provider<Random>((Ref ref) => Random());

/// Pure, testable sampling: a shuffled copy of [seeds] capped at
/// [sampleSize]. Shuffles even when `seeds.length <= sampleSize` so seed
/// *order* also varies per request (engines rank per seed). Never mutates
/// the input.
List<SeedTrack> sampleSeeds(
  List<SeedTrack> seeds, {
  required Random rng,
  int sampleSize = kSeedSampleSize,
}) {
  final List<SeedTrack> copy = List<SeedTrack>.of(seeds)..shuffle(rng);
  return copy.length <= sampleSize ? copy : copy.sublist(0, sampleSize);
}

/// Recommendation results from the heerr backend (`POST /api/v1/recommend`).
///
/// Reads the user's seed collection via [seedCollectionProvider] (N2), POSTs
/// `{seeds, limit: 50}` to the backend, and returns every parsed
/// [RecommendedTrack] that is **not** already in the library (RX8).
///
/// When the seed collection is empty, still calls the backend with
/// `seeds: []` — the listenbrainz engine drives its own history-based
/// results, so the empty-seed case is meaningful there. Other engines
/// will return `[]` for empty seeds; the screen renders the
/// empty-state widget.
/// Freshness window for [Recommendations.refreshIfStale] (#38). Calls newer
/// than this no-op; older ones invalidate so the next read re-fetches with a
/// fresh seed sample.
const Duration _kRecsMaxAge = Duration(minutes: 30);

@Riverpod(keepAlive: true)
class Recommendations extends _$Recommendations {
  /// Set at build *start* so a [refreshIfStale] racing an in-flight build
  /// no-ops (cold start: Home initState fires while the first build runs).
  DateTime? _lastFetchAt;

  @override
  Future<List<RecommendedTrack>> build() async {
    _lastFetchAt = DateTime.now();
    final SeedTrack? manual = ref.watch(manualSeedProvider);
    final List<SeedTrack> seeds;
    if (manual != null) {
      // "Find similar" — sole seed, never sampled.
      seeds = <SeedTrack>[manual];
    } else {
      // `read`, not `watch`, for the RNG — its identity must not trigger
      // rebuilds; its statefulness across rebuilds is what varies the sample.
      seeds = sampleSeeds(
        await ref.watch(seedCollectionProvider.future),
        rng: ref.read(recommendationRngProvider),
      );
    }

    final BackendService backend =
        await ref.watch(backendServiceProvider.future);
    final List<RecommendedTrack> base =
        await backend.recommend(seeds: seeds, limit: _kRecommendationsLimit);

    if (base.isEmpty) return base;

    // Cross-reference each result against the Subsonic library via
    // `search3`. Library-side failures are swallowed per result so one bad
    // search3 doesn't kill the whole list — the result just falls through as
    // inLibrary=false. For You recommends songs you don't own yet (RX8), so
    // owned matches are dropped.
    final List<RecommendedTrack> hydrated = await _hydrateLibraryMatches(base);
    return hydrated.where((RecommendedTrack r) => !r.inLibrary).toList();
  }

  Future<List<RecommendedTrack>> _hydrateLibraryMatches(
    List<RecommendedTrack> base,
  ) async {
    final SubsonicLibraryService service;
    try {
      service = await ref.watch(subsonicLibraryServiceProvider.future);
    } catch (_) {
      // Navidrome not configured — every row stays remote-only.
      return base;
    }

    Future<RecommendedTrack> resolveOne(RecommendedTrack r) async {
      try {
        final SubsonicSongMatch? match =
            await service.findLibraryMatch('${r.artist} ${r.title}');
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

  /// UI helper for pull-to-refresh. Invalidates self so seedCollection
  /// + recommend are both re-fetched on the next read.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Re-fetch when the cached feed is older than [maxAge]. No-ops when the
  /// cache is fresh or when a manual "Find similar" seed is active — the
  /// seeded view must never be silently replaced by the general feed
  /// (invalidating would re-run the same sole seed, but the reload flash is
  /// unwanted on a screen the user deliberately opened). Cheap to call from
  /// Home-open / app-resume paths (#38).
  void refreshIfStale({Duration maxAge = _kRecsMaxAge}) {
    if (ref.read(manualSeedProvider) != null) return;
    final DateTime? last = _lastFetchAt;
    if (last != null && DateTime.now().difference(last) < maxAge) return;
    ref.invalidateSelf();
  }
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
///     resume (lifecycle coordinator). 60 s TTL prevents thrashing.
///
/// Failures propagate as `AsyncError`; the Settings widget renders an
/// "unknown" chip in that case rather than a hard error pane.
@Riverpod(keepAlive: true)
class RecommendHealthNotifier extends _$RecommendHealthNotifier {
  DateTime? _lastFetchAt;

  @override
  Future<RecommendHealth> build() async {
    _lastFetchAt = DateTime.now();
    final BackendService backend =
        await ref.watch(backendServiceProvider.future);
    return backend.recommendHealth();
  }

  /// Re-fetch when the cached payload is older than [maxAge]. No-ops when the
  /// cache is fresh — cheap to call from app-resume / screen-open paths.
  void refreshIfStale({Duration maxAge = _kHealthMaxAge}) {
    final DateTime? last = _lastFetchAt;
    if (last != null && DateTime.now().difference(last) < maxAge) return;
    ref.invalidateSelf();
  }
}
