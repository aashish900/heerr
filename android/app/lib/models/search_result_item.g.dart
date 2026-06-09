// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchResultItemImpl _$$SearchResultItemImplFromJson(
  Map<String, dynamic> json,
) => _$SearchResultItemImpl(
  spotifyUri: json['spotify_uri'] as String,
  spotifyUrl: json['spotify_url'] as String,
  title: json['title'] as String,
  artist: json['artist'] as String,
  album: json['album'] as String?,
  durationMs: (json['duration_ms'] as num?)?.toInt(),
  coverUrl: json['cover_url'] as String?,
  alreadyDownloaded: json['already_downloaded'] as bool,
  activeJobId: json['active_job_id'] as String?,
);

Map<String, dynamic> _$$SearchResultItemImplToJson(
  _$SearchResultItemImpl instance,
) => <String, dynamic>{
  'spotify_uri': instance.spotifyUri,
  'spotify_url': instance.spotifyUrl,
  'title': instance.title,
  'artist': instance.artist,
  if (instance.album case final value?) 'album': value,
  if (instance.durationMs case final value?) 'duration_ms': value,
  if (instance.coverUrl case final value?) 'cover_url': value,
  'already_downloaded': instance.alreadyDownloaded,
  if (instance.activeJobId case final value?) 'active_job_id': value,
};
