import 'package:freezed_annotation/freezed_annotation.dart';

import 'podcast_episode.dart';

part 'episode_with_channel.freezed.dart';
part 'episode_with_channel.g.dart';

/// PA1/PR3 (#53): one episode from the cross-subscription feed
/// (`GET /podcasts/episodes`), carrying its show's title/art inline so a
/// mixed-show list (Home Continue Listening/Latest Episodes, Library
/// Episodes/Downloads) can render a row without a second call per show.
/// Backend contract: `backend/app/schemas/podcast.py::EpisodeWithChannelItem`.
@freezed
class EpisodeWithChannel with _$EpisodeWithChannel {
  const factory EpisodeWithChannel({
    required String id,
    required String channelId,
    required String channelTitle,
    String? channelImageUrl,
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
  }) = _EpisodeWithChannel;

  factory EpisodeWithChannel.fromJson(Map<String, dynamic> json) =>
      _$EpisodeWithChannelFromJson(json);
}

/// PR3 (#53): playback (`playEpisode`) and the episode-download dispatcher
/// operate on [PodcastEpisode] — this adapts a cross-show feed row to that
/// shape rather than duplicating either code path for [EpisodeWithChannel].
extension EpisodeWithChannelPlayback on EpisodeWithChannel {
  PodcastEpisode toPodcastEpisode() => PodcastEpisode(
        id: id,
        channelId: channelId,
        guid: guid,
        title: title,
        description: description,
        publishedAt: publishedAt,
        durationS: durationS,
        enclosureUrl: enclosureUrl,
        enclosureType: enclosureType,
        imageUrl: imageUrl,
        episodeNo: episodeNo,
        seasonNo: seasonNo,
        downloaded: downloaded,
        positionS: positionS,
        played: played,
      );
}
