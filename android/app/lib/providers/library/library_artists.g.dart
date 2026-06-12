// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_artists.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryArtistsHash() => r'e94529949fde6aa53186058687f509878205f443';

/// Wraps `GET /rest/getArtists.view`. Subsonic groups artists into
/// alphabetical buckets after applying `ignoredArticles`; the envelope is:
///
/// ```
/// "artists": { "ignoredArticles": "...", "index": [{name, artist: [...]}, ...] }
/// ```
///
/// We surface the flat `List<ArtistIndex>` — UI typically renders them
/// sectioned, but the provider doesn't decide that. Returns an empty list
/// when the user has no library (no `index` field).
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
