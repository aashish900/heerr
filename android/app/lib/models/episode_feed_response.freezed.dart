// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode_feed_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EpisodeFeedResponse _$EpisodeFeedResponseFromJson(Map<String, dynamic> json) {
  return _EpisodeFeedResponse.fromJson(json);
}

/// @nodoc
mixin _$EpisodeFeedResponse {
  List<EpisodeWithChannel> get episodes => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  /// Serializes this EpisodeFeedResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EpisodeFeedResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EpisodeFeedResponseCopyWith<EpisodeFeedResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EpisodeFeedResponseCopyWith<$Res> {
  factory $EpisodeFeedResponseCopyWith(
    EpisodeFeedResponse value,
    $Res Function(EpisodeFeedResponse) then,
  ) = _$EpisodeFeedResponseCopyWithImpl<$Res, EpisodeFeedResponse>;
  @useResult
  $Res call({List<EpisodeWithChannel> episodes, int total});
}

/// @nodoc
class _$EpisodeFeedResponseCopyWithImpl<$Res, $Val extends EpisodeFeedResponse>
    implements $EpisodeFeedResponseCopyWith<$Res> {
  _$EpisodeFeedResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EpisodeFeedResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? episodes = null, Object? total = null}) {
    return _then(
      _value.copyWith(
            episodes: null == episodes
                ? _value.episodes
                : episodes // ignore: cast_nullable_to_non_nullable
                      as List<EpisodeWithChannel>,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EpisodeFeedResponseImplCopyWith<$Res>
    implements $EpisodeFeedResponseCopyWith<$Res> {
  factory _$$EpisodeFeedResponseImplCopyWith(
    _$EpisodeFeedResponseImpl value,
    $Res Function(_$EpisodeFeedResponseImpl) then,
  ) = __$$EpisodeFeedResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<EpisodeWithChannel> episodes, int total});
}

/// @nodoc
class __$$EpisodeFeedResponseImplCopyWithImpl<$Res>
    extends _$EpisodeFeedResponseCopyWithImpl<$Res, _$EpisodeFeedResponseImpl>
    implements _$$EpisodeFeedResponseImplCopyWith<$Res> {
  __$$EpisodeFeedResponseImplCopyWithImpl(
    _$EpisodeFeedResponseImpl _value,
    $Res Function(_$EpisodeFeedResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EpisodeFeedResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? episodes = null, Object? total = null}) {
    return _then(
      _$EpisodeFeedResponseImpl(
        episodes: null == episodes
            ? _value._episodes
            : episodes // ignore: cast_nullable_to_non_nullable
                  as List<EpisodeWithChannel>,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EpisodeFeedResponseImpl implements _EpisodeFeedResponse {
  const _$EpisodeFeedResponseImpl({
    required final List<EpisodeWithChannel> episodes,
    required this.total,
  }) : _episodes = episodes;

  factory _$EpisodeFeedResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$EpisodeFeedResponseImplFromJson(json);

  final List<EpisodeWithChannel> _episodes;
  @override
  List<EpisodeWithChannel> get episodes {
    if (_episodes is EqualUnmodifiableListView) return _episodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_episodes);
  }

  @override
  final int total;

  @override
  String toString() {
    return 'EpisodeFeedResponse(episodes: $episodes, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EpisodeFeedResponseImpl &&
            const DeepCollectionEquality().equals(other._episodes, _episodes) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_episodes),
    total,
  );

  /// Create a copy of EpisodeFeedResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EpisodeFeedResponseImplCopyWith<_$EpisodeFeedResponseImpl> get copyWith =>
      __$$EpisodeFeedResponseImplCopyWithImpl<_$EpisodeFeedResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EpisodeFeedResponseImplToJson(this);
  }
}

abstract class _EpisodeFeedResponse implements EpisodeFeedResponse {
  const factory _EpisodeFeedResponse({
    required final List<EpisodeWithChannel> episodes,
    required final int total,
  }) = _$EpisodeFeedResponseImpl;

  factory _EpisodeFeedResponse.fromJson(Map<String, dynamic> json) =
      _$EpisodeFeedResponseImpl.fromJson;

  @override
  List<EpisodeWithChannel> get episodes;
  @override
  int get total;

  /// Create a copy of EpisodeFeedResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EpisodeFeedResponseImplCopyWith<_$EpisodeFeedResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
