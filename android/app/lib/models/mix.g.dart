// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mix.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MixVibeImpl _$$MixVibeImplFromJson(Map<String, dynamic> json) =>
    _$MixVibeImpl(id: json['id'] as String, title: json['title'] as String);

Map<String, dynamic> _$$MixVibeImplToJson(_$MixVibeImpl instance) =>
    <String, dynamic>{'id': instance.id, 'title': instance.title};

_$MixResponseImpl _$$MixResponseImplFromJson(Map<String, dynamic> json) =>
    _$MixResponseImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      personalized: json['personalized'] as bool,
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => RecommendedTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RecommendedTrack>[],
    );

Map<String, dynamic> _$$MixResponseImplToJson(_$MixResponseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'personalized': instance.personalized,
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
