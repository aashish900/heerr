// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LyricsImpl _$$LyricsImplFromJson(Map<String, dynamic> json) => _$LyricsImpl(
  artist: json['artist'] as String?,
  title: json['title'] as String?,
  value: json['value'] as String?,
  lines: (json['lines'] as List<dynamic>?)
      ?.map((e) => LyricsLine.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$LyricsImplToJson(_$LyricsImpl instance) =>
    <String, dynamic>{
      if (instance.artist case final value?) 'artist': value,
      if (instance.title case final value?) 'title': value,
      if (instance.value case final value?) 'value': value,
      if (instance.lines?.map((e) => e.toJson()).toList() case final value?)
        'lines': value,
    };

_$LyricsLineImpl _$$LyricsLineImplFromJson(Map<String, dynamic> json) =>
    _$LyricsLineImpl(
      start: (json['start'] as num).toInt(),
      value: json['value'] as String,
    );

Map<String, dynamic> _$$LyricsLineImplToJson(_$LyricsLineImpl instance) =>
    <String, dynamic>{'start': instance.start, 'value': instance.value};
