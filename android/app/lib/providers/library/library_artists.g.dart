// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_artists.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryArtistsHash() => r'1dd4e3df55e6754880e52e179972857dd1418cc0';

/// Wraps `GET /rest/getArtists.view` (via [SubsonicLibraryService]). Subsonic
/// groups artists into alphabetical buckets; we surface the flat
/// `List<ArtistIndex>`. Returns an empty list when the user has no library.
///
/// L5: cache-aware. See [libraryAlbums] for the list-encoding shape.
///
/// Copied from [libraryArtists].
@ProviderFor(libraryArtists)
final libraryArtistsProvider =
    AutoDisposeFutureProvider<List<ArtistIndex>>.internal(
      libraryArtists,
      name: r'libraryArtistsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$libraryArtistsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LibraryArtistsRef = AutoDisposeFutureProviderRef<List<ArtistIndex>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
