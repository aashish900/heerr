// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recommend_health.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecommendHealth _$RecommendHealthFromJson(Map<String, dynamic> json) {
  return _RecommendHealth.fromJson(json);
}

/// @nodoc
mixin _$RecommendHealth {
  String get engine => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'fallback_active')
  bool get fallbackActive => throw _privateConstructorUsedError;

  /// Serializes this RecommendHealth to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecommendHealth
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecommendHealthCopyWith<RecommendHealth> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendHealthCopyWith<$Res> {
  factory $RecommendHealthCopyWith(
    RecommendHealth value,
    $Res Function(RecommendHealth) then,
  ) = _$RecommendHealthCopyWithImpl<$Res, RecommendHealth>;
  @useResult
  $Res call({
    String engine,
    String status,
    @JsonKey(name: 'fallback_active') bool fallbackActive,
  });
}

/// @nodoc
class _$RecommendHealthCopyWithImpl<$Res, $Val extends RecommendHealth>
    implements $RecommendHealthCopyWith<$Res> {
  _$RecommendHealthCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecommendHealth
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? engine = null,
    Object? status = null,
    Object? fallbackActive = null,
  }) {
    return _then(
      _value.copyWith(
            engine: null == engine
                ? _value.engine
                : engine // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            fallbackActive: null == fallbackActive
                ? _value.fallbackActive
                : fallbackActive // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecommendHealthImplCopyWith<$Res>
    implements $RecommendHealthCopyWith<$Res> {
  factory _$$RecommendHealthImplCopyWith(
    _$RecommendHealthImpl value,
    $Res Function(_$RecommendHealthImpl) then,
  ) = __$$RecommendHealthImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String engine,
    String status,
    @JsonKey(name: 'fallback_active') bool fallbackActive,
  });
}

/// @nodoc
class __$$RecommendHealthImplCopyWithImpl<$Res>
    extends _$RecommendHealthCopyWithImpl<$Res, _$RecommendHealthImpl>
    implements _$$RecommendHealthImplCopyWith<$Res> {
  __$$RecommendHealthImplCopyWithImpl(
    _$RecommendHealthImpl _value,
    $Res Function(_$RecommendHealthImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecommendHealth
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? engine = null,
    Object? status = null,
    Object? fallbackActive = null,
  }) {
    return _then(
      _$RecommendHealthImpl(
        engine: null == engine
            ? _value.engine
            : engine // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        fallbackActive: null == fallbackActive
            ? _value.fallbackActive
            : fallbackActive // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecommendHealthImpl implements _RecommendHealth {
  const _$RecommendHealthImpl({
    required this.engine,
    required this.status,
    @JsonKey(name: 'fallback_active') required this.fallbackActive,
  });

  factory _$RecommendHealthImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendHealthImplFromJson(json);

  @override
  final String engine;
  @override
  final String status;
  @override
  @JsonKey(name: 'fallback_active')
  final bool fallbackActive;

  @override
  String toString() {
    return 'RecommendHealth(engine: $engine, status: $status, fallbackActive: $fallbackActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendHealthImpl &&
            (identical(other.engine, engine) || other.engine == engine) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.fallbackActive, fallbackActive) ||
                other.fallbackActive == fallbackActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, engine, status, fallbackActive);

  /// Create a copy of RecommendHealth
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendHealthImplCopyWith<_$RecommendHealthImpl> get copyWith =>
      __$$RecommendHealthImplCopyWithImpl<_$RecommendHealthImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendHealthImplToJson(this);
  }
}

abstract class _RecommendHealth implements RecommendHealth {
  const factory _RecommendHealth({
    required final String engine,
    required final String status,
    @JsonKey(name: 'fallback_active') required final bool fallbackActive,
  }) = _$RecommendHealthImpl;

  factory _RecommendHealth.fromJson(Map<String, dynamic> json) =
      _$RecommendHealthImpl.fromJson;

  @override
  String get engine;
  @override
  String get status;
  @override
  @JsonKey(name: 'fallback_active')
  bool get fallbackActive;

  /// Create a copy of RecommendHealth
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecommendHealthImplCopyWith<_$RecommendHealthImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
