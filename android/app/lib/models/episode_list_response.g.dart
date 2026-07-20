// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EpisodeListResponseImpl _$$EpisodeListResponseImplFromJson(
  Map<String, dynamic> json,
) => _$EpisodeListResponseImpl(
  episodes: (json['episodes'] as List<dynamic>)
      .map((e) => PodcastEpisode.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$$EpisodeListResponseImplToJson(
  _$EpisodeListResponseImpl instance,
) => <String, dynamic>{
  'episodes': instance.episodes.map((e) => e.toJson()).toList(),
  'total': instance.total,
};
