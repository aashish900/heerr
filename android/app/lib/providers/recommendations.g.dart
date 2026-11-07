// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendations.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$seedCollectionHash() => r'8d397e7ca0c79b57a78f18ac1d180b181ea8cec5';

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
String _$recommendationsHash() => r'97c8460c55a1c48c5eadc8fe3e4dd7a4cdb2a540';

/// See also [Recommendations].
@ProviderFor(Recommendations)
final recommendationsProvider =
    AsyncNotifierProvider<Recommendations, List<RecommendedTrack>>.internal(
      Recommendations.new,
      name: r'recommendationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recommendationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Recommendations = AsyncNotifier<List<RecommendedTrack>>;
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
