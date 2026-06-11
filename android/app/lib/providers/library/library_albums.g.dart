// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_albums.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryAlbumsHash() => r'a5c74ead2f29c834d01690da45b615e15756d791';

/// Wraps `GET /rest/getAlbumList2.view?type=alphabeticalByName&size=500`.
/// Returns a flat A-Z album list for the Library tab's Albums sub-tab.
/// `getArtist(id)` gives per-artist albums but the Albums sub-tab needs a
/// global view, which Subsonic only exposes through `getAlbumList2`.
///
/// Copied from [libraryAlbums].
@ProviderFor(libraryAlbums)
final libraryAlbumsProvider = AutoDisposeFutureProvider<List<Album>>.internal(
  libraryAlbums,
  name: r'libraryAlbumsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$libraryAlbumsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LibraryAlbumsRef = AutoDisposeFutureProviderRef<List<Album>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
