import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../models/jam.dart';
import '../models/subsonic/song.dart';
import 'heerr_audio_handler.dart';
import 'song_to_media_item.dart';

/// Phase JM: apply one guest [cmd] to the host's [handler]. [toItem] turns a
/// guest-sent [Song] into a playable [MediaItem] with *this* phone's creds
/// (local file if downloaded, else stream URL) — see `play_core.songItem`.
/// Unknown kinds / malformed payloads are ignored: a guest on a newer app
/// version must never crash the host's loop.
Future<void> runJamCommand(
  JamCommand cmd,
  HeerrAudioHandler handler,
  Future<MediaItem> Function(Song song) toItem,
) async {
  switch (cmd.kind) {
    case 'play_songs':
      final List<MediaItem> items = await _items(cmd, toItem);
      if (items.isEmpty) return;
      final dynamic start = cmd.payload['start_index'];
      final int i = start is int && start >= 0 && start < items.length
          ? start
          : 0;
      await handler.playAll(items, startIndex: i);
    case 'enqueue':
      final List<MediaItem> items = await _items(cmd, toItem);
      if (items.isEmpty) return;
      // Same as addSongsToQueue: nothing to append behind -> play.
      if (handler.queue.value.isEmpty) {
        await handler.playAll(items);
      } else {
        await handler.addQueueItems(items);
      }
    case 'play':
      // Not awaited: just_audio's play() completes only on pause/stop/end,
      // which would stall the host sync loop for the whole track.
      unawaited(handler.play());
    case 'pause':
      await handler.pause();
    case 'next':
      await handler.skipToNext();
    case 'prev':
      await handler.skipToPrevious();
    case 'seek':
      final dynamic ms = cmd.payload['position_ms'];
      if (ms is int && ms >= 0) await handler.seek(Duration(milliseconds: ms));
  }
}

Future<List<MediaItem>> _items(
  JamCommand cmd,
  Future<MediaItem> Function(Song song) toItem,
) {
  final dynamic raw = cmd.payload['songs'];
  if (raw is! List) return Future<List<MediaItem>>.value(<MediaItem>[]);
  final List<Song> songs = <Song>[
    for (final dynamic s in raw)
      if (s is Map<String, dynamic>) Song.fromJson(s),
  ];
  return Future.wait<MediaItem>(songs.map(toItem));
}

/// Max queue entries the host publishes from the current index onward.
const int kJamStateQueueCap = 50;

/// The host snapshot written by `POST /jam/{id}/sync` (`/PLAN.md` §5.3).
/// Songs are [Song] JSON rebuilt from the queue via [songFromMediaItem];
/// items with no Subsonic id (previews, podcast episodes) publish as null
/// `current` / are skipped in `queue`.
Map<String, dynamic> jamHostState({
  required MediaItem? current,
  required PlaybackState playback,
  required List<MediaItem> queue,
  required int nowMs,
}) {
  final int index = playback.queueIndex ?? 0;
  final int from = index.clamp(0, queue.length);
  return <String, dynamic>{
    'playing': playback.playing,
    'position_ms': playback.position.inMilliseconds,
    'updated_at_ms': nowMs,
    'current': current == null ? null : songFromMediaItem(current)?.toJson(),
    'queue': <Map<String, dynamic>>[
      for (final MediaItem m in queue.skip(from).take(kJamStateQueueCap))
        if (songFromMediaItem(m) case final Song s) s.toJson(),
    ],
    'queue_index': index,
  };
}
