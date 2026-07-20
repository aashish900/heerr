// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_feed_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EpisodeFeedResponseImpl _$$EpisodeFeedResponseImplFromJson(
  Map<String, dynamic> json,
) => _$EpisodeFeedResponseImpl(
  episodes: (json['episodes'] as List<dynamic>)
      .map((e) => EpisodeWithChannel.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$$EpisodeFeedResponseImplToJson(
  _$EpisodeFeedResponseImpl instance,
) => <String, dynamic>{
  'episodes': instance.episodes.map((e) => e.toJson()).toList(),
  'total': instance.total,
};
