// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jam.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

JamSession _$JamSessionFromJson(Map<String, dynamic> json) {
  return _JamSession.fromJson(json);
}

/// @nodoc
mixin _$JamSession {
  String get id => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;

  /// Serializes this JamSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JamSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JamSessionCopyWith<JamSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JamSessionCopyWith<$Res> {
  factory $JamSessionCopyWith(
    JamSession value,
    $Res Function(JamSession) then,
  ) = _$JamSessionCopyWithImpl<$Res, JamSession>;
  @useResult
  $Res call({String id, String code, DateTime expiresAt});
}

/// @nodoc
class _$JamSessionCopyWithImpl<$Res, $Val extends JamSession>
    implements $JamSessionCopyWith<$Res> {
  _$JamSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JamSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            code: null == code
                ? _value.code
                : code // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$JamSessionImplCopyWith<$Res>
    implements $JamSessionCopyWith<$Res> {
  factory _$$JamSessionImplCopyWith(
    _$JamSessionImpl value,
    $Res Function(_$JamSessionImpl) then,
  ) = __$$JamSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String code, DateTime expiresAt});
}

/// @nodoc
class __$$JamSessionImplCopyWithImpl<$Res>
    extends _$JamSessionCopyWithImpl<$Res, _$JamSessionImpl>
    implements _$$JamSessionImplCopyWith<$Res> {
  __$$JamSessionImplCopyWithImpl(
    _$JamSessionImpl _value,
    $Res Function(_$JamSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of JamSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _$JamSessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        code: null == code
            ? _value.code
            : code // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$JamSessionImpl implements _JamSession {
  const _$JamSessionImpl({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  factory _$JamSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$JamSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String code;
  @override
  final DateTime expiresAt;

  @override
  String toString() {
    return 'JamSession(id: $id, code: $code, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JamSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, code, expiresAt);

  /// Create a copy of JamSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JamSessionImplCopyWith<_$JamSessionImpl> get copyWith =>
      __$$JamSessionImplCopyWithImpl<_$JamSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JamSessionImplToJson(this);
  }
}

abstract class _JamSession implements JamSession {
  const factory _JamSession({
    required final String id,
    required final String code,
    required final DateTime expiresAt,
  }) = _$JamSessionImpl;

  factory _JamSession.fromJson(Map<String, dynamic> json) =
      _$JamSessionImpl.fromJson;

  @override
  String get id;
  @override
  String get code;
  @override
  DateTime get expiresAt;

  /// Create a copy of JamSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JamSessionImplCopyWith<_$JamSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

JamJoin _$JamJoinFromJson(Map<String, dynamic> json) {
  return _JamJoin.fromJson(json);
}

/// @nodoc
mixin _$JamJoin {
  String get id => throw _privateConstructorUsedError;
  String get hostUsername => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;

  /// Serializes this JamJoin to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JamJoin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JamJoinCopyWith<JamJoin> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JamJoinCopyWith<$Res> {
  factory $JamJoinCopyWith(JamJoin value, $Res Function(JamJoin) then) =
      _$JamJoinCopyWithImpl<$Res, JamJoin>;
  @useResult
  $Res call({String id, String hostUsername, DateTime expiresAt});
}

/// @nodoc
class _$JamJoinCopyWithImpl<$Res, $Val extends JamJoin>
    implements $JamJoinCopyWith<$Res> {
  _$JamJoinCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JamJoin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? hostUsername = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            hostUsername: null == hostUsername
                ? _value.hostUsername
                : hostUsername // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$JamJoinImplCopyWith<$Res> implements $JamJoinCopyWith<$Res> {
  factory _$$JamJoinImplCopyWith(
    _$JamJoinImpl value,
    $Res Function(_$JamJoinImpl) then,
  ) = __$$JamJoinImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String hostUsername, DateTime expiresAt});
}

/// @nodoc
class __$$JamJoinImplCopyWithImpl<$Res>
    extends _$JamJoinCopyWithImpl<$Res, _$JamJoinImpl>
    implements _$$JamJoinImplCopyWith<$Res> {
  __$$JamJoinImplCopyWithImpl(
    _$JamJoinImpl _value,
    $Res Function(_$JamJoinImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of JamJoin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? hostUsername = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _$JamJoinImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        hostUsername: null == hostUsername
            ? _value.hostUsername
            : hostUsername // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$JamJoinImpl implements _JamJoin {
  const _$JamJoinImpl({
    required this.id,
    required this.hostUsername,
    required this.expiresAt,
  });

  factory _$JamJoinImpl.fromJson(Map<String, dynamic> json) =>
      _$$JamJoinImplFromJson(json);

  @override
  final String id;
  @override
  final String hostUsername;
  @override
  final DateTime expiresAt;

  @override
  String toString() {
    return 'JamJoin(id: $id, hostUsername: $hostUsername, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JamJoinImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.hostUsername, hostUsername) ||
                other.hostUsername == hostUsername) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, hostUsername, expiresAt);

  /// Create a copy of JamJoin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JamJoinImplCopyWith<_$JamJoinImpl> get copyWith =>
      __$$JamJoinImplCopyWithImpl<_$JamJoinImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JamJoinImplToJson(this);
  }
}

abstract class _JamJoin implements JamJoin {
  const factory _JamJoin({
    required final String id,
    required final String hostUsername,
    required final DateTime expiresAt,
  }) = _$JamJoinImpl;

  factory _JamJoin.fromJson(Map<String, dynamic> json) = _$JamJoinImpl.fromJson;

  @override
  String get id;
  @override
  String get hostUsername;
  @override
  DateTime get expiresAt;

  /// Create a copy of JamJoin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JamJoinImplCopyWith<_$JamJoinImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

JamCommand _$JamCommandFromJson(Map<String, dynamic> json) {
  return _JamCommand.fromJson(json);
}

/// @nodoc
mixin _$JamCommand {
  int get id => throw _privateConstructorUsedError;
  String get kind => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;
  String get sender => throw _privateConstructorUsedError;

  /// Serializes this JamCommand to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JamCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JamCommandCopyWith<JamCommand> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JamCommandCopyWith<$Res> {
  factory $JamCommandCopyWith(
    JamCommand value,
    $Res Function(JamCommand) then,
  ) = _$JamCommandCopyWithImpl<$Res, JamCommand>;
  @useResult
  $Res call({int id, String kind, Map<String, dynamic> payload, String sender});
}

/// @nodoc
class _$JamCommandCopyWithImpl<$Res, $Val extends JamCommand>
    implements $JamCommandCopyWith<$Res> {
  _$JamCommandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JamCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? payload = null,
    Object? sender = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as String,
            payload: null == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            sender: null == sender
                ? _value.sender
                : sender // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$JamCommandImplCopyWith<$Res>
    implements $JamCommandCopyWith<$Res> {
  factory _$$JamCommandImplCopyWith(
    _$JamCommandImpl value,
    $Res Function(_$JamCommandImpl) then,
  ) = __$$JamCommandImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int id, String kind, Map<String, dynamic> payload, String sender});
}

/// @nodoc
class __$$JamCommandImplCopyWithImpl<$Res>
    extends _$JamCommandCopyWithImpl<$Res, _$JamCommandImpl>
    implements _$$JamCommandImplCopyWith<$Res> {
  __$$JamCommandImplCopyWithImpl(
    _$JamCommandImpl _value,
    $Res Function(_$JamCommandImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of JamCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? payload = null,
    Object? sender = null,
  }) {
    return _then(
      _$JamCommandImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String,
        payload: null == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        sender: null == sender
            ? _value.sender
            : sender // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$JamCommandImpl implements _JamCommand {
  const _$JamCommandImpl({
    required this.id,
    required this.kind,
    final Map<String, dynamic> payload = const <String, dynamic>{},
    this.sender = '',
  }) : _payload = payload;

  factory _$JamCommandImpl.fromJson(Map<String, dynamic> json) =>
      _$$JamCommandImplFromJson(json);

  @override
  final int id;
  @override
  final String kind;
  final Map<String, dynamic> _payload;
  @override
  @JsonKey()
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  @JsonKey()
  final String sender;

  @override
  String toString() {
    return 'JamCommand(id: $id, kind: $kind, payload: $payload, sender: $sender)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JamCommandImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.sender, sender) || other.sender == sender));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    kind,
    const DeepCollectionEquality().hash(_payload),
    sender,
  );

  /// Create a copy of JamCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JamCommandImplCopyWith<_$JamCommandImpl> get copyWith =>
      __$$JamCommandImplCopyWithImpl<_$JamCommandImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JamCommandImplToJson(this);
  }
}

abstract class _JamCommand implements JamCommand {
  const factory _JamCommand({
    required final int id,
    required final String kind,
    final Map<String, dynamic> payload,
    final String sender,
  }) = _$JamCommandImpl;

  factory _JamCommand.fromJson(Map<String, dynamic> json) =
      _$JamCommandImpl.fromJson;

  @override
  int get id;
  @override
  String get kind;
  @override
  Map<String, dynamic> get payload;
  @override
  String get sender;

  /// Create a copy of JamCommand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JamCommandImplCopyWith<_$JamCommandImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

JamSyncResponse _$JamSyncResponseFromJson(Map<String, dynamic> json) {
  return _JamSyncResponse.fromJson(json);
}

/// @nodoc
mixin _$JamSyncResponse {
  List<JamCommand> get commands => throw _privateConstructorUsedError;
  int get cursor => throw _privateConstructorUsedError;
  bool get ended => throw _privateConstructorUsedError;

  /// Serializes this JamSyncResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JamSyncResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JamSyncResponseCopyWith<JamSyncResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JamSyncResponseCopyWith<$Res> {
  factory $JamSyncResponseCopyWith(
    JamSyncResponse value,
    $Res Function(JamSyncResponse) then,
  ) = _$JamSyncResponseCopyWithImpl<$Res, JamSyncResponse>;
  @useResult
  $Res call({List<JamCommand> commands, int cursor, bool ended});
}

/// @nodoc
class _$JamSyncResponseCopyWithImpl<$Res, $Val extends JamSyncResponse>
    implements $JamSyncResponseCopyWith<$Res> {
  _$JamSyncResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JamSyncResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? commands = null,
    Object? cursor = null,
    Object? ended = null,
  }) {
    return _then(
      _value.copyWith(
            commands: null == commands
                ? _value.commands
                : commands // ignore: cast_nullable_to_non_nullable
                      as List<JamCommand>,
            cursor: null == cursor
                ? _value.cursor
                : cursor // ignore: cast_nullable_to_non_nullable
                      as int,
            ended: null == ended
                ? _value.ended
                : ended // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$JamSyncResponseImplCopyWith<$Res>
    implements $JamSyncResponseCopyWith<$Res> {
  factory _$$JamSyncResponseImplCopyWith(
    _$JamSyncResponseImpl value,
    $Res Function(_$JamSyncResponseImpl) then,
  ) = __$$JamSyncResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<JamCommand> commands, int cursor, bool ended});
}

/// @nodoc
class __$$JamSyncResponseImplCopyWithImpl<$Res>
    extends _$JamSyncResponseCopyWithImpl<$Res, _$JamSyncResponseImpl>
    implements _$$JamSyncResponseImplCopyWith<$Res> {
  __$$JamSyncResponseImplCopyWithImpl(
    _$JamSyncResponseImpl _value,
    $Res Function(_$JamSyncResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of JamSyncResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? commands = null,
    Object? cursor = null,
    Object? ended = null,
  }) {
    return _then(
      _$JamSyncResponseImpl(
        commands: null == commands
            ? _value._commands
            : commands // ignore: cast_nullable_to_non_nullable
                  as List<JamCommand>,
        cursor: null == cursor
            ? _value.cursor
            : cursor // ignore: cast_nullable_to_non_nullable
                  as int,
        ended: null == ended
            ? _value.ended
            : ended // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$JamSyncResponseImpl implements _JamSyncResponse {
  const _$JamSyncResponseImpl({
    final List<JamCommand> commands = const <JamCommand>[],
    required this.cursor,
    required this.ended,
  }) : _commands = commands;

  factory _$JamSyncResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$JamSyncResponseImplFromJson(json);

  final List<JamCommand> _commands;
  @override
  @JsonKey()
  List<JamCommand> get commands {
    if (_commands is EqualUnmodifiableListView) return _commands;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_commands);
  }

  @override
  final int cursor;
  @override
  final bool ended;

  @override
  String toString() {
    return 'JamSyncResponse(commands: $commands, cursor: $cursor, ended: $ended)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JamSyncResponseImpl &&
            const DeepCollectionEquality().equals(other._commands, _commands) &&
            (identical(other.cursor, cursor) || other.cursor == cursor) &&
            (identical(other.ended, ended) || other.ended == ended));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_commands),
    cursor,
    ended,
  );

  /// Create a copy of JamSyncResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JamSyncResponseImplCopyWith<_$JamSyncResponseImpl> get copyWith =>
      __$$JamSyncResponseImplCopyWithImpl<_$JamSyncResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$JamSyncResponseImplToJson(this);
  }
}

abstract class _JamSyncResponse implements JamSyncResponse {
  const factory _JamSyncResponse({
    final List<JamCommand> commands,
    required final int cursor,
    required final bool ended,
  }) = _$JamSyncResponseImpl;

  factory _JamSyncResponse.fromJson(Map<String, dynamic> json) =
      _$JamSyncResponseImpl.fromJson;

  @override
  List<JamCommand> get commands;
  @override
  int get cursor;
  @override
  bool get ended;

  /// Create a copy of JamSyncResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JamSyncResponseImplCopyWith<_$JamSyncResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

JamState _$JamStateFromJson(Map<String, dynamic> json) {
  return _JamState.fromJson(json);
}

/// @nodoc
mixin _$JamState {
  Map<String, dynamic>? get state => throw _privateConstructorUsedError;
  DateTime? get stateAt => throw _privateConstructorUsedError;
  String get hostUsername => throw _privateConstructorUsedError;
  bool get ended => throw _privateConstructorUsedError;

  /// Serializes this JamState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JamState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JamStateCopyWith<JamState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JamStateCopyWith<$Res> {
  factory $JamStateCopyWith(JamState value, $Res Function(JamState) then) =
      _$JamStateCopyWithImpl<$Res, JamState>;
  @useResult
  $Res call({
    Map<String, dynamic>? state,
    DateTime? stateAt,
    String hostUsername,
    bool ended,
  });
}

/// @nodoc
class _$JamStateCopyWithImpl<$Res, $Val extends JamState>
    implements $JamStateCopyWith<$Res> {
  _$JamStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JamState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = freezed,
    Object? stateAt = freezed,
    Object? hostUsername = null,
    Object? ended = null,
  }) {
    return _then(
      _value.copyWith(
            state: freezed == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            stateAt: freezed == stateAt
                ? _value.stateAt
                : stateAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            hostUsername: null == hostUsername
                ? _value.hostUsername
                : hostUsername // ignore: cast_nullable_to_non_nullable
                      as String,
            ended: null == ended
                ? _value.ended
                : ended // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$JamStateImplCopyWith<$Res>
    implements $JamStateCopyWith<$Res> {
  factory _$$JamStateImplCopyWith(
    _$JamStateImpl value,
    $Res Function(_$JamStateImpl) then,
  ) = __$$JamStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Map<String, dynamic>? state,
    DateTime? stateAt,
    String hostUsername,
    bool ended,
  });
}

/// @nodoc
class __$$JamStateImplCopyWithImpl<$Res>
    extends _$JamStateCopyWithImpl<$Res, _$JamStateImpl>
    implements _$$JamStateImplCopyWith<$Res> {
  __$$JamStateImplCopyWithImpl(
    _$JamStateImpl _value,
    $Res Function(_$JamStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of JamState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = freezed,
    Object? stateAt = freezed,
    Object? hostUsername = null,
    Object? ended = null,
  }) {
    return _then(
      _$JamStateImpl(
        state: freezed == state
            ? _value._state
            : state // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        stateAt: freezed == stateAt
            ? _value.stateAt
            : stateAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        hostUsername: null == hostUsername
            ? _value.hostUsername
            : hostUsername // ignore: cast_nullable_to_non_nullable
                  as String,
        ended: null == ended
            ? _value.ended
            : ended // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$JamStateImpl implements _JamState {
  const _$JamStateImpl({
    final Map<String, dynamic>? state,
    this.stateAt,
    required this.hostUsername,
    required this.ended,
  }) : _state = state;

  factory _$JamStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$JamStateImplFromJson(json);

  final Map<String, dynamic>? _state;
  @override
  Map<String, dynamic>? get state {
    final value = _state;
    if (value == null) return null;
    if (_state is EqualUnmodifiableMapView) return _state;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime? stateAt;
  @override
  final String hostUsername;
  @override
  final bool ended;

  @override
  String toString() {
    return 'JamState(state: $state, stateAt: $stateAt, hostUsername: $hostUsername, ended: $ended)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JamStateImpl &&
            const DeepCollectionEquality().equals(other._state, _state) &&
            (identical(other.stateAt, stateAt) || other.stateAt == stateAt) &&
            (identical(other.hostUsername, hostUsername) ||
                other.hostUsername == hostUsername) &&
            (identical(other.ended, ended) || other.ended == ended));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_state),
    stateAt,
    hostUsername,
    ended,
  );

  /// Create a copy of JamState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JamStateImplCopyWith<_$JamStateImpl> get copyWith =>
      __$$JamStateImplCopyWithImpl<_$JamStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JamStateImplToJson(this);
  }
}

abstract class _JamState implements JamState {
  const factory _JamState({
    final Map<String, dynamic>? state,
    final DateTime? stateAt,
    required final String hostUsername,
    required final bool ended,
  }) = _$JamStateImpl;

  factory _JamState.fromJson(Map<String, dynamic> json) =
      _$JamStateImpl.fromJson;

  @override
  Map<String, dynamic>? get state;
  @override
  DateTime? get stateAt;
  @override
  String get hostUsername;
  @override
  bool get ended;

  /// Create a copy of JamState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JamStateImplCopyWith<_$JamStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
