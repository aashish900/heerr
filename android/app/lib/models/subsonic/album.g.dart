// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AlbumImpl _$$AlbumImplFromJson(Map<String, dynamic> json) => _$AlbumImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  artist: json['artist'] as String?,
  artistId: json['artistId'] as String?,
  coverArt: json['coverArt'] as String?,
  songCount: (json['songCount'] as num?)?.toInt(),
  duration: (json['duration'] as num?)?.toInt(),
  year: (json['year'] as num?)?.toInt(),
  genre: json['genre'] as String?,
  created: json['created'] as String?,
  song:
      (json['song'] as List<dynamic>?)
          ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Song>[],
);

Map<String, dynamic> _$$AlbumImplToJson(_$AlbumImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.artist case final value?) 'artist': value,
      if (instance.artistId case final value?) 'artistId': value,
      if (instance.coverArt case final value?) 'coverArt': value,
      if (instance.songCount case final value?) 'songCount': value,
      if (instance.duration case final value?) 'duration': value,
      if (instance.year case final value?) 'year': value,
      if (instance.genre case final value?) 'genre': value,
      if (instance.created case final value?) 'created': value,
      'song': instance.song.map((e) => e.toJson()).toList(),
    };
