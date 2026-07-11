// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_views.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sortedLibraryAlbumsHash() =>
    r'f09ad1fa0114daf8f1fc34b0ab0507228487ca25';

/// The Albums tab's view of the library (X3, LIBRARYSCREEN.md §4):
/// `libraryAlbumsProvider`'s full fetch, re-sorted per the sort chip and
/// optionally filtered to offline-marked albums. Pure derivation — no
/// network beyond the underlying cached fetch. The manifest is only awaited
/// when the Downloaded filter is on, so browsing stays independent of
/// offline-subsystem readiness.
///
/// Copied from [sortedLibraryAlbums].
@ProviderFor(sortedLibraryAlbums)
final sortedLibraryAlbumsProvider =
    AutoDisposeFutureProvider<List<Album>>.internal(
      sortedLibraryAlbums,
      name: r'sortedLibraryAlbumsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortedLibraryAlbumsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SortedLibraryAlbumsRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$sortedLibraryArtistsHash() =>
    r'2dba1c1ec57abac1b6c3bad92d284e0b7fc9e853';

/// The Artists tab's view (X5): `getArtists`' alphabetical index buckets
/// flattened to one list, sorted per the chip. The Downloaded filter keeps
/// artists that are offline-marked themselves (`markedArtists`, L7) or have
/// at least one offline-marked album (joined through the cached albums
/// fetch on `Album.artistId`).
///
/// Copied from [sortedLibraryArtists].
@ProviderFor(sortedLibraryArtists)
final sortedLibraryArtistsProvider =
    AutoDisposeFutureProvider<List<Artist>>.internal(
      sortedLibraryArtists,
      name: r'sortedLibraryArtistsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortedLibraryArtistsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SortedLibraryArtistsRef = AutoDisposeFutureProviderRef<List<Artist>>;
String _$sortedLibraryPlaylistsHash() =>
    r'ed6b60d0023ca423be7826f9625146546753fecf';

/// The Playlists tab's view (X6): the playlists fetch sorted per the chip,
/// optionally filtered to offline-marked playlists.
///
/// Copied from [sortedLibraryPlaylists].
@ProviderFor(sortedLibraryPlaylists)
final sortedLibraryPlaylistsProvider =
    AutoDisposeFutureProvider<List<Playlist>>.internal(
      sortedLibraryPlaylists,
      name: r'sortedLibraryPlaylistsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortedLibraryPlaylistsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SortedLibraryPlaylistsRef =
    AutoDisposeFutureProviderRef<List<Playlist>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
