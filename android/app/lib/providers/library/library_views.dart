import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../models/subsonic/artist.dart';
import '../../models/subsonic/artist_index.dart';
import '../../models/subsonic/playlist.dart';
import '../../offline/offline_manifest.dart';
import 'library_albums.dart';
import 'library_artists.dart';
import 'library_filters.dart';
import 'library_playlists.dart';

part 'library_views.g.dart';

/// The Albums tab's view of the library (X3, LIBRARYSCREEN.md §4):
/// `libraryAlbumsProvider`'s full fetch, re-sorted per the sort chip and
/// optionally filtered to offline-marked albums. Pure derivation — no
/// network beyond the underlying cached fetch. The manifest is only awaited
/// when the Downloaded filter is on, so browsing stays independent of
/// offline-subsystem readiness.
@riverpod
Future<List<Album>> sortedLibraryAlbums(SortedLibraryAlbumsRef ref) async {
  final List<Album> albums = await ref.watch(libraryAlbumsProvider.future);
  final AlbumSort sort = ref.watch(albumSortNotifierProvider);
  final bool downloadedOnly =
      ref.watch(downloadedOnlyNotifierProvider(LibraryTab.albums));
  List<Album> out = sortAlbums(albums, sort);
  if (downloadedOnly) {
    final OfflineManifest manifest =
        await ref.watch(offlineManifestProvider.future);
    out = out
        .where((Album a) => manifest.markedAlbums.contains(a.id))
        .toList();
  }
  return out;
}

/// The Artists tab's view (X5): `getArtists`' alphabetical index buckets
/// flattened to one list, sorted per the chip. The Downloaded filter keeps
/// artists that are offline-marked themselves (`markedArtists`, L7) or have
/// at least one offline-marked album (joined through the cached albums
/// fetch on `Album.artistId`).
@riverpod
Future<List<Artist>> sortedLibraryArtists(SortedLibraryArtistsRef ref) async {
  final List<ArtistIndex> indices =
      await ref.watch(libraryArtistsProvider.future);
  final ArtistSort sort = ref.watch(artistSortNotifierProvider);
  final bool downloadedOnly =
      ref.watch(downloadedOnlyNotifierProvider(LibraryTab.artists));
  List<Artist> out = <Artist>[
    for (final ArtistIndex group in indices) ...group.artist,
  ];
  out.sort((Artist a, Artist b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (sort == ArtistSort.zToA) {
    out = out.reversed.toList();
  }
  if (downloadedOnly) {
    final OfflineManifest manifest =
        await ref.watch(offlineManifestProvider.future);
    final List<Album> albums = await ref.watch(libraryAlbumsProvider.future);
    final Set<String> artistsWithMarkedAlbums = albums
        .where((Album a) => manifest.markedAlbums.contains(a.id))
        .map((Album a) => a.artistId)
        .whereType<String>()
        .toSet();
    out = out
        .where((Artist a) =>
            manifest.markedArtists.contains(a.id) ||
            artistsWithMarkedAlbums.contains(a.id))
        .toList();
  }
  return out;
}

/// The Playlists tab's view (X6): the playlists fetch sorted per the chip,
/// optionally filtered to offline-marked playlists.
@riverpod
Future<List<Playlist>> sortedLibraryPlaylists(
    SortedLibraryPlaylistsRef ref) async {
  final List<Playlist> playlists =
      await ref.watch(libraryPlaylistsProvider.future);
  final PlaylistSort sort = ref.watch(playlistSortNotifierProvider);
  final bool downloadedOnly =
      ref.watch(downloadedOnlyNotifierProvider(LibraryTab.playlists));
  List<Playlist> out = sortPlaylists(playlists, sort);
  if (downloadedOnly) {
    final OfflineManifest manifest =
        await ref.watch(offlineManifestProvider.future);
    out = out
        .where((Playlist p) => manifest.markedPlaylists.contains(p.id))
        .toList();
  }
  return out;
}
