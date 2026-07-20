import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/podcast_episode.dart';
import '../models/profile.dart';
import '../providers/profiles/active_profile.dart';
import '../widgets/error_snackbar.dart';
import 'episode_to_media_item.dart';
import 'heerr_audio_handler.dart';
import 'player_provider.dart';

/// PC5 (#53): play a podcast [episode], replacing the queue with just this
/// episode (same "replace, don't append" shape as `playSongFromSubsonic` /
/// `playPreview`). Resumes from `episode.positionS` when non-zero — the
/// "resume-from-position on open" half of PC5; the throttled `PUT` half
/// lives in `episode_progress_provider.dart`, wired session-wide rather
/// than per-call.
Future<void> playEpisode(
  WidgetRef ref,
  BuildContext context,
  PodcastEpisode episode,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final Profile? profile = ref.read(activeProfileProvider);
    if (profile == null ||
        profile.heerrBaseUrl.isEmpty ||
        profile.heerrBearerToken.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        duration: kSnackBarDuration,
        content: Text('Not signed in — sign in under Settings.'),
      ));
      return;
    }
    final MediaItem mediaItem = episodeToMediaItem(
      episode: episode,
      heerrBaseUrl: profile.heerrBaseUrl,
      token: profile.heerrBearerToken,
    );
    final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
    await handler.playSong(mediaItem);
    if (episode.positionS > 0) {
      await handler.player.seek(Duration(seconds: episode.positionS));
    }
    messenger.showSnackBar(SnackBar(
      duration: kSnackBarDuration,
      content: Text('Playing: ${episode.title}'),
    ));
  } catch (e) {
    final String msg = e is ApiError ? e.message : 'Play failed: $e';
    messenger.showSnackBar(SnackBar(duration: kSnackBarDuration, content: Text(msg)));
  }
}
