// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_meta.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProfileMeta _$ProfileMetaFromJson(Map<String, dynamic> json) {
  return _ProfileMeta.fromJson(json);
}

/// @nodoc
mixin _$ProfileMeta {
  String? get nickname => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;

  /// Serializes this ProfileMeta to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProfileMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileMetaCopyWith<ProfileMeta> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileMetaCopyWith<$Res> {
  factory $ProfileMetaCopyWith(
    ProfileMeta value,
    $Res Function(ProfileMeta) then,
  ) = _$ProfileMetaCopyWithImpl<$Res, ProfileMeta>;
  @useResult
  $Res call({String? nickname, String? bio});
}

/// @nodoc
class _$ProfileMetaCopyWithImpl<$Res, $Val extends ProfileMeta>
    implements $ProfileMetaCopyWith<$Res> {
  _$ProfileMetaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfileMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? nickname = freezed, Object? bio = freezed}) {
    return _then(
      _value.copyWith(
            nickname: freezed == nickname
                ? _value.nickname
                : nickname // ignore: cast_nullable_to_non_nullable
                      as String?,
            bio: freezed == bio
                ? _value.bio
                : bio // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileMetaImplCopyWith<$Res>
    implements $ProfileMetaCopyWith<$Res> {
  factory _$$ProfileMetaImplCopyWith(
    _$ProfileMetaImpl value,
    $Res Function(_$ProfileMetaImpl) then,
  ) = __$$ProfileMetaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? nickname, String? bio});
}

/// @nodoc
class __$$ProfileMetaImplCopyWithImpl<$Res>
    extends _$ProfileMetaCopyWithImpl<$Res, _$ProfileMetaImpl>
    implements _$$ProfileMetaImplCopyWith<$Res> {
  __$$ProfileMetaImplCopyWithImpl(
    _$ProfileMetaImpl _value,
    $Res Function(_$ProfileMetaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfileMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? nickname = freezed, Object? bio = freezed}) {
    return _then(
      _$ProfileMetaImpl(
        nickname: freezed == nickname
            ? _value.nickname
            : nickname // ignore: cast_nullable_to_non_nullable
                  as String?,
        bio: freezed == bio
            ? _value.bio
            : bio // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProfileMetaImpl implements _ProfileMeta {
  const _$ProfileMetaImpl({this.nickname, this.bio});

  factory _$ProfileMetaImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileMetaImplFromJson(json);

  @override
  final String? nickname;
  @override
  final String? bio;

  @override
  String toString() {
    return 'ProfileMeta(nickname: $nickname, bio: $bio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileMetaImpl &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.bio, bio) || other.bio == bio));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, nickname, bio);

  /// Create a copy of ProfileMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileMetaImplCopyWith<_$ProfileMetaImpl> get copyWith =>
      __$$ProfileMetaImplCopyWithImpl<_$ProfileMetaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileMetaImplToJson(this);
  }
}

abstract class _ProfileMeta implements ProfileMeta {
  const factory _ProfileMeta({final String? nickname, final String? bio}) =
      _$ProfileMetaImpl;

  factory _ProfileMeta.fromJson(Map<String, dynamic> json) =
      _$ProfileMetaImpl.fromJson;

  @override
  String? get nickname;
  @override
  String? get bio;

  /// Create a copy of ProfileMeta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileMetaImplCopyWith<_$ProfileMetaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
