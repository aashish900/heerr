import 'package:audio_service/audio_service.dart';

import '../api/subsonic_client.dart';
import '../models/subsonic/song.dart';

/// Convert a Subsonic [Song] into an `audio_service` [MediaItem] suitable
/// for [HeerrAudioHandler]'s queue.
///
/// `id` is the **stream URL** — that's what `just_audio.AudioPlayer` opens
/// when this item becomes the current track. Auth params live in the URL
/// because the player fetches raw bytes outside the dio interceptor (same
/// constraint as cover art — see `buildSubsonicCoverArtUrl`).
///
/// Pure function so it's testable without standing up `just_audio` or
/// `audio_service`'s platform channels. All Navidrome creds must be
/// non-empty — the caller is responsible for surfacing a friendlier error
/// when they aren't (the temporary debug FAB on Library does this).
///
/// [saltGenerator] is injectable for deterministic unit tests; production
/// callers pass nothing.
MediaItem songToMediaItem({
  required Song song,
  required String navidromeBaseUrl,
  required String navidromeUsername,
  required String navidromePassword,
  String Function()? saltGenerator,
}) {
  final String streamUrl = buildSubsonicStreamUrl(
    baseUrl: navidromeBaseUrl,
    username: navidromeUsername,
    password: navidromePassword,
    songId: song.id,
    saltGenerator: saltGenerator,
  );

  Uri? artUri;
  final String? coverArt = song.coverArt;
  if (coverArt != null && coverArt.isNotEmpty) {
    artUri = Uri.parse(
      buildSubsonicCoverArtUrl(
        baseUrl: navidromeBaseUrl,
        username: navidromeUsername,
        password: navidromePassword,
        coverArtId: coverArt,
        saltGenerator: saltGenerator,
      ),
    );
  }

  final int? duration = song.duration;
  return MediaItem(
    id: streamUrl,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: duration == null ? null : Duration(seconds: duration),
    artUri: artUri,
    // Stash the source Song id so callers can map an active MediaItem back
    // to its Subsonic identity (J2 uses this for the now-playing screen +
    // reactive promotion).
    extras: <String, dynamic>{'subsonicId': song.id},
  );
}
