// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QueueResponseImpl _$$QueueResponseImplFromJson(Map<String, dynamic> json) =>
    _$QueueResponseImpl(
      active: (json['active'] as List<dynamic>)
          .map((e) => JobView.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent: (json['recent'] as List<dynamic>)
          .map((e) => JobView.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$QueueResponseImplToJson(_$QueueResponseImpl instance) =>
    <String, dynamic>{
      'active': instance.active.map((e) => e.toJson()).toList(),
      'recent': instance.recent.map((e) => e.toJson()).toList(),
    };
