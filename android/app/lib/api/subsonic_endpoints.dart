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
}
