// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist_index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ArtistIndexImpl _$$ArtistIndexImplFromJson(Map<String, dynamic> json) =>
    _$ArtistIndexImpl(
      name: json['name'] as String,
      artist:
          (json['artist'] as List<dynamic>?)
              ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Artist>[],
    );

Map<String, dynamic> _$$ArtistIndexImplToJson(_$ArtistIndexImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'artist': instance.artist.map((e) => e.toJson()).toList(),
    };
