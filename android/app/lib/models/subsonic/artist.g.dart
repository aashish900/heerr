// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ArtistImpl _$$ArtistImplFromJson(Map<String, dynamic> json) => _$ArtistImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  coverArt: json['coverArt'] as String?,
  albumCount: (json['albumCount'] as num?)?.toInt(),
  artistImageUrl: json['artistImageUrl'] as String?,
  album:
      (json['album'] as List<dynamic>?)
          ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Album>[],
);

Map<String, dynamic> _$$ArtistImplToJson(_$ArtistImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.coverArt case final value?) 'coverArt': value,
      if (instance.albumCount case final value?) 'albumCount': value,
      if (instance.artistImageUrl case final value?) 'artistImageUrl': value,
      'album': instance.album.map((e) => e.toJson()).toList(),
    };
