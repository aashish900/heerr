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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
