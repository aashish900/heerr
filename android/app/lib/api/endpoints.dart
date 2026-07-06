/// Backend endpoint paths. Joined onto the user-supplied `backendBaseUrl`
/// (which already includes `/api/v1`), so paths here are bare.
class Endpoints {
  const Endpoints._();

  static const String health = '/health';
  static const String search = '/search';
  static const String download = '/download';
  static const String queue = '/queue';

  /// Phase K preview proxy: backend `GET /api/v1/preview/stream`. Resolves a
  /// YouTube Music watch URL to audio (yt-dlp) and proxies the bytes so a
  /// search result can be streamed before it is downloaded. just_audio can't
  /// attach auth headers to an `AudioSource`, so the bearer rides in `?token=`
  /// — see `player/preview_url.dart::buildPreviewStreamUrl`.
  static const String previewStream = '/preview/stream';

  /// Recommendation engine entry point. Backend Phase I (`backend/app/api/
  /// v1/recommend.py`). `POST` accepts `{seeds, limit}` and returns
  /// `{results: [RecommendedTrack]}`. `GET /recommend/health` (added at I4)
  /// reports the active engine + fallback state — N5 will surface it.
  static const String recommend = '/recommend';
  static const String recommendHealth = '/recommend/health';

  /// Phase S (multi-user): backend J6 — `POST /auth/login`. Accepts
  /// `{username, password}`, validates them against Navidrome via the
  /// backend's IdP shim, and returns `{token, scopes, navidromeUrl,
  /// navidromeUsername}` on success.
  static const String authLogin = '/auth/login';

  /// Phase W (#41): backend N1 — `DELETE /library/song`. Body
  /// `{path: <subsonic-relative-path>}` deletes the file from the music
  /// library on the server; Navidrome drops the track on its next scan.
  static const String libraryDeleteSong = '/library/song';

  /// Phase Y (#44): backend O2 — multipart `PATCH /library/song`. Form fields
  /// `path` (required) + optional `title`/`album`/`artist` + optional `cover`
  /// file rewrite the audio file's tags / embedded cover in place. Same path
  /// as [libraryDeleteSong]; the HTTP verb distinguishes them.
  static const String libraryEditSong = '/library/song';

  static String status(String jobId) => '/status/$jobId';
}
