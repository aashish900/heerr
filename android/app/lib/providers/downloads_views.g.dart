// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_views.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadedSongsViewHash() =>
    r'744710b09aa29c9e9adfc3b64a0d5fce60b0d736';

/// Downloads > Songs view: joins [downloadedSongsProvider] with each song's
/// manifest entry, then applies the DL5 chip state (sort, Lossless-only,
/// Downloaded-Today-only). Pure derivation over already-cached data — no
/// extra network beyond the underlying fetches.
///
/// Copied from [downloadedSongsView].
@ProviderFor(downloadedSongsView)
final downloadedSongsViewProvider =
    AutoDisposeFutureProvider<List<DownloadedSongRow>>.internal(
      downloadedSongsView,
      name: r'downloadedSongsViewProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadedSongsViewHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DownloadedSongsViewRef =
    AutoDisposeFutureProviderRef<List<DownloadedSongRow>>;
String _$sortedDownloadedAlbumsHash() =>
    r'6b5055e381b78ae2197a9cd34a44fdce7607cbc3';

/// Downloads > Albums view: resolves every downloaded album id
/// (`downloadedAlbumIdsProvider`) to its full metadata and sorts per the
/// chip, reusing `sortAlbums` (`library_filters.dart`) rather than
/// duplicating the sort logic.
///
/// Copied from [sortedDownloadedAlbums].
@ProviderFor(sortedDownloadedAlbums)
final sortedDownloadedAlbumsProvider =
    AutoDisposeFutureProvider<List<Album>>.internal(
      sortedDownloadedAlbums,
      name: r'sortedDownloadedAlbumsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortedDownloadedAlbumsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SortedDownloadedAlbumsRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$sortedDownloadedPlaylistsHash() =>
    r'9350d82263bd0d4d97792264b94768eef9805eaa';

/// Downloads > Playlists view: resolves every marked playlist to its full
/// metadata and sorts per the chip, reusing `sortPlaylists`.
///
/// Copied from [sortedDownloadedPlaylists].
@ProviderFor(sortedDownloadedPlaylists)
final sortedDownloadedPlaylistsProvider =
    AutoDisposeFutureProvider<List<Playlist>>.internal(
      sortedDownloadedPlaylists,
      name: r'sortedDownloadedPlaylistsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortedDownloadedPlaylistsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SortedDownloadedPlaylistsRef =
    AutoDisposeFutureProviderRef<List<Playlist>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
