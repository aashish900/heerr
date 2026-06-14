// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeRecentHash() => r'3fd32a3b9e1215774b328db34073d5c60596524e';

/// Recently-played albums (Subsonic `getAlbumList2.view?type=recent`). The
/// Home screen's "Jump back in" section and primary quick-access grid use
/// this. Empty list when the library hasn't been played yet.
///
/// Copied from [homeRecent].
@ProviderFor(homeRecent)
final homeRecentProvider = AutoDisposeFutureProvider<List<Album>>.internal(
  homeRecent,
  name: r'homeRecentProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeRecentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeRecentRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$homeMostPlayedHash() => r'2141ae0ce4e424cca7a556c818b5ba78f4bcdc09';

/// Most-played albums (Subsonic `getAlbumList2.view?type=frequent`). Powers
/// the Home screen's "Most played" horizontal section.
///
/// Copied from [homeMostPlayed].
@ProviderFor(homeMostPlayed)
final homeMostPlayedProvider = AutoDisposeFutureProvider<List<Album>>.internal(
  homeMostPlayed,
  name: r'homeMostPlayedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeMostPlayedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeMostPlayedRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$homeRandomSongsHash() => r'72b0c576599e763cb564bda299ae5078a1d60652';

/// Random songs from the library (Subsonic `getRandomSongs.view`). Used as
/// the universal fallback when the backend recommendations come back empty
/// (a fresh deploy with no scrobble history) and as a fill-in for the
/// quick-access grid when "recently played" is empty.
///
/// Copied from [homeRandomSongs].
@ProviderFor(homeRandomSongs)
final homeRandomSongsProvider = AutoDisposeFutureProvider<List<Song>>.internal(
  homeRandomSongs,
  name: r'homeRandomSongsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeRandomSongsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeRandomSongsRef = AutoDisposeFutureProviderRef<List<Song>>;
String _$homeRecommendationsHash() =>
    r'e6433daa110e09e753c6a398a12926a76cf48825';

/// Recommendation feed for the Home screen.
///
/// Primary source: [recommendationsProvider] (already library-cross-
/// referenced via the N4 `search3` hydration step). When that returns an
/// empty list (no seeds, engine-down with empty fallback chain, etc.) the
/// notifier maps [homeRandomSongs] to `RecommendedTrack` shape so the
/// section still has content. Songs are local, so `inLibrary=true` and
/// `subsonicSongId` is populated; `sourceUrl` is empty (random songs have
/// no upstream URL).
///
/// Copied from [homeRecommendations].
@ProviderFor(homeRecommendations)
final homeRecommendationsProvider =
    AutoDisposeFutureProvider<HomeRecommendations>.internal(
      homeRecommendations,
      name: r'homeRecommendationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$homeRecommendationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeRecommendationsRef =
    AutoDisposeFutureProviderRef<HomeRecommendations>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
