import 'package:freezed_annotation/freezed_annotation.dart';

import 'episode_with_channel.dart';

part 'episode_feed_response.freezed.dart';
part 'episode_feed_response.g.dart';

/// `GET /api/v1/podcasts/episodes` response body (PA1, #53).
/// Backend contract: `backend/app/schemas/podcast.py::EpisodeFeedResponse`.
@freezed
class EpisodeFeedResponse with _$EpisodeFeedResponse {
  const factory EpisodeFeedResponse({
    required List<EpisodeWithChannel> episodes,
    required int total,
  }) = _EpisodeFeedResponse;

  factory EpisodeFeedResponse.fromJson(Map<String, dynamic> json) =>
      _$EpisodeFeedResponseFromJson(json);
}
