import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subsonic/album.dart';
import '../models/subsonic/artist.dart';
import '../models/subsonic/song.dart';
import '../offline/local_uri.dart';
import '../providers/library/library_album.dart';
import 'song_to_media_item.dart';

/// `WidgetRef.read` and `ProviderContainer.read` both fit this, so the same
/// play logic serves the UI and the Android Auto (no-UI) path.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Subsonic [Song] -> queue [MediaItem]: `file://` when downloaded, else the
/// stream URL. Single chokepoint for the local-vs-stream decision.
///
/// Awaits `localUriForProvider.future` so the manifest has fully rebuilt after
/// a recent sync (see `local_uri.dart`) — otherwise a fresh download is
/// invisible to the player.
Future<MediaItem> songItem(
  ProviderReader read,
  Song s, {
  required String url,
  required String user,
  required String pass,
}) async {
  final String? localUri = await read(localUriForProvider(s.id).future);
  String? localPath;
  if (localUri != null) {
    final Uri parsed = Uri.parse(localUri);
    if (parsed.scheme == 'file') localPath = parsed.toFilePath();
  }
  return songToMediaItem(
    song: s,
    navidromeBaseUrl: url,
    navidromeUsername: user,
    navidromePassword: pass,
    localFilePath: localPath,
  );
}

/// Every song of [artist], in the artist's album order (Subsonic returns
/// most-recent first; kept as-is). Albums resolve in parallel — serial would
/// multiply the latency by the album count.
Future<List<Song>> songsForArtist(ProviderReader read, Artist artist) async {
  final List<Album> resolved = await Future.wait<Album>(
    artist.album.map((Album a) => read(libraryAlbumProvider(a.id).future)),
  );
  return <Song>[for (final Album a in resolved) ...a.song];
}
