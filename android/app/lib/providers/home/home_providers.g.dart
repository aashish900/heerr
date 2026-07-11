// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeRecentHash() => r'f581847298c440b2973da7c7b95ac43ec2fb8e4e';

/// Recently-played albums (`getAlbumList2.view?type=recent`). The Home
/// screen's "Jump back in" section and primary quick-access grid use this.
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
String _$homeMostPlayedHash() => r'aedf0b6d456a21b116838ef28f6b03e7e5a4169a';

/// Most-played albums (`getAlbumList2.view?type=frequent`). Powers the Home
/// screen's "Most played" horizontal section.
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
String _$homeNewestHash() => r'69a3cf9146eb5eb9e573f49c832648a5a1a23ff3';

/// Recently-added albums (`getAlbumList2.view?type=newest` — Subsonic
/// "newest" = most recently *added*, distinct from `recent` = recently
/// *played*). Powers the Home screen's "Recently Added" vertical section
/// (redesign — HOMESCREEN.md task 4).
///
/// Copied from [homeNewest].
@ProviderFor(homeNewest)
final homeNewestProvider = AutoDisposeFutureProvider<List<Album>>.internal(
  homeNewest,
  name: r'homeNewestProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeNewestHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeNewestRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$recentlyAddedFullHash() => r'1387272ee13674b8026012e40b3f8d7fb3ae9da1';

/// Full recently-added list for the "See all" screen. Separate provider
/// (not a rerun of [homeNewest]) so the Home section's 8-row fetch and the
/// screen's 50-row fetch cache independently.
///
/// Copied from [recentlyAddedFull].
@ProviderFor(recentlyAddedFull)
final recentlyAddedFullProvider =
    AutoDisposeFutureProvider<List<Album>>.internal(
      recentlyAddedFull,
      name: r'recentlyAddedFullProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentlyAddedFullHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentlyAddedFullRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$homeRandomSongsHash() => r'c94555a3bda9d6fbae4b3dfe3649068612f1e8c7';

/// Random songs from the library (`getRandomSongs.view`). Used as the
/// universal fallback when backend recommendations come back empty, and as a
/// fill-in for the quick-access grid when "recently played" is empty.
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
/// empty list the notifier maps [homeRandomSongs] to `RecommendedTrack` shape
/// so the section still has content. Songs are local, so `inLibrary=true` and
/// `subsonicSongId` is populated; `sourceUrl` is empty.
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
