// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileMetaImpl _$$ProfileMetaImplFromJson(Map<String, dynamic> json) =>
    _$ProfileMetaImpl(
      nickname: json['nickname'] as String?,
      bio: json['bio'] as String?,
    );

Map<String, dynamic> _$$ProfileMetaImplToJson(_$ProfileMetaImpl instance) =>
    <String, dynamic>{
      if (instance.nickname case final value?) 'nickname': value,
      if (instance.bio case final value?) 'bio': value,
    };
