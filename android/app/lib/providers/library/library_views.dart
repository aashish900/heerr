import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../offline/offline_manifest.dart';
import 'library_albums.dart';
import 'library_filters.dart';

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
