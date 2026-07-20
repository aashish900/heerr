import 'package:audio_service/audio_service.dart';

import '../models/podcast_episode.dart';
import 'podcast_audio_url.dart';

/// Convert a [PodcastEpisode] into an `audio_service` [MediaItem].
///
/// This is the **fourth** `MediaItem.id` flavour alongside the three in
/// `song_to_media_item.dart` / `search_result_to_media_item.dart` (Subsonic
/// stream URL, `file://` local path, preview-proxy URL). There is no
/// on-device "downloaded episode" file — `PodcastEpisode.downloaded` means
/// the backend has the bytes in `PODCAST_OUTPUT_DIR`, not the phone — so
/// `id` is always a remote URL, never `file://`:
///
/// 1. Downloaded on the backend: the Range-capable
///    `GET /podcasts/episodes/{id}/audio?token=` proxy (real seek/resume).
/// 2. Not yet downloaded: `episode.enclosureUrl` directly — already public,
///    never proxied (see `backend/docs/PODCASTS.md` §2.5).
///
/// Flagged `extras['episodeId']` (and `extras['channelId']`) so playback
/// code can distinguish episodes from library/preview items — see
/// [isEpisodeMediaItem] / [episodeIdFromMediaItem].
///
/// Pure function — testable without `just_audio` / `audio_service` platform
/// channels, same as [songToMediaItem] / [searchResultToMediaItem].
MediaItem episodeToMediaItem({
  required PodcastEpisode episode,
  required String heerrBaseUrl,
  required String token,
}) {
  final String mediaId = episode.downloaded
      ? buildPodcastAudioUrl(
          heerrBaseUrl: heerrBaseUrl,
          episodeId: episode.id,
          token: token,
        )
      : episode.enclosureUrl;

  Uri? artUri;
  final String? cover = episode.imageUrl;
  if (cover != null && cover.isNotEmpty) {
    artUri = Uri.tryParse(cover);
  }
  artUri ??= Uri.parse('android.resource://com.aashish.heerr/mipmap/ic_launcher');

  final int? durationS = episode.durationS;
  return MediaItem(
    id: mediaId,
    title: episode.title,
    duration: durationS == null ? null : Duration(seconds: durationS),
    artUri: artUri,
    extras: <String, dynamic>{
      'episodeId': episode.id,
      'channelId': episode.channelId,
    },
  );
}

/// True when [item] was built by [episodeToMediaItem].
bool isEpisodeMediaItem(MediaItem? item) => item?.extras?['episodeId'] != null;

/// The `PodcastEpisode.id` [item] was built from, or `null` when [item] is
/// not an episode item (see [isEpisodeMediaItem]).
String? episodeIdFromMediaItem(MediaItem? item) {
  final dynamic raw = item?.extras?['episodeId'];
  return raw is String && raw.isNotEmpty ? raw : null;
}
