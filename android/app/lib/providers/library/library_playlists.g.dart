// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_playlists.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryPlaylistsHash() => r'd2d54f7774731da5efb42bb145781fb38b1ccf2d';

/// Wraps `GET /rest/getPlaylists.view`. Returns the user's playlists as a
/// flat list. Each [Playlist] here has no `entry` populated — the detail
/// payload comes from `libraryPlaylist(id)`.
///
/// L5: cache-aware. See [libraryAlbums] for the list-encoding shape.
///
/// Copied from [libraryPlaylists].
@ProviderFor(libraryPlaylists)
final libraryPlaylistsProvider =
    AutoDisposeFutureProvider<List<Playlist>>.internal(
      libraryPlaylists,
      name: r'libraryPlaylistsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$libraryPlaylistsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LibraryPlaylistsRef = AutoDisposeFutureProviderRef<List<Playlist>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
