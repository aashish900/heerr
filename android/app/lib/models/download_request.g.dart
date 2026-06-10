// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DownloadRequestImpl _$$DownloadRequestImplFromJson(
  Map<String, dynamic> json,
) => _$DownloadRequestImpl(
  spotifyUri: json['spotify_uri'] as String,
  displayName: json['display_name'] as String?,
);

Map<String, dynamic> _$$DownloadRequestImplToJson(
  _$DownloadRequestImpl instance,
) => <String, dynamic>{
  'spotify_uri': instance.spotifyUri,
  if (instance.displayName case final value?) 'display_name': value,
};
