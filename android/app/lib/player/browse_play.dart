import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subsonic/artist.dart';
import '../models/subsonic/song.dart';
import '../providers/library/library_artist.dart';
import '../providers/server_creds.dart';
import 'browse_ids.dart';
import 'browse_tree.dart';
import 'play_core.dart';

/// Android Auto `playFromMediaId`: resolve [id] to a queue and hand it to
/// [playAll]. A song queues its whole parent (album / playlist / favourites /
/// downloaded) starting at that song; an album, playlist or artist plays from
/// the top. Anything else (tabs, a song with no parent, missing creds) is a
/// no-op.
Future<void> playBrowseId(
  ProviderContainer c,
  BrowseId id,
  Future<void> Function(List<MediaItem> items, int startIndex) playAll,
) async {
  final ServerCreds creds = c.read(serverCredsProvider);
  final String? url = creds.navidromeBaseUrl;
  final String? user = creds.navidromeUsername;
  final String? pass = creds.navidromePassword;
  if (url == null ||
      url.isEmpty ||
      user == null ||
      user.isEmpty ||
      pass == null ||
      pass.isEmpty) {
    return;
  }

  final List<Song> songs;
  int start = 0;
  switch (id.kind) {
    case BrowseKind.song:
      final BrowseId? parent = id.parent;
      if (parent == null) return;
      songs = await songsOf(c, parent);
      start = songs.indexWhere((Song s) => s.id == id.id);
    case BrowseKind.artist:
      final Artist artist = await c.read(libraryArtistProvider(id.id!).future);
      songs = await songsForArtist(c.read, artist);
    case BrowseKind.album:
    case BrowseKind.playlist:
      songs = await songsOf(c, id);
    default:
      return;
  }
  if (songs.isEmpty) return;

  final List<MediaItem> items = await Future.wait<MediaItem>(
    songs.map(
      (Song s) => songItem(c.read, s, url: url, user: user, pass: pass),
    ),
  );
  await playAll(items, start < 0 ? 0 : start);
}
