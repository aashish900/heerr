import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'episode_download_response.freezed.dart';
part 'episode_download_response.g.dart';

/// POST /api/v1/podcasts/episodes/{id}/download response body.
/// Backend contract: `backend/app/schemas/podcast.py::EpisodeDownloadResponse`.
/// Same shape as [DownloadResponse] (song downloads) — the episode download
/// reuses the same `jobs` queue/state machine server-side.
@freezed
class EpisodeDownloadResponse with _$EpisodeDownloadResponse {
  const factory EpisodeDownloadResponse({
    required String jobId,
    required JobState state,
    required bool deduped,
  }) = _EpisodeDownloadResponse;

  factory EpisodeDownloadResponse.fromJson(Map<String, dynamic> json) =>
      _$EpisodeDownloadResponseFromJson(json);
}
