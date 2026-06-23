import '../api/endpoints.dart';

/// Builds the absolute URL for the backend preview-stream proxy
/// (backend Phase K — `GET /api/v1/preview/stream`).
///
/// just_audio cannot attach an `Authorization` header to an `AudioSource`, so
/// the bearer token rides in the `token` query param — the same shape Subsonic
/// stream URLs already use. The backend accepts it there and keeps it out of
/// logs. [heerrBaseUrl] already includes the `/api/v1` prefix (same value the
/// heerr dio uses as its base), so only the bare [Endpoints.previewStream] path
/// is appended.
///
/// Both [sourceUrl] (a `music.youtube.com/watch?v=<id>` URL) and [token] are
/// percent-encoded via [Uri], so the result is safe to hand straight to
/// `AudioSource.uri(Uri.parse(...))`.
String buildPreviewStreamUrl({
  required String heerrBaseUrl,
  required String sourceUrl,
  required String token,
}) {
  final String base = heerrBaseUrl.endsWith('/')
      ? heerrBaseUrl.substring(0, heerrBaseUrl.length - 1)
      : heerrBaseUrl;
  final String query = Uri(
    queryParameters: <String, String>{
      'source_url': sourceUrl,
      'token': token,
    },
  ).query;
  return '$base${Endpoints.previewStream}?$query';
}
