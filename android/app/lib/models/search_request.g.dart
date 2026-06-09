// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchRequestImpl _$$SearchRequestImplFromJson(Map<String, dynamic> json) =>
    _$SearchRequestImpl(
      query: json['query'] as String,
      type: $enumDecode(_$SpotifyTypeEnumMap, json['type']),
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );

Map<String, dynamic> _$$SearchRequestImplToJson(_$SearchRequestImpl instance) =>
    <String, dynamic>{
      'query': instance.query,
      'type': _$SpotifyTypeEnumMap[instance.type]!,
      'limit': instance.limit,
    };

const _$SpotifyTypeEnumMap = {
  SpotifyType.track: 'track',
  SpotifyType.album: 'album',
  SpotifyType.playlist: 'playlist',
};
