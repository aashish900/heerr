// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommended_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecommendedTrackImpl _$$RecommendedTrackImplFromJson(
  Map<String, dynamic> json,
) => _$RecommendedTrackImpl(
  title: json['title'] as String,
  artist: json['artist'] as String,
  sourceUrl: json['source_url'] as String,
  score: (json['score'] as num?)?.toDouble(),
  inLibrary: json['in_library'] as bool? ?? false,
  subsonicSongId: json['subsonic_song_id'] as String?,
);

Map<String, dynamic> _$$RecommendedTrackImplToJson(
  _$RecommendedTrackImpl instance,
) => <String, dynamic>{
  'title': instance.title,
  'artist': instance.artist,
  'source_url': instance.sourceUrl,
  if (instance.score case final value?) 'score': value,
  'in_library': instance.inLibrary,
  if (instance.subsonicSongId case final value?) 'subsonic_song_id': value,
};
