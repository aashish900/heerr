import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/subsonic/album.dart';
import '../models/subsonic/artist.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../offline/offline_manifest.dart';
import 'library/library_album.dart';
import 'library/library_artist.dart';
import 'library/library_playlist.dart';

part 'downloaded_songs.g.dart';

/// Union of album ids that have downloaded content for the active server.
/// `markedAlbums` plus every album reached through a `markedArtists`
/// expansion. Sorted alphabetically by id for a stable list order.
///
/// Surfaced as a standalone provider so the Downloads → Albums tab and
/// [downloadedSongs] both consume the same expansion logic. Without
/// this, marking an artist downloads the songs but never surfaces the
/// album rows / song rows in the Downloads screen.
@riverpod
Future<List<String>> downloadedAlbumIds(DownloadedAlbumIdsRef ref) async {
  final OfflineManifest manifest =
      await ref.watch(offlineManifestProvider.future);
  final Set<String> ids = <String>{...manifest.markedAlbums};
  for (final String artistId in manifest.markedArtists) {
    try {
      final Artist artist =
          await ref.watch(libraryArtistProvider(artistId).future);
      for (final Album a in artist.album) {
        ids.add(a.id);
      }
    } catch (_) {
      // Missing artist cache shouldn't strand the whole tab.
    }
  }
  final List<String> out = ids.toList()..sort();
  return out;
}

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
@riverpod
Future<List<Song>> downloadedSongs(DownloadedSongsRef ref) async {
  final OfflineManifest manifest = await ref.watch(offlineManifestProvider.future);
  final Set<String> readyIds = <String>{
    for (final MapEntry<String, OfflineSongEntry> e in manifest.songs.entries)
      if (e.value.state == OfflineSongState.ready) e.key,
  };
  if (readyIds.isEmpty) return <Song>[];

  // Fan-out: resolve every relevant album (markedAlbums ∪ artist-expanded)
  // and every marked playlist in parallel.
  final List<String> albumIds =
      await ref.watch(downloadedAlbumIdsProvider.future);
  final List<Future<Album>> albumFutures = albumIds
      .map((String id) => ref.watch(libraryAlbumProvider(id).future))
      .toList();
  final List<Future<Playlist>> playlistFutures = manifest.markedPlaylists
      .map((String id) => ref.watch(libraryPlaylistProvider(id).future))
      .toList();

  // Tolerate failures on individual albums / playlists — a single missing
  // cache shouldn't blank the whole Songs tab.
  final List<Album> albums = <Album>[];
  for (final Future<Album> f in albumFutures) {
    try {
      albums.add(await f);
    } catch (_) {/* skip */}
  }
  final List<Playlist> playlists = <Playlist>[];
  for (final Future<Playlist> f in playlistFutures) {
    try {
      playlists.add(await f);
    } catch (_) {/* skip */}
  }

  // Subsonic's `getAlbum.view` often leaves `Song.coverArt` empty and
  // expects the client to inherit from the parent album. `getPlaylist`
  // usually populates the per-song coverArt because playlist entries
  // span multiple albums — keep whatever it sent.
  Song withCover(Song s, String? fallback) {
    if (s.coverArt != null && s.coverArt!.isNotEmpty) return s;
    if (fallback == null || fallback.isEmpty) return s;
    return s.copyWith(coverArt: fallback);
  }

  final Map<String, Song> bySongId = <String, Song>{};
  for (final Album a in albums) {
    for (final Song s in a.song) {
      if (readyIds.contains(s.id)) {
        bySongId[s.id] = withCover(s, a.coverArt ?? a.id);
      }
    }
  }
  for (final Playlist p in playlists) {
    for (final Song s in p.entry) {
      if (readyIds.contains(s.id)) bySongId.putIfAbsent(s.id, () => s);
    }
  }

  final List<Song> out = bySongId.values.toList()
    ..sort((Song a, Song b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return out;
}
