// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SongImpl _$$SongImplFromJson(Map<String, dynamic> json) => _$SongImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String?,
  artistId: json['artistId'] as String?,
  album: json['album'] as String?,
  albumId: json['albumId'] as String?,
  coverArt: json['coverArt'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  track: (json['track'] as num?)?.toInt(),
  year: (json['year'] as num?)?.toInt(),
  genre: json['genre'] as String?,
  suffix: json['suffix'] as String?,
  contentType: json['contentType'] as String?,
  bitRate: (json['bitRate'] as num?)?.toInt(),
  path: json['path'] as String?,
  isVideo: json['isVideo'] as bool?,
  size: (json['size'] as num?)?.toInt(),
);

Map<String, dynamic> _$$SongImplToJson(_$SongImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      if (instance.artist case final value?) 'artist': value,
      if (instance.artistId case final value?) 'artistId': value,
      if (instance.album case final value?) 'album': value,
      if (instance.albumId case final value?) 'albumId': value,
      if (instance.coverArt case final value?) 'coverArt': value,
      if (instance.duration case final value?) 'duration': value,
      if (instance.track case final value?) 'track': value,
      if (instance.year case final value?) 'year': value,
      if (instance.genre case final value?) 'genre': value,
      if (instance.suffix case final value?) 'suffix': value,
      if (instance.contentType case final value?) 'contentType': value,
      if (instance.bitRate case final value?) 'bitRate': value,
      if (instance.path case final value?) 'path': value,
      if (instance.isVideo case final value?) 'isVideo': value,
      if (instance.size case final value?) 'size': value,
    };
