// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DownloadResponse _$DownloadResponseFromJson(Map<String, dynamic> json) {
  return _DownloadResponse.fromJson(json);
}

/// @nodoc
mixin _$DownloadResponse {
  String get jobId => throw _privateConstructorUsedError;
  JobState get state => throw _privateConstructorUsedError;
  bool get deduped => throw _privateConstructorUsedError;

  /// Serializes this DownloadResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DownloadResponseCopyWith<DownloadResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DownloadResponseCopyWith<$Res> {
  factory $DownloadResponseCopyWith(
    DownloadResponse value,
    $Res Function(DownloadResponse) then,
  ) = _$DownloadResponseCopyWithImpl<$Res, DownloadResponse>;
  @useResult
  $Res call({String jobId, JobState state, bool deduped});
}

/// @nodoc
class _$DownloadResponseCopyWithImpl<$Res, $Val extends DownloadResponse>
    implements $DownloadResponseCopyWith<$Res> {
  _$DownloadResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DownloadResponse
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
abstract class _$$DownloadResponseImplCopyWith<$Res>
    implements $DownloadResponseCopyWith<$Res> {
  factory _$$DownloadResponseImplCopyWith(
    _$DownloadResponseImpl value,
    $Res Function(_$DownloadResponseImpl) then,
  ) = __$$DownloadResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String jobId, JobState state, bool deduped});
}

/// @nodoc
class __$$DownloadResponseImplCopyWithImpl<$Res>
    extends _$DownloadResponseCopyWithImpl<$Res, _$DownloadResponseImpl>
    implements _$$DownloadResponseImplCopyWith<$Res> {
  __$$DownloadResponseImplCopyWithImpl(
    _$DownloadResponseImpl _value,
    $Res Function(_$DownloadResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? state = null,
    Object? deduped = null,
  }) {
    return _then(
      _$DownloadResponseImpl(
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
class _$DownloadResponseImpl implements _DownloadResponse {
  const _$DownloadResponseImpl({
    required this.jobId,
    required this.state,
    required this.deduped,
  });

  factory _$DownloadResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$DownloadResponseImplFromJson(json);

  @override
  final String jobId;
  @override
  final JobState state;
  @override
  final bool deduped;

  @override
  String toString() {
    return 'DownloadResponse(jobId: $jobId, state: $state, deduped: $deduped)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DownloadResponseImpl &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.deduped, deduped) || other.deduped == deduped));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, jobId, state, deduped);

  /// Create a copy of DownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DownloadResponseImplCopyWith<_$DownloadResponseImpl> get copyWith =>
      __$$DownloadResponseImplCopyWithImpl<_$DownloadResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DownloadResponseImplToJson(this);
  }
}

abstract class _DownloadResponse implements DownloadResponse {
  const factory _DownloadResponse({
    required final String jobId,
    required final JobState state,
    required final bool deduped,
  }) = _$DownloadResponseImpl;

  factory _DownloadResponse.fromJson(Map<String, dynamic> json) =
      _$DownloadResponseImpl.fromJson;

  @override
  String get jobId;
  @override
  JobState get state;
  @override
  bool get deduped;

  /// Create a copy of DownloadResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DownloadResponseImplCopyWith<_$DownloadResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
