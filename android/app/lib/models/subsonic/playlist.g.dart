// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlaylistImpl _$$PlaylistImplFromJson(Map<String, dynamic> json) =>
    _$PlaylistImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      owner: json['owner'] as String?,
      public: json['public'] as bool?,
      songCount: (json['songCount'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      created: json['created'] as String?,
      changed: json['changed'] as String?,
      coverArt: json['coverArt'] as String?,
      entry:
          (json['entry'] as List<dynamic>?)
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Song>[],
    );

Map<String, dynamic> _$$PlaylistImplToJson(_$PlaylistImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.comment case final value?) 'comment': value,
      if (instance.owner case final value?) 'owner': value,
      if (instance.public case final value?) 'public': value,
      if (instance.songCount case final value?) 'songCount': value,
      if (instance.duration case final value?) 'duration': value,
      if (instance.created case final value?) 'created': value,
      if (instance.changed case final value?) 'changed': value,
      if (instance.coverArt case final value?) 'coverArt': value,
      'entry': instance.entry.map((e) => e.toJson()).toList(),
    };
