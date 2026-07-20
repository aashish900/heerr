// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode_download_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EpisodeDownloadResponse _$EpisodeDownloadResponseFromJson(
  Map<String, dynamic> json,
) {
  return _EpisodeDownloadResponse.fromJson(json);
}

/// @nodoc
mixin _$EpisodeDownloadResponse {
  String get jobId => throw _privateConstructorUsedError;
  JobState get state => throw _privateConstructorUsedError;
  bool get deduped => throw _privateConstructorUsedError;

  /// Serializes this EpisodeDownloadResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EpisodeDownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EpisodeDownloadResponseCopyWith<EpisodeDownloadResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EpisodeDownloadResponseCopyWith<$Res> {
  factory $EpisodeDownloadResponseCopyWith(
    EpisodeDownloadResponse value,
    $Res Function(EpisodeDownloadResponse) then,
  ) = _$EpisodeDownloadResponseCopyWithImpl<$Res, EpisodeDownloadResponse>;
  @useResult
  $Res call({String jobId, JobState state, bool deduped});
}

/// @nodoc
class _$EpisodeDownloadResponseCopyWithImpl<
  $Res,
  $Val extends EpisodeDownloadResponse
>
    implements $EpisodeDownloadResponseCopyWith<$Res> {
  _$EpisodeDownloadResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EpisodeDownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? state = null,
    Object? deduped = null,
  }) {
    return _then(
      _value.copyWith(
            jobId: null == jobId
                ? _value.jobId
                : jobId // ignore: cast_nullable_to_non_nullable
                      as String,
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as JobState,
            deduped: null == deduped
                ? _value.deduped
                : deduped // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EpisodeDownloadResponseImplCopyWith<$Res>
    implements $EpisodeDownloadResponseCopyWith<$Res> {
  factory _$$EpisodeDownloadResponseImplCopyWith(
    _$EpisodeDownloadResponseImpl value,
    $Res Function(_$EpisodeDownloadResponseImpl) then,
  ) = __$$EpisodeDownloadResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String jobId, JobState state, bool deduped});
}

/// @nodoc
class __$$EpisodeDownloadResponseImplCopyWithImpl<$Res>
    extends
        _$EpisodeDownloadResponseCopyWithImpl<
          $Res,
          _$EpisodeDownloadResponseImpl
        >
    implements _$$EpisodeDownloadResponseImplCopyWith<$Res> {
  __$$EpisodeDownloadResponseImplCopyWithImpl(
    _$EpisodeDownloadResponseImpl _value,
    $Res Function(_$EpisodeDownloadResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EpisodeDownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? state = null,
    Object? deduped = null,
  }) {
    return _then(
      _$EpisodeDownloadResponseImpl(
        jobId: null == jobId
            ? _value.jobId
            : jobId // ignore: cast_nullable_to_non_nullable
                  as String,
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as JobState,
        deduped: null == deduped
            ? _value.deduped
            : deduped // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EpisodeDownloadResponseImpl implements _EpisodeDownloadResponse {
  const _$EpisodeDownloadResponseImpl({
    required this.jobId,
    required this.state,
    required this.deduped,
  });

  factory _$EpisodeDownloadResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$EpisodeDownloadResponseImplFromJson(json);

  @override
  final String jobId;
  @override
  final JobState state;
  @override
  final bool deduped;

  @override
  String toString() {
    return 'EpisodeDownloadResponse(jobId: $jobId, state: $state, deduped: $deduped)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EpisodeDownloadResponseImpl &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.deduped, deduped) || other.deduped == deduped));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, jobId, state, deduped);

  /// Create a copy of EpisodeDownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EpisodeDownloadResponseImplCopyWith<_$EpisodeDownloadResponseImpl>
  get copyWith =>
      __$$EpisodeDownloadResponseImplCopyWithImpl<
        _$EpisodeDownloadResponseImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EpisodeDownloadResponseImplToJson(this);
  }
}

abstract class _EpisodeDownloadResponse implements EpisodeDownloadResponse {
  const factory _EpisodeDownloadResponse({
    required final String jobId,
    required final JobState state,
    required final bool deduped,
  }) = _$EpisodeDownloadResponseImpl;

  factory _EpisodeDownloadResponse.fromJson(Map<String, dynamic> json) =
      _$EpisodeDownloadResponseImpl.fromJson;

  @override
  String get jobId;
  @override
  JobState get state;
  @override
  bool get deduped;

  /// Create a copy of EpisodeDownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EpisodeDownloadResponseImplCopyWith<_$EpisodeDownloadResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}
