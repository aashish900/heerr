// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_view.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$JobViewImpl _$$JobViewImplFromJson(Map<String, dynamic> json) =>
    _$JobViewImpl(
      jobId: json['job_id'] as String,
      sourceUrl: json['source_url'] as String,
      sourceType: $enumDecode(_$ContentTypeEnumMap, json['source_type']),
      state: $enumDecode(_$JobStateEnumMap, json['state']),
      displayName: json['display_name'] as String?,
      progress: (json['progress'] as num?)?.toInt(),
      error: json['error'] as String?,
      outputPath: json['output_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      finishedAt: json['finished_at'] == null
          ? null
          : DateTime.parse(json['finished_at'] as String),
    );

Map<String, dynamic> _$$JobViewImplToJson(_$JobViewImpl instance) =>
    <String, dynamic>{
      'job_id': instance.jobId,
      'source_url': instance.sourceUrl,
      'source_type': _$ContentTypeEnumMap[instance.sourceType]!,
      'state': _$JobStateEnumMap[instance.state]!,
      if (instance.displayName case final value?) 'display_name': value,
      if (instance.progress case final value?) 'progress': value,
      if (instance.error case final value?) 'error': value,
      if (instance.outputPath case final value?) 'output_path': value,
      'created_at': instance.createdAt.toIso8601String(),
      if (instance.startedAt?.toIso8601String() case final value?)
        'started_at': value,
      if (instance.finishedAt?.toIso8601String() case final value?)
        'finished_at': value,
    };

const _$ContentTypeEnumMap = {
  ContentType.song: 'song',
  ContentType.album: 'album',
  ContentType.playlist: 'playlist',
  ContentType.episode: 'episode',
};

const _$JobStateEnumMap = {
  JobState.queued: 'queued',
  JobState.running: 'running',
  JobState.done: 'done',
  JobState.failed: 'failed',
};
