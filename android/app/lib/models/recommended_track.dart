import 'package:freezed_annotation/freezed_annotation.dart';

part 'recommended_track.freezed.dart';
part 'recommended_track.g.dart';

/// One row of `POST /api/v1/recommend` response.
///
/// Mirrors the backend `RecommendResultItem` schema (snake-case wire
/// names mapped via `@JsonKey`). The shape is identical across every
/// configured engine — engine choice is invisible to the client by
/// design (see backend DECISIONLOG 2026-06-13).
///
/// `sourceUrl` is always a `music.youtube.com/watch?v=…` URL, even when
/// the upstream signal came from Last.fm or ListenBrainz: the backend's
/// source resolver resolves every candidate before the response ships.
/// Tapping Download therefore dispatches through the existing
/// `POST /download` flow with no special-casing.
///
/// `score` is engine-relative (Last.fm match weight, ListenBrainz CF
/// score, etc.). Null when the engine didn't surface one. Not displayed
/// in v1 — kept on the model so future UI can sort / badge by it.
///
/// `inLibrary` is hydrated client-side by [recommendationsProvider] at
/// N4 (Subsonic `search3` cross-reference). Defaults to `false`; the
/// recommendations screen renders **Play** instead of **Download** when
/// `true` and a "Find similar →" affordance lands in the same milestone.
@freezed
class RecommendedTrack with _$RecommendedTrack {
  const factory RecommendedTrack({
    required String title,
    required String artist,
    @JsonKey(name: 'source_url') required String sourceUrl,
    double? score,
    @Default(false) bool inLibrary,

    /// Navidrome song id when [inLibrary] is true. Set by the N4
    /// cross-reference step (parallel `search3.view` calls). Required for
    /// the "Play" branch — without it we can't drive Subsonic playback.
    /// Null on remote-only results (the Download path).
    String? subsonicSongId,

    /// Navidrome `coverArt` id when the row is library-matched (the N4
    /// cross-reference returns the full Song, which carries `coverArt`).
    /// Threaded through to the Home "Picked for you" card so it can render
    /// the cached library cover instead of a placeholder.
    /// Null for genuinely-online recommendations — those fall back to the
    /// remote video thumbnail derived from `sourceUrl`.
    String? coverArt,
  }) = _RecommendedTrack;

  factory RecommendedTrack.fromJson(Map<String, dynamic> json) =>
      _$RecommendedTrackFromJson(json);
}
