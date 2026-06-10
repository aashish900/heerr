// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DownloadRequestImpl _$$DownloadRequestImplFromJson(
  Map<String, dynamic> json,
) => _$DownloadRequestImpl(
  sourceUrl: json['source_url'] as String,
  sourceType: json['source_type'] as String,
  displayName: json['display_name'] as String?,
);

Map<String, dynamic> _$$DownloadRequestImplToJson(
  _$DownloadRequestImpl instance,
) => <String, dynamic>{
  'source_url': instance.sourceUrl,
  'source_type': instance.sourceType,
  if (instance.displayName case final value?) 'display_name': value,
};
