import 'package:freezed_annotation/freezed_annotation.dart';

import 'subsonic/song.dart';

part 'seed_track.freezed.dart';
part 'seed_track.g.dart';

/// One recommendation seed sent to the backend's `POST /api/v1/recommend`.
///
/// Fields mirror the backend's `RecommendSeed` schema:
/// - [title] — track title. **Null means an artist seed** ("more like this
///   artist"), built from frequently / recently played albums (RX8). Omitted
///   from the JSON when null (`include_if_null: false` in `build.yaml`).
/// - [artist] — track or album artist. Always required.
/// - [sourceUrl] — optional `music.youtube.com/watch?v=…` URL. When the
///   seed already has a source videoId attached (rare on the Android side
///   today), some engines can skip the search-resolve step. Null in
///   v1 — populated by future features only.
/// - [weight] — 0..1 strength of the seed (starred song 1.0, frequent-album
///   artist 0.7, recent-album artist 0.4). The backend sums weights across
///   seeds that agree on a track.
@freezed
class SeedTrack with _$SeedTrack {
  const factory SeedTrack({
    String? title,
    required String artist,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @Default(1.0) double weight,
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
