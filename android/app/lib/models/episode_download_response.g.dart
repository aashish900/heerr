// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_download_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EpisodeDownloadResponseImpl _$$EpisodeDownloadResponseImplFromJson(
  Map<String, dynamic> json,
) => _$EpisodeDownloadResponseImpl(
  jobId: json['job_id'] as String,
  state: $enumDecode(_$JobStateEnumMap, json['state']),
  deduped: json['deduped'] as bool,
);

Map<String, dynamic> _$$EpisodeDownloadResponseImplToJson(
  _$EpisodeDownloadResponseImpl instance,
) => <String, dynamic>{
  'job_id': instance.jobId,
  'state': _$JobStateEnumMap[instance.state]!,
  'deduped': instance.deduped,
};

const _$JobStateEnumMap = {
  JobState.queued: 'queued',
  JobState.running: 'running',
  JobState.done: 'done',
  JobState.failed: 'failed',
};
