import 'package:audio_service/audio_service.dart';

import '../models/search_result_item.dart';
import 'preview_url.dart';

/// Convert a not-in-library online-search [SearchResultItem] into an
/// `audio_service` [MediaItem] that streams through the backend preview proxy
/// (Phase K / Phase T).
///
/// This is the **third** `MediaItem.id` flavour alongside the two in
/// [songToMediaItem] (Subsonic stream URL, `file://` local path): here `id` is
/// the heerr `/preview/stream` URL built by [buildPreviewStreamUrl], so
/// `just_audio` opens the proxy and the backend streams the googlevideo bytes.
///
/// The item is flagged `extras['preview'] == true` so the Now Playing / mini
/// player can show a "Preview" badge, and the original `sourceUrl` rides along
/// so the same row can be dispatched to `/download` and later promoted to real
/// Subsonic playback once Navidrome re-indexes (combined-search promotion).
///
/// Pure function — testable without `just_audio` / `audio_service` platform
/// channels, same as [songToMediaItem].
MediaItem searchResultToMediaItem({
  required SearchResultItem item,
  required String heerrBaseUrl,
  required String token,
}) {
  final String mediaId = buildPreviewStreamUrl(
    heerrBaseUrl: heerrBaseUrl,
    sourceUrl: item.sourceUrl,
    token: token,
  );

  Uri? artUri;
  final String? cover = item.coverUrl;
  if (cover != null && cover.isNotEmpty) {
    artUri = Uri.tryParse(cover);
  }
  // Mirror songToMediaItem's launcher fallback so the notification always has
  // an icon when the remote thumbnail is absent or unparseable.
  artUri ??= Uri.parse('android.resource://com.aashish.heerr/mipmap/ic_launcher');

  final int? durationMs = item.durationMs;
  return MediaItem(
    id: mediaId,
    title: item.title,
    artist: item.artist,
    album: item.album,
    duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    artUri: artUri,
    extras: <String, dynamic>{
      'preview': true,
      'sourceUrl': item.sourceUrl,
    },
  );
}
