import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/subsonic/song.dart';

part 'now_playing_snapshot.freezed.dart';
part 'now_playing_snapshot.g.dart';

/// Persisted "what was playing when the app last closed" snapshot.
///
/// Written to `<appDocs>/now_playing.json` by [NowPlayingPersistence] and
/// read back on cold start to restore the queue + position into
/// [HeerrAudioHandler] *without* auto-playing — the user taps to resume.
///
/// Schema is intentionally small:
///  - [songs] — the queue as a list of [Song]s. Round-tripped via
///    `songToMediaItem` / `songFromMediaItem`. We persist Songs rather
///    than `MediaItem`s because the stream URL in `MediaItem.id` carries
///    a rotating-salt auth signature that goes stale across processes.
///  - [currentIndex] — clamped to the queue range on restore.
///  - [positionMs] — player position in milliseconds at last save.
///  - [updatedAt] — epoch ms; useful for staleness checks / debugging.
@freezed
class NowPlayingSnapshot with _$NowPlayingSnapshot {
  const factory NowPlayingSnapshot({
    @Default(<Song>[]) List<Song> songs,
    @Default(0) int currentIndex,
    @Default(0) int positionMs,
    @Default(0) int updatedAt,
  }) = _NowPlayingSnapshot;

  factory NowPlayingSnapshot.fromJson(Map<String, dynamic> json) =>
      _$NowPlayingSnapshotFromJson(json);
}
