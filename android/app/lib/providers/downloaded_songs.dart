import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../offline/offline_manifest.dart';
import 'library/library_album.dart';
import 'library/library_playlist.dart';

part 'downloaded_songs.g.dart';

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
@riverpod
Future<List<Song>> downloadedSongs(DownloadedSongsRef ref) async {
  final OfflineManifest manifest = await ref.watch(offlineManifestProvider.future);
  final Set<String> readyIds = <String>{
    for (final MapEntry<String, OfflineSongEntry> e in manifest.songs.entries)
      if (e.value.state == OfflineSongState.ready) e.key,
  };
  if (readyIds.isEmpty) return <Song>[];

  // Fan-out: resolve every marked album + playlist in parallel.
  final List<Future<Album>> albumFutures = manifest.markedAlbums
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

  final Map<String, Song> bySongId = <String, Song>{};
  for (final Album a in albums) {
    for (final Song s in a.song) {
      if (readyIds.contains(s.id)) bySongId[s.id] = s;
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
