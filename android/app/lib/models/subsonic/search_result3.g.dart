// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result3.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchResult3Impl _$$SearchResult3ImplFromJson(Map<String, dynamic> json) =>
    _$SearchResult3Impl(
      artist:
          (json['artist'] as List<dynamic>?)
              ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Artist>[],
      album:
          (json['album'] as List<dynamic>?)
              ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Album>[],
      song:
          (json['song'] as List<dynamic>?)
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Song>[],
    );

Map<String, dynamic> _$$SearchResult3ImplToJson(_$SearchResult3Impl instance) =>
    <String, dynamic>{
      'artist': instance.artist.map((e) => e.toJson()).toList(),
      'album': instance.album.map((e) => e.toJson()).toList(),
      'song': instance.song.map((e) => e.toJson()).toList(),
    };
