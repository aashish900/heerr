/// Backend endpoint paths. Joined onto the user-supplied `backendBaseUrl`
/// (which already includes `/api/v1`), so paths here are bare.
class Endpoints {
  const Endpoints._();

  static const String health = '/health';
  static const String search = '/search';
  static const String download = '/download';
  static const String queue = '/queue';

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

  static String status(String jobId) => '/status/$jobId';
}
