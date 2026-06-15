// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'now_playing_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NowPlayingSnapshotImpl _$$NowPlayingSnapshotImplFromJson(
  Map<String, dynamic> json,
) => _$NowPlayingSnapshotImpl(
  songs:
      (json['songs'] as List<dynamic>?)
          ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Song>[],
  currentIndex: (json['current_index'] as num?)?.toInt() ?? 0,
  positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$NowPlayingSnapshotImplToJson(
  _$NowPlayingSnapshotImpl instance,
) => <String, dynamic>{
  'songs': instance.songs.map((e) => e.toJson()).toList(),
  'current_index': instance.currentIndex,
  'position_ms': instance.positionMs,
  'updated_at': instance.updatedAt,
};
