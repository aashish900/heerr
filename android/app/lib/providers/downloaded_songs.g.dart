// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_songs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadedSongsHash() => r'd0a6f6b87b6294aa4d93faa950d5979c9c7fff07';

/// All songs that have a `ready` entry in the offline manifest, resolved
/// to their full `Song` metadata via the marked albums + playlists.
///
/// Used by the Downloads screen's "Songs" tab. The traversal is fan-out:
/// every marked album / playlist is fetched in parallel through the
/// existing cache-aware providers, so this works fully offline as long
/// as the L5 library cache has been populated.
///
/// Songs that appear in both an album and a playlist are deduplicated by
/// id. The output is sorted alphabetically by title for a stable feel.
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
