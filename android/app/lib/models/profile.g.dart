// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileImpl _$$ProfileImplFromJson(Map<String, dynamic> json) =>
    _$ProfileImpl(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      heerrBaseUrl: json['heerr_base_url'] as String,
      heerrBearerToken: json['heerr_bearer_token'] as String,
      navidromeBaseUrl: json['navidrome_base_url'] as String,
      navidromeUsername: json['navidrome_username'] as String,
      navidromePassword: json['navidrome_password'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
    );

Map<String, dynamic> _$$ProfileImplToJson(_$ProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'heerr_base_url': instance.heerrBaseUrl,
      'heerr_bearer_token': instance.heerrBearerToken,
      'navidrome_base_url': instance.navidromeBaseUrl,
      'navidrome_username': instance.navidromeUsername,
      'navidrome_password': instance.navidromePassword,
      'created_at': instance.createdAt.toIso8601String(),
      'last_used_at': instance.lastUsedAt.toIso8601String(),
    };
