/// Subsonic API path constants. Joined onto the user-supplied
/// `navidromeBaseUrl` (e.g. `http://100.x.y.z:4533`). All methods
/// live under `/rest/<method>.view`; auth params (u/s/t/v/c/f) are injected
/// by `SubsonicAuthInterceptor`.
class SubsonicEndpoints {
  const SubsonicEndpoints._();

  /// Cheap "are credentials valid?" probe. Returns the standard envelope
  /// with `status: ok` / `status: failed`.
  static const String ping = '/rest/ping.view';

  /// Full indexed artist list (the "Artists" tab in any Subsonic client).
  static const String getArtists = '/rest/getArtists.view';

  /// Artist detail (albums for an artist). `id` query param required.
  static const String getArtist = '/rest/getArtist.view';

  /// Album detail (songs for an album). `id` query param required.
  static const String getAlbum = '/rest/getAlbum.view';

  /// Flat list of albums. Required `type` (e.g. `alphabeticalByName`,
  /// `newest`, `byYear`). Optional `size` (default 10, max 500), `offset`.
  /// Used by the Library tab's Albums sub-tab — the per-artist album list
  /// inside `getArtist` is unsuitable for an A-Z global view.
  static const String getAlbumList2 = '/rest/getAlbumList2.view';

  /// All playlists visible to the authenticated user.
  static const String getPlaylists = '/rest/getPlaylists.view';

  /// Playlist detail (entries). `id` query param required.
  static const String getPlaylist = '/rest/getPlaylist.view';

  /// Library search across artists, albums, and songs. `query` required;
  /// `artistCount` / `albumCount` / `songCount` optional limits.
  static const String search3 = '/rest/search3.view';

  /// Audio stream by song id. `id` required; range requests supported by
  /// Navidrome for seek (used at J1 by `just_audio`).
  static const String stream = '/rest/stream.view';

  /// Cover-art image bytes by id. `size` query param optional. Auth lives
  /// in URL query params so `Image.network(url)` works without headers.
  static const String getCoverArt = '/rest/getCoverArt.view';

  /// Create a new playlist. Required `name`; optional `songId` (repeatable
  /// multi-param to populate songs in order). Returns the new playlist in
  /// the `playlist` envelope key. M1 plumbing for the Playlists feature.
  static const String createPlaylist = '/rest/createPlaylist.view';

  /// Mutate an existing playlist. Required `playlistId`. Optional `name`,
  /// `comment`, `public` (bool), `songIdToAdd` (multi, append), and
  /// `songIndexToRemove` (multi, 0-based against the *current* order —
  /// callers must send indices descending so earlier removes don't shift
  /// later ones). Empty envelope on success.
  static const String updatePlaylist = '/rest/updatePlaylist.view';

  /// Delete a playlist by `id`. Empty envelope on success.
  static const String deletePlaylist = '/rest/deletePlaylist.view';

  /// Register playback with the server. Required `id` (Subsonic song id);
  /// `submission=false` is the "now playing" notification fired at track
  /// start; `submission=true` is the "I listened to it" submission fired at
  /// ≥ 50% of track duration. Navidrome forwards submissions to Last.fm /
  /// ListenBrainz when those integrations are configured on the server.
  /// See N1 in `android/docs/ROADMAP.md`.
  static const String scrobble = '/rest/scrobble.view';

  /// All starred songs, albums, and artists for the authenticated user.
  /// Used by the recommendation seed-collection (N2) — starred songs are
  /// the strongest signal of "music the user likes" available without
  /// scrobble history.
  static const String getStarred2 = '/rest/getStarred2.view';

  /// Random song selection. Optional `size` (default 10, max 500). Used by
  /// the Home screen (O2) as a fallback content source when the library is
  /// brand-new (no recently-played / most-played history) and as the
  /// "Discover" fallback for recommendations when the backend returns
  /// nothing.
  static const String getRandomSongs = '/rest/getRandomSongs.view';

  /// Open Subsonic structured-lyrics endpoint. Required `id` (Navidrome song
  /// id). Navidrome (≥ 0.52) resolves lyrics via LRCLib (external provider)
  /// + embedded file tags, so this succeeds for most popular tracks even
  /// when the audio file has no embedded LYRICS tag. Returns
  /// `lyricsList.structuredLyrics[].line[].value` which we join with `\n`
  /// to produce plain text. Code 70 or an empty `structuredLyrics` array →
  /// empty state, not a hard error. P2.
  static const String getLyricsBySongId = '/rest/getLyricsBySongId.view';
}
