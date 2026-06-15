import 'package:freezed_annotation/freezed_annotation.dart';

import 'subsonic/song.dart';

part 'seed_track.freezed.dart';
part 'seed_track.g.dart';

/// One recommendation seed sent to the backend's `POST /api/v1/recommend`.
///
/// Fields mirror the backend's `RecommendSeed` schema:
/// - [title] — track title (or album name when a seed is sourced from
///   `getAlbumList2.view?type=frequent`).
/// - [artist] — track artist (or album artist).
/// - [sourceUrl] — optional `music.youtube.com/watch?v=…` URL. When the
///   seed already has a YouTube videoId attached (rare on the Android side
///   today), engines like ytmusic can skip the search-resolve step. Null in
///   v1 — populated by future features only.
@freezed
class SeedTrack with _$SeedTrack {
  const factory SeedTrack({
    required String title,
    required String artist,
    @JsonKey(name: 'source_url') String? sourceUrl,
  }) = _SeedTrack;

  factory SeedTrack.fromJson(Map<String, dynamic> json) =>
      _$SeedTrackFromJson(json);
}

/// Build a [SeedTrack] for the "Find similar →" long-press affordance on
/// a song row. Returns null if the [Song] lacks an artist — the backend's
/// `RecommendSeed` requires both title and artist.
SeedTrack? seedForSong(Song song) {
  final String? artist = song.artist;
  if (artist == null || artist.isEmpty) return null;
  return SeedTrack(title: song.title, artist: artist);
}
