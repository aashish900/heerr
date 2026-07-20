// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EpisodeListResponse _$EpisodeListResponseFromJson(Map<String, dynamic> json) {
  return _EpisodeListResponse.fromJson(json);
}

/// @nodoc
mixin _$EpisodeListResponse {
  List<PodcastEpisode> get episodes => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  /// Serializes this EpisodeListResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EpisodeListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EpisodeListResponseCopyWith<EpisodeListResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EpisodeListResponseCopyWith<$Res> {
  factory $EpisodeListResponseCopyWith(
    EpisodeListResponse value,
    $Res Function(EpisodeListResponse) then,
  ) = _$EpisodeListResponseCopyWithImpl<$Res, EpisodeListResponse>;
  @useResult
  $Res call({List<PodcastEpisode> episodes, int total});
}

/// @nodoc
class _$EpisodeListResponseCopyWithImpl<$Res, $Val extends EpisodeListResponse>
    implements $EpisodeListResponseCopyWith<$Res> {
  _$EpisodeListResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EpisodeListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? episodes = null, Object? total = null}) {
    return _then(
      _value.copyWith(
            episodes: null == episodes
                ? _value.episodes
                : episodes // ignore: cast_nullable_to_non_nullable
                      as List<PodcastEpisode>,
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
abstract class _$$EpisodeListResponseImplCopyWith<$Res>
    implements $EpisodeListResponseCopyWith<$Res> {
  factory _$$EpisodeListResponseImplCopyWith(
    _$EpisodeListResponseImpl value,
    $Res Function(_$EpisodeListResponseImpl) then,
  ) = __$$EpisodeListResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<PodcastEpisode> episodes, int total});
}

/// @nodoc
class __$$EpisodeListResponseImplCopyWithImpl<$Res>
    extends _$EpisodeListResponseCopyWithImpl<$Res, _$EpisodeListResponseImpl>
    implements _$$EpisodeListResponseImplCopyWith<$Res> {
  __$$EpisodeListResponseImplCopyWithImpl(
    _$EpisodeListResponseImpl _value,
    $Res Function(_$EpisodeListResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EpisodeListResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? episodes = null, Object? total = null}) {
    return _then(
      _$EpisodeListResponseImpl(
        episodes: null == episodes
            ? _value._episodes
            : episodes // ignore: cast_nullable_to_non_nullable
                  as List<PodcastEpisode>,
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
class _$EpisodeListResponseImpl implements _EpisodeListResponse {
  const _$EpisodeListResponseImpl({
    required final List<PodcastEpisode> episodes,
    required this.total,
  }) : _episodes = episodes;

  factory _$EpisodeListResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$EpisodeListResponseImplFromJson(json);

  final List<PodcastEpisode> _episodes;
  @override
  List<PodcastEpisode> get episodes {
    if (_episodes is EqualUnmodifiableListView) return _episodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_episodes);
  }

  @override
  final int total;

  @override
  String toString() {
    return 'EpisodeListResponse(episodes: $episodes, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EpisodeListResponseImpl &&
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

  /// Create a copy of EpisodeListResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EpisodeListResponseImplCopyWith<_$EpisodeListResponseImpl> get copyWith =>
      __$$EpisodeListResponseImplCopyWithImpl<_$EpisodeListResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EpisodeListResponseImplToJson(this);
  }
}

abstract class _EpisodeListResponse implements EpisodeListResponse {
  const factory _EpisodeListResponse({
    required final List<PodcastEpisode> episodes,
    required final int total,
  }) = _$EpisodeListResponseImpl;

  factory _EpisodeListResponse.fromJson(Map<String, dynamic> json) =
      _$EpisodeListResponseImpl.fromJson;

  @override
  List<PodcastEpisode> get episodes;
  @override
  int get total;

  /// Create a copy of EpisodeListResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EpisodeListResponseImplCopyWith<_$EpisodeListResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
