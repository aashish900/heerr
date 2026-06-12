// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_songs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadedAlbumIdsHash() =>
    r'a34638c8a7a182e926032273ff8902e569976757';

/// Union of album ids that have downloaded content for the active server.
/// `markedAlbums` plus every album reached through a `markedArtists`
/// expansion. Sorted alphabetically by id for a stable list order.
///
/// Surfaced as a standalone provider so the Downloads → Albums tab and
/// [downloadedSongs] both consume the same expansion logic. Without
/// this, marking an artist downloads the songs but never surfaces the
/// album rows / song rows in the Downloads screen.
///
/// Copied from [downloadedAlbumIds].
@ProviderFor(downloadedAlbumIds)
final downloadedAlbumIdsProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
      downloadedAlbumIds,
      name: r'downloadedAlbumIdsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadedAlbumIdsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DownloadedAlbumIdsRef = AutoDisposeFutureProviderRef<List<String>>;
String _$downloadedSongsHash() => r'e766177a2be25493013e5ee1fa43c738f0babe04';

/// All songs that have a `ready` entry in the offline manifest, resolved
/// to their full `Song` metadata via the marked albums + playlists +
/// artist expansion.
///
/// Used by the Downloads screen's "Songs" tab. The traversal is fan-out:
/// every relevant album / playlist is fetched in parallel through the
/// existing cache-aware providers, so this works fully offline as long
/// as the L5 library cache has been populated.
///
/// Songs that appear in multiple containers are deduplicated by id. The
/// output is sorted alphabetically by title for a stable feel.
///
/// Copied from [downloadedSongs].
@ProviderFor(downloadedSongs)
final downloadedSongsProvider = AutoDisposeFutureProvider<List<Song>>.internal(
  downloadedSongs,
  name: r'downloadedSongsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadedSongsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DownloadedSongsRef = AutoDisposeFutureProviderRef<List<Song>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
