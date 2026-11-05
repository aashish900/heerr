// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jam.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$JamSessionImpl _$$JamSessionImplFromJson(Map<String, dynamic> json) =>
    _$JamSessionImpl(
      id: json['id'] as String,
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$$JamSessionImplToJson(_$JamSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'expires_at': instance.expiresAt.toIso8601String(),
    };

_$JamJoinImpl _$$JamJoinImplFromJson(Map<String, dynamic> json) =>
    _$JamJoinImpl(
      id: json['id'] as String,
      hostUsername: json['host_username'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$$JamJoinImplToJson(_$JamJoinImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'host_username': instance.hostUsername,
      'expires_at': instance.expiresAt.toIso8601String(),
    };

_$JamCommandImpl _$$JamCommandImplFromJson(Map<String, dynamic> json) =>
    _$JamCommandImpl(
      id: (json['id'] as num).toInt(),
      kind: json['kind'] as String,
      payload:
          json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      sender: json['sender'] as String? ?? '',
    );

Map<String, dynamic> _$$JamCommandImplToJson(_$JamCommandImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'payload': instance.payload,
      'sender': instance.sender,
    };

_$JamSyncResponseImpl _$$JamSyncResponseImplFromJson(
  Map<String, dynamic> json,
) => _$JamSyncResponseImpl(
  commands:
      (json['commands'] as List<dynamic>?)
          ?.map((e) => JamCommand.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <JamCommand>[],
  cursor: (json['cursor'] as num).toInt(),
  ended: json['ended'] as bool,
);

Map<String, dynamic> _$$JamSyncResponseImplToJson(
  _$JamSyncResponseImpl instance,
) => <String, dynamic>{
  'commands': instance.commands.map((e) => e.toJson()).toList(),
  'cursor': instance.cursor,
  'ended': instance.ended,
};

_$JamStateImpl _$$JamStateImplFromJson(Map<String, dynamic> json) =>
    _$JamStateImpl(
      state: json['state'] as Map<String, dynamic>?,
      stateAt: json['state_at'] == null
          ? null
          : DateTime.parse(json['state_at'] as String),
      hostUsername: json['host_username'] as String,
      ended: json['ended'] as bool,
    );

Map<String, dynamic> _$$JamStateImplToJson(
  _$JamStateImpl instance,
) => <String, dynamic>{
  if (instance.state case final value?) 'state': value,
  if (instance.stateAt?.toIso8601String() case final value?) 'state_at': value,
  'host_username': instance.hostUsername,
  'ended': instance.ended,
};
