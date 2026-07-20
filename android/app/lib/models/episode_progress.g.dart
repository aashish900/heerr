// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EpisodeProgressImpl _$$EpisodeProgressImplFromJson(
  Map<String, dynamic> json,
) => _$EpisodeProgressImpl(
  episodeId: json['episode_id'] as String,
  positionS: (json['position_s'] as num).toInt(),
  played: json['played'] as bool,
);

Map<String, dynamic> _$$EpisodeProgressImplToJson(
  _$EpisodeProgressImpl instance,
) => <String, dynamic>{
  'episode_id': instance.episodeId,
  'position_s': instance.positionS,
  'played': instance.played,
};
