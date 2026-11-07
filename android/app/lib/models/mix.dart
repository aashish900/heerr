import 'package:freezed_annotation/freezed_annotation.dart';

import 'recommended_track.dart';

part 'mix.freezed.dart';
part 'mix.g.dart';

/// One vibe offered by `GET /api/v1/recommend/mixes` (Phase MX): e.g.
/// `{id: "chill", title: "Chill Mix"}`. The list is static server-side.
@freezed
class MixVibe with _$MixVibe {
  const factory MixVibe({
    required String id,
    required String title,
  }) = _MixVibe;

  factory MixVibe.fromJson(Map<String, dynamic> json) =>
      _$MixVibeFromJson(json);
}

/// `POST /api/v1/recommend/mixes/{id}` response. [personalized] is false when
/// none of the mood's playlists matched the user's artists (the mix is then
/// YouTube Music's own top picks for the mood). [results] are songs the
/// client may still own — `MixNotifier` drops those after hydration.
@freezed
class MixResponse with _$MixResponse {
  const factory MixResponse({
    required String id,
    required String title,
    required bool personalized,
    @Default(<RecommendedTrack>[]) List<RecommendedTrack> results,
  }) = _MixResponse;

  factory MixResponse.fromJson(Map<String, dynamic> json) =>
      _$MixResponseFromJson(json);
}
