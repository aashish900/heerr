// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendations.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$seedCollectionHash() => r'f3804f4e65f4c9220f5494a736bf9d9c45f25a4a';

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
String _$recommendationsHash() => r'1a8d0fda66af4cdee0c73ddec85185d94accf7a8';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
