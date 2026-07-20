import '../api/endpoints.dart';

/// Builds the absolute URL for a downloaded episode's Range-capable audio
/// stream (backend Phase P — `GET /api/v1/podcasts/episodes/{id}/audio`).
///
/// Same rationale as `preview_url.dart::buildPreviewStreamUrl`: just_audio
/// cannot attach an `Authorization` header to an `AudioSource`, so the
/// bearer token rides in the `token` query param. Only call this for a
/// [PodcastEpisode] with `downloaded == true` — the backend 404s otherwise
/// (undownloaded episodes stream from `PodcastEpisode.enclosureUrl`
/// directly; see `backend/docs/PODCASTS.md` 2.5).
String buildPodcastAudioUrl({
  required String heerrBaseUrl,
  required String episodeId,
  required String token,
}) {
  final String base = heerrBaseUrl.endsWith('/')
      ? heerrBaseUrl.substring(0, heerrBaseUrl.length - 1)
      : heerrBaseUrl;
  final String query = Uri(queryParameters: <String, String>{'token': token}).query;
  return '$base${Endpoints.podcastEpisodeAudio(episodeId)}?$query';
}
