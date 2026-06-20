// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendations.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$seedCollectionHash() => r'ab8dc14207bc3a37b62e4f7b167cf9300db812bd';

/// Recommendation seed collection — input to the backend `POST /recommend`.
///
/// Order of operations:
///   1. `getStarred2.view` → starred songs.
///   2. `getAlbumList2.view?type=frequent&size=30` → frequently played albums.
///   3. If both came back empty, read the Favourites playlist via the
///      existing [favouritesPlaylistProvider] + [libraryPlaylistProvider]
///      chain.
///   4. Merge via [buildSeedCollection] — starred first, dedup, cap.
///
/// Errors from the Subsonic calls propagate to the caller as `AsyncError`.
///
/// Copied from [seedCollection].
@ProviderFor(seedCollection)
final seedCollectionProvider =
    AutoDisposeFutureProvider<List<SeedTrack>>.internal(
      seedCollection,
      name: r'seedCollectionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$seedCollectionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SeedCollectionRef = AutoDisposeFutureProviderRef<List<SeedTrack>>;
String _$recommendationsHash() => r'5d69080feaca6cf1470310f291fca44e2a491dc7';

/// Recommendation results from the heerr backend (`POST /api/v1/recommend`).
///
/// Reads the user's seed collection via [seedCollectionProvider] (N2), POSTs
/// `{seeds, limit: 20}` to the backend, returns the parsed [RecommendedTrack]
/// list for the UI.
///
/// When the seed collection is empty, still calls the backend with
/// `seeds: []` — the listenbrainz engine drives its own history-based
/// results, so the empty-seed case is meaningful there. ytmusic and lastfm
/// engines will return `[]` for empty seeds; the screen renders the
/// empty-state widget.
///
/// Copied from [Recommendations].
@ProviderFor(Recommendations)
final recommendationsProvider =
    AutoDisposeAsyncNotifierProvider<
      Recommendations,
      List<RecommendedTrack>
    >.internal(
      Recommendations.new,
      name: r'recommendationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recommendationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Recommendations = AutoDisposeAsyncNotifier<List<RecommendedTrack>>;
String _$recommendHealthNotifierHash() =>
    r'11162029cc7983c9f0d208d905d452428f73aa15';

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
///
/// Copied from [RecommendHealthNotifier].
@ProviderFor(RecommendHealthNotifier)
final recommendHealthNotifierProvider =
    AsyncNotifierProvider<RecommendHealthNotifier, RecommendHealth>.internal(
      RecommendHealthNotifier.new,
      name: r'recommendHealthNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recommendHealthNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RecommendHealthNotifier = AsyncNotifier<RecommendHealth>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
