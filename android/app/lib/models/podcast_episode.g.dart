// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_episode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PodcastEpisodeImpl _$$PodcastEpisodeImplFromJson(Map<String, dynamic> json) =>
    _$PodcastEpisodeImpl(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      guid: json['guid'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
      durationS: (json['duration_s'] as num?)?.toInt(),
      enclosureUrl: json['enclosure_url'] as String,
      enclosureType: json['enclosure_type'] as String?,
      imageUrl: json['image_url'] as String?,
      episodeNo: (json['episode_no'] as num?)?.toInt(),
      seasonNo: (json['season_no'] as num?)?.toInt(),
      downloaded: json['downloaded'] as bool,
      positionS: (json['position_s'] as num).toInt(),
      played: json['played'] as bool,
    );

Map<String, dynamic> _$$PodcastEpisodeImplToJson(
  _$PodcastEpisodeImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'channel_id': instance.channelId,
  'guid': instance.guid,
  'title': instance.title,
  if (instance.description case final value?) 'description': value,
  if (instance.publishedAt?.toIso8601String() case final value?)
    'published_at': value,
  if (instance.durationS case final value?) 'duration_s': value,
  'enclosure_url': instance.enclosureUrl,
  if (instance.enclosureType case final value?) 'enclosure_type': value,
  if (instance.imageUrl case final value?) 'image_url': value,
  if (instance.episodeNo case final value?) 'episode_no': value,
  if (instance.seasonNo case final value?) 'season_no': value,
  'downloaded': instance.downloaded,
  'position_s': instance.positionS,
  'played': instance.played,
};
