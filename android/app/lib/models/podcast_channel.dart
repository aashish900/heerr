import 'package:freezed_annotation/freezed_annotation.dart';

part 'podcast_channel.freezed.dart';
part 'podcast_channel.g.dart';

/// A podcast channel/show.
/// Backend contract: `backend/app/schemas/podcast.py::PodcastChannelItem`
/// (Podcast Index search results — [id] is null, not yet ingested) and
/// `::ChannelItem` (ingested/subscribed channels — [id] set). The backend
/// has no separate "subscription" entity: `GET /podcasts/subscriptions`
/// returns this same shape, so a subscribed channel is just a
/// [PodcastChannel] with a non-null [id].
@freezed
class PodcastChannel with _$PodcastChannel {
  const factory PodcastChannel({
    String? id,
    required String feedUrl,
    required String title,
    String? author,
    String? imageUrl,
    String? description,
  }) = _PodcastChannel;

  factory PodcastChannel.fromJson(Map<String, dynamic> json) =>
      _$PodcastChannelFromJson(json);
}
