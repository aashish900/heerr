// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'queue_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

QueueResponse _$QueueResponseFromJson(Map<String, dynamic> json) {
  return _QueueResponse.fromJson(json);
}

/// @nodoc
mixin _$QueueResponse {
  List<JobView> get active => throw _privateConstructorUsedError;
  List<JobView> get recent => throw _privateConstructorUsedError;

  /// Serializes this QueueResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QueueResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QueueResponseCopyWith<QueueResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QueueResponseCopyWith<$Res> {
  factory $QueueResponseCopyWith(
    QueueResponse value,
    $Res Function(QueueResponse) then,
  ) = _$QueueResponseCopyWithImpl<$Res, QueueResponse>;
  @useResult
  $Res call({List<JobView> active, List<JobView> recent});
}

/// @nodoc
class _$QueueResponseCopyWithImpl<$Res, $Val extends QueueResponse>
    implements $QueueResponseCopyWith<$Res> {
  _$QueueResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QueueResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? active = null, Object? recent = null}) {
    return _then(
      _value.copyWith(
            active: null == active
                ? _value.active
                : active // ignore: cast_nullable_to_non_nullable
                      as List<JobView>,
            recent: null == recent
                ? _value.recent
                : recent // ignore: cast_nullable_to_non_nullable
                      as List<JobView>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QueueResponseImplCopyWith<$Res>
    implements $QueueResponseCopyWith<$Res> {
  factory _$$QueueResponseImplCopyWith(
    _$QueueResponseImpl value,
    $Res Function(_$QueueResponseImpl) then,
  ) = __$$QueueResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<JobView> active, List<JobView> recent});
}

/// @nodoc
class __$$QueueResponseImplCopyWithImpl<$Res>
    extends _$QueueResponseCopyWithImpl<$Res, _$QueueResponseImpl>
    implements _$$QueueResponseImplCopyWith<$Res> {
  __$$QueueResponseImplCopyWithImpl(
    _$QueueResponseImpl _value,
    $Res Function(_$QueueResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QueueResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? active = null, Object? recent = null}) {
    return _then(
      _$QueueResponseImpl(
        active: null == active
            ? _value._active
            : active // ignore: cast_nullable_to_non_nullable
                  as List<JobView>,
        recent: null == recent
            ? _value._recent
            : recent // ignore: cast_nullable_to_non_nullable
                  as List<JobView>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$QueueResponseImpl implements _QueueResponse {
  const _$QueueResponseImpl({
    required final List<JobView> active,
    required final List<JobView> recent,
  }) : _active = active,
       _recent = recent;

  factory _$QueueResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$QueueResponseImplFromJson(json);

  final List<JobView> _active;
  @override
  List<JobView> get active {
    if (_active is EqualUnmodifiableListView) return _active;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_active);
  }

  final List<JobView> _recent;
  @override
  List<JobView> get recent {
    if (_recent is EqualUnmodifiableListView) return _recent;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recent);
  }

  @override
  String toString() {
    return 'QueueResponse(active: $active, recent: $recent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QueueResponseImpl &&
            const DeepCollectionEquality().equals(other._active, _active) &&
            const DeepCollectionEquality().equals(other._recent, _recent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_active),
    const DeepCollectionEquality().hash(_recent),
  );

  /// Create a copy of QueueResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QueueResponseImplCopyWith<_$QueueResponseImpl> get copyWith =>
      __$$QueueResponseImplCopyWithImpl<_$QueueResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QueueResponseImplToJson(this);
  }
}

abstract class _QueueResponse implements QueueResponse {
  const factory _QueueResponse({
    required final List<JobView> active,
    required final List<JobView> recent,
  }) = _$QueueResponseImpl;

  factory _QueueResponse.fromJson(Map<String, dynamic> json) =
      _$QueueResponseImpl.fromJson;

  @override
  List<JobView> get active;
  @override
  List<JobView> get recent;

  /// Create a copy of QueueResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QueueResponseImplCopyWith<_$QueueResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
