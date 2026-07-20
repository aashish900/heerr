import 'package:freezed_annotation/freezed_annotation.dart';

import 'podcast_episode.dart';

part 'episode_list_response.freezed.dart';
part 'episode_list_response.g.dart';

/// GET /api/v1/podcasts/channels/{id}/episodes response body.
/// Backend contract: `backend/app/schemas/podcast.py::EpisodeListResponse`.
/// [total] is the channel's full episode count (independent of [limit]/
/// [offset]) — PC3 uses it to decide whether pagination has more pages.
@freezed
class EpisodeListResponse with _$EpisodeListResponse {
  const factory EpisodeListResponse({
    required List<PodcastEpisode> episodes,
    required int total,
  }) = _EpisodeListResponse;

  factory EpisodeListResponse.fromJson(Map<String, dynamic> json) =>
      _$EpisodeListResponseFromJson(json);
}
