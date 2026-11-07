// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SeedTrackImpl _$$SeedTrackImplFromJson(Map<String, dynamic> json) =>
    _$SeedTrackImpl(
      title: json['title'] as String?,
      artist: json['artist'] as String,
      sourceUrl: json['source_url'] as String?,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$$SeedTrackImplToJson(_$SeedTrackImpl instance) =>
    <String, dynamic>{
      if (instance.title case final value?) 'title': value,
      'artist': instance.artist,
      if (instance.sourceUrl case final value?) 'source_url': value,
      'weight': instance.weight,
    };
