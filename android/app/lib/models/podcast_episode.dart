import 'package:freezed_annotation/freezed_annotation.dart';

part 'podcast_episode.freezed.dart';
part 'podcast_episode.g.dart';

/// One episode of a [PodcastChannel].
/// Backend contract: `backend/app/schemas/podcast.py::EpisodeItem`.
/// [downloaded] mirrors the server's `downloaded_path is not None` check;
/// [positionS]/[played] are the calling user's resume state, `0`/`false`
/// when no [EpisodeProgress] row exists yet.
@freezed
class PodcastEpisode with _$PodcastEpisode {
  const factory PodcastEpisode({
    required String id,
    required String channelId,
    required String guid,
    required String title,
    String? description,
    DateTime? publishedAt,
    int? durationS,
    required String enclosureUrl,
    String? enclosureType,
    String? imageUrl,
    int? episodeNo,
    int? seasonNo,
    required bool downloaded,
    required int positionS,
    required bool played,
  }) = _PodcastEpisode;

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) =>
      _$PodcastEpisodeFromJson(json);
}
