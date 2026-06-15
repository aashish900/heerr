// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LyricsImpl _$$LyricsImplFromJson(Map<String, dynamic> json) => _$LyricsImpl(
  artist: json['artist'] as String?,
  title: json['title'] as String?,
  value: json['value'] as String?,
);

Map<String, dynamic> _$$LyricsImplToJson(_$LyricsImpl instance) =>
    <String, dynamic>{
      if (instance.artist case final value?) 'artist': value,
      if (instance.title case final value?) 'title': value,
      if (instance.value case final value?) 'value': value,
    };
