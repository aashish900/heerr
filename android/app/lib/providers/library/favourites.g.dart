// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favourites.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$favouritesPlaylistHash() =>
    r'1e9a00a307f6e5fd93267a73bd32ebaa3beed136';

/// Locates the user's Favourites playlist by matching
/// [kFavouritesPlaylistName] against [libraryPlaylistsProvider] for the
/// current `settings.navidromeUsername`. Returns `null` when:
///   - the Favourites playlist hasn't been lazy-created yet (first
///     ever heart-tap creates it via `toggleFavourite`),
///   - or no Navidrome username is configured.
///
/// Cache-aware via the underlying [libraryPlaylistsProvider] — fresh
/// after every `PlaylistMutations.createPlaylist` / `addSongs` /
/// `removeSongsAtIndices` invalidation.
///
/// Copied from [favouritesPlaylist].
@ProviderFor(favouritesPlaylist)
final favouritesPlaylistProvider =
    AutoDisposeFutureProvider<Playlist?>.internal(
      favouritesPlaylist,
      name: r'favouritesPlaylistProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$favouritesPlaylistHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FavouritesPlaylistRef = AutoDisposeFutureProviderRef<Playlist?>;
String _$favouriteSongIdsHash() => r'16d6b132b2fac80d684a606f6f0ee402ff7cedb1';

/// Set of song ids currently in the user's Favourites playlist. Empty
/// when no Favourites playlist exists yet. UI surfaces (heart icon)
/// watch this provider to know whether to render the filled-red heart.
///
/// Derived: watches [favouritesPlaylistProvider] → then
/// [libraryPlaylistProvider] with the favourites id to pull the entry
/// list. Both layers carry the invalidation chain from mutations so the
/// heart UI updates after a toggle without an explicit refresh.
///
/// Copied from [favouriteSongIds].
@ProviderFor(favouriteSongIds)
final favouriteSongIdsProvider =
    AutoDisposeFutureProvider<Set<String>>.internal(
      favouriteSongIds,
      name: r'favouriteSongIdsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$favouriteSongIdsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FavouriteSongIdsRef = AutoDisposeFutureProviderRef<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
