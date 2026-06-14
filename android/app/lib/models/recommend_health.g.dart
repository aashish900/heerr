// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommend_health.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecommendHealthImpl _$$RecommendHealthImplFromJson(
  Map<String, dynamic> json,
) => _$RecommendHealthImpl(
  engine: json['engine'] as String,
  status: json['status'] as String,
  fallbackActive: json['fallback_active'] as bool,
);

Map<String, dynamic> _$$RecommendHealthImplToJson(
  _$RecommendHealthImpl instance,
) => <String, dynamic>{
  'engine': instance.engine,
  'status': instance.status,
  'fallback_active': instance.fallbackActive,
};
