// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchRequestImpl _$$SearchRequestImplFromJson(Map<String, dynamic> json) =>
    _$SearchRequestImpl(
      query: json['query'] as String,
      type: $enumDecode(_$ContentTypeEnumMap, json['type']),
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );

Map<String, dynamic> _$$SearchRequestImplToJson(_$SearchRequestImpl instance) =>
    <String, dynamic>{
      'query': instance.query,
      'type': _$ContentTypeEnumMap[instance.type]!,
      'limit': instance.limit,
    };

const _$ContentTypeEnumMap = {
  ContentType.song: 'song',
  ContentType.album: 'album',
  ContentType.playlist: 'playlist',
  ContentType.episode: 'episode',
};
