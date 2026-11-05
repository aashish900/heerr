import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_error.dart';
import '../models/subsonic/song.dart';
import '../providers/jam_remote.dart';
import '../providers/server_creds.dart';
import 'heerr_audio_handler.dart';
import 'player_provider.dart';
import 'song_to_media_item.dart';

part 'jam_display.g.dart';

/// JM: what Now Playing + the mini-player show. Normally the local player;
/// while this phone controls a jam host, the host's polled snapshot rebuilt
/// as a [PlayerSnapshot] so the same screens render it. A plain provider
/// (not a stream) so a 2s poll swaps the value without a loading flash.
@riverpod
AsyncValue<PlayerSnapshot> displaySnapshot(DisplaySnapshotRef ref) {
  final JamRemoteStatus? jam = ref.watch(jamRemoteProvider);
  if (jam == null) return ref.watch(playerSnapshotProvider);
  final ({MediaItem? current, List<MediaItem> queue, PlaybackState state}) h =
      _host(jam, ref.watch(serverCredsProvider));
  return AsyncData<PlayerSnapshot>(
    PlayerSnapshot(item: h.current, state: h.state),
  );
}

/// JM: the queue Now Playing's sheet lists (host's while joined, from its
/// current index onward).
@riverpod
AsyncValue<List<MediaItem>> displayQueue(DisplayQueueRef ref) {
  final JamRemoteStatus? jam = ref.watch(jamRemoteProvider);
  if (jam == null) return ref.watch(playerQueueProvider);
  return AsyncData<List<MediaItem>>(
    _host(jam, ref.watch(serverCredsProvider)).queue,
  );
}

({MediaItem? current, List<MediaItem> queue, PlaybackState state}) _host(
  JamRemoteStatus jam,
  ServerCreds creds,
) {
  final Map<String, dynamic> s =
      jam.hostState?.state ?? const <String, dynamic>{};
  MediaItem? item(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      // Art + stream URLs built with this phone's creds: same library.
      return songToMediaItem(
        song: Song.fromJson(json),
        navidromeBaseUrl: creds.navidromeBaseUrl ?? '',
        navidromeUsername: creds.navidromeUsername ?? '',
        navidromePassword: creds.navidromePassword ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  final dynamic pos = s['position_ms'];
  return (
    current: item(s['current']),
    queue: <MediaItem>[
      if (s['queue'] is List)
        for (final dynamic e in s['queue'] as List<dynamic>)
          if (item(e) case final MediaItem m) m,
    ],
    // updateTime defaults to now, so PlaybackState.position extrapolates
    // from when this snapshot arrived (host and guest clocks may differ).
    state: PlaybackState(
      playing: s['playing'] == true,
      processingState: AudioProcessingState.ready,
      updatePosition: Duration(milliseconds: pos is int ? pos : 0),
    ),
  );
}

/// JM: transport for UI buttons. Drives the jam host while joined (a 404
/// means the host ended the session: leave), else the local player.
Future<void> playerTransport(
  WidgetRef ref,
  String kind, {
  Duration? position,
}) async {
  final JamRemote jam = ref.read(jamRemoteProvider.notifier);
  if (ref.read(jamRemoteProvider) != null) {
    try {
      await jam.send(
        kind,
        kind == 'seek'
            ? <String, dynamic>{'position_ms': position!.inMilliseconds}
            : null,
      );
    } on NotFoundError {
      jam.leave();
    } on ApiError {
      // Tailnet blip: the banner + next poll show the real host state.
    }
    return;
  }
  final HeerrAudioHandler h = ref.read(audioHandlerProvider);
  switch (kind) {
    case 'play':
      await h.play();
    case 'pause':
      await h.pause();
    case 'next':
      await h.skipToNext();
    case 'prev':
      await h.skipToPrevious();
    case 'seek':
      await h.seek(position!);
  }
}
