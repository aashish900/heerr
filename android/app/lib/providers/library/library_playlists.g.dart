// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_playlists.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryPlaylistsHash() => r'945f75e1e94c51741db05876cc71c00a7bdbdefd';

/// Wraps `GET /rest/getPlaylists.view` (via [SubsonicLibraryService]). Returns
/// the user's playlists as a flat list; each [Playlist] here has no `entry`
/// populated — the detail payload comes from `libraryPlaylist(id)`.
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
