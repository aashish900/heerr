import 'package:freezed_annotation/freezed_annotation.dart';

part 'episode_progress.freezed.dart';
part 'episode_progress.g.dart';

/// PUT /api/v1/podcasts/episodes/{id}/progress response body.
/// Backend contract: `backend/app/schemas/podcast.py::EpisodeProgressResponse`.
@freezed
class EpisodeProgress with _$EpisodeProgress {
  const factory EpisodeProgress({
    required String episodeId,
    required int positionS,
    required bool played,
  }) = _EpisodeProgress;

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) =>
      _$EpisodeProgressFromJson(json);
}
