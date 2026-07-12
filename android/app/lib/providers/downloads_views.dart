import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../offline/offline_manifest.dart';
import 'downloaded_songs.dart';
import 'downloads_filters.dart';
import 'library/library_album.dart';
import 'library/library_filters.dart';
import 'library/library_playlist.dart';

part 'downloads_views.g.dart';

/// One row of the Downloads > Songs tab: the resolved [Song] metadata plus
/// its manifest entry (size/suffix/downloadedAt — DL6, DOWNLOADSSCREEN.md
/// §4).
typedef DownloadedSongRow = ({Song song, OfflineSongEntry entry});

/// D7: a suffix counts as "Lossless" if it's in this set, not just `flac`.
const Set<String> kLosslessSuffixes = <String>{'flac', 'alac', 'wav'};

/// Downloads > Songs view: joins [downloadedSongsProvider] with each song's
/// manifest entry, then applies the DL5 chip state (sort, Lossless-only,
/// Downloaded-Today-only). Pure derivation over already-cached data — no
/// extra network beyond the underlying fetches.
@riverpod
Future<List<DownloadedSongRow>> downloadedSongsView(
  DownloadedSongsViewRef ref,
) async {
  final List<Song> songs = await ref.watch(downloadedSongsProvider.future);
  final OfflineManifest manifest = await ref.watch(offlineManifestProvider.future);

  List<DownloadedSongRow> rows = <DownloadedSongRow>[
    for (final Song s in songs)
      if (manifest.songs[s.id] != null) (song: s, entry: manifest.songs[s.id]!),
  ];

  if (ref.watch(downloadsLosslessOnlyNotifierProvider)) {
    rows = rows
        .where((DownloadedSongRow r) =>
            kLosslessSuffixes.contains(r.entry.suffix?.toLowerCase()))
        .toList();
  }

  if (ref.watch(downloadsTodayOnlyNotifierProvider)) {
    final DateTime now = DateTime.now();
    rows = rows.where((DownloadedSongRow r) {
      final DateTime? at = r.entry.downloadedAt;
      return at != null &&
          at.year == now.year &&
          at.month == now.month &&
          at.day == now.day;
    }).toList();
  }

  return sortDownloadedSongRows(rows, ref.watch(downloadsSongSortNotifierProvider));
}

int _byTitle(Song a, Song b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());

/// Pure sort helper — unit-testable, mirrors `sortAlbums`/`sortPlaylists`
/// (`library_filters.dart`).
List<DownloadedSongRow> sortDownloadedSongRows(
  List<DownloadedSongRow> rows,
  DownloadsSongSort sort,
) {
  final List<DownloadedSongRow> out = List<DownloadedSongRow>.of(rows);
  switch (sort) {
    case DownloadsSongSort.recent:
      out.sort((DownloadedSongRow a, DownloadedSongRow b) {
        final DateTime? da = a.entry.downloadedAt;
        final DateTime? db = b.entry.downloadedAt;
        if (da == null && db == null) return _byTitle(a.song, b.song);
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    case DownloadsSongSort.largest:
      out.sort((DownloadedSongRow a, DownloadedSongRow b) {
        final int cmp = (b.entry.size ?? 0).compareTo(a.entry.size ?? 0);
        return cmp != 0 ? cmp : _byTitle(a.song, b.song);
      });
    case DownloadsSongSort.aToZ:
      out.sort((DownloadedSongRow a, DownloadedSongRow b) => _byTitle(a.song, b.song));
  }
  return out;
}

AlbumSort _toAlbumSort(DownloadsContainerSort s) =>
    s == DownloadsContainerSort.recent ? AlbumSort.recentlyAdded : AlbumSort.alphabetical;

PlaylistSort _toPlaylistSort(DownloadsContainerSort s) =>
    s == DownloadsContainerSort.recent ? PlaylistSort.recentlyAdded : PlaylistSort.alphabetical;

/// Downloads > Albums view: resolves every downloaded album id
/// (`downloadedAlbumIdsProvider`) to its full metadata and sorts per the
/// chip, reusing `sortAlbums` (`library_filters.dart`) rather than
/// duplicating the sort logic.
@riverpod
Future<List<Album>> sortedDownloadedAlbums(SortedDownloadedAlbumsRef ref) async {
  final List<String> ids = await ref.watch(downloadedAlbumIdsProvider.future);
  final List<Album> albums = <Album>[];
  for (final String id in ids) {
    try {
      albums.add(await ref.watch(libraryAlbumProvider(id).future));
    } catch (_) {
      // Missing cache shouldn't strand the whole tab.
    }
  }
  final DownloadsContainerSort sort = ref.watch(downloadsAlbumSortNotifierProvider);
  return sortAlbums(albums, _toAlbumSort(sort));
}

/// Downloads > Playlists view: resolves every marked playlist to its full
/// metadata and sorts per the chip, reusing `sortPlaylists`.
@riverpod
Future<List<Playlist>> sortedDownloadedPlaylists(
  SortedDownloadedPlaylistsRef ref,
) async {
  final OfflineManifest manifest = await ref.watch(offlineManifestProvider.future);
  final List<Playlist> playlists = <Playlist>[];
  for (final String id in manifest.markedPlaylists) {
    try {
      playlists.add(await ref.watch(libraryPlaylistProvider(id).future));
    } catch (_) {
      // Missing cache shouldn't strand the whole tab.
    }
  }
  final DownloadsContainerSort sort = ref.watch(downloadsPlaylistSortNotifierProvider);
  return sortPlaylists(playlists, _toPlaylistSort(sort));
}
