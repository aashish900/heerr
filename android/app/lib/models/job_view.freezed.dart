// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_view.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

JobView _$JobViewFromJson(Map<String, dynamic> json) {
  return _JobView.fromJson(json);
}

/// @nodoc
mixin _$JobView {
  String get jobId => throw _privateConstructorUsedError;
  String get spotifyUri => throw _privateConstructorUsedError;
  SpotifyType get spotifyType => throw _privateConstructorUsedError;
  JobState get state => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  int? get progress => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  String? get outputPath => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get finishedAt => throw _privateConstructorUsedError;

  /// Serializes this JobView to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JobView
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobViewCopyWith<JobView> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobViewCopyWith<$Res> {
  factory $JobViewCopyWith(JobView value, $Res Function(JobView) then) =
      _$JobViewCopyWithImpl<$Res, JobView>;
  @useResult
  $Res call({
    String jobId,
    String spotifyUri,
    SpotifyType spotifyType,
    JobState state,
    String? displayName,
    int? progress,
    String? error,
    String? outputPath,
    DateTime createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  });
}

/// @nodoc
class _$JobViewCopyWithImpl<$Res, $Val extends JobView>
    implements $JobViewCopyWith<$Res> {
  _$JobViewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JobView
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? spotifyUri = null,
    Object? spotifyType = null,
    Object? state = null,
    Object? displayName = freezed,
    Object? progress = freezed,
    Object? error = freezed,
    Object? outputPath = freezed,
    Object? createdAt = null,
    Object? startedAt = freezed,
    Object? finishedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            jobId: null == jobId
                ? _value.jobId
                : jobId // ignore: cast_nullable_to_non_nullable
                      as String,
            spotifyUri: null == spotifyUri
                ? _value.spotifyUri
                : spotifyUri // ignore: cast_nullable_to_non_nullable
                      as String,
            spotifyType: null == spotifyType
                ? _value.spotifyType
                : spotifyType // ignore: cast_nullable_to_non_nullable
                      as SpotifyType,
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as JobState,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            progress: freezed == progress
                ? _value.progress
                : progress // ignore: cast_nullable_to_non_nullable
                      as int?,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            outputPath: freezed == outputPath
                ? _value.outputPath
                : outputPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            finishedAt: freezed == finishedAt
                ? _value.finishedAt
                : finishedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$JobViewImplCopyWith<$Res> implements $JobViewCopyWith<$Res> {
  factory _$$JobViewImplCopyWith(
    _$JobViewImpl value,
    $Res Function(_$JobViewImpl) then,
  ) = __$$JobViewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String jobId,
    String spotifyUri,
    SpotifyType spotifyType,
    JobState state,
    String? displayName,
    int? progress,
    String? error,
    String? outputPath,
    DateTime createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  });
}

/// @nodoc
class __$$JobViewImplCopyWithImpl<$Res>
    extends _$JobViewCopyWithImpl<$Res, _$JobViewImpl>
    implements _$$JobViewImplCopyWith<$Res> {
  __$$JobViewImplCopyWithImpl(
    _$JobViewImpl _value,
    $Res Function(_$JobViewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of JobView
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jobId = null,
    Object? spotifyUri = null,
    Object? spotifyType = null,
    Object? state = null,
    Object? displayName = freezed,
    Object? progress = freezed,
    Object? error = freezed,
    Object? outputPath = freezed,
    Object? createdAt = null,
    Object? startedAt = freezed,
    Object? finishedAt = freezed,
  }) {
    return _then(
      _$JobViewImpl(
        jobId: null == jobId
            ? _value.jobId
            : jobId // ignore: cast_nullable_to_non_nullable
                  as String,
        spotifyUri: null == spotifyUri
            ? _value.spotifyUri
            : spotifyUri // ignore: cast_nullable_to_non_nullable
                  as String,
        spotifyType: null == spotifyType
            ? _value.spotifyType
            : spotifyType // ignore: cast_nullable_to_non_nullable
                  as SpotifyType,
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as JobState,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        progress: freezed == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as int?,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        outputPath: freezed == outputPath
            ? _value.outputPath
            : outputPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        finishedAt: freezed == finishedAt
            ? _value.finishedAt
            : finishedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$JobViewImpl implements _JobView {
  const _$JobViewImpl({
    required this.jobId,
    required this.spotifyUri,
    required this.spotifyType,
    required this.state,
    this.displayName,
    this.progress,
    this.error,
    this.outputPath,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  factory _$JobViewImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobViewImplFromJson(json);

  @override
  final String jobId;
  @override
  final String spotifyUri;
  @override
  final SpotifyType spotifyType;
  @override
  final JobState state;
  @override
  final String? displayName;
  @override
  final int? progress;
  @override
  final String? error;
  @override
  final String? outputPath;
  @override
  final DateTime createdAt;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? finishedAt;

  @override
  String toString() {
    return 'JobView(jobId: $jobId, spotifyUri: $spotifyUri, spotifyType: $spotifyType, state: $state, displayName: $displayName, progress: $progress, error: $error, outputPath: $outputPath, createdAt: $createdAt, startedAt: $startedAt, finishedAt: $finishedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobViewImpl &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.spotifyUri, spotifyUri) ||
                other.spotifyUri == spotifyUri) &&
            (identical(other.spotifyType, spotifyType) ||
                other.spotifyType == spotifyType) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.outputPath, outputPath) ||
                other.outputPath == outputPath) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.finishedAt, finishedAt) ||
                other.finishedAt == finishedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    jobId,
    spotifyUri,
    spotifyType,
    state,
    displayName,
    progress,
    error,
    outputPath,
    createdAt,
    startedAt,
    finishedAt,
  );

  /// Create a copy of JobView
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobViewImplCopyWith<_$JobViewImpl> get copyWith =>
      __$$JobViewImplCopyWithImpl<_$JobViewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobViewImplToJson(this);
  }
}

abstract class _JobView implements JobView {
  const factory _JobView({
    required final String jobId,
    required final String spotifyUri,
    required final SpotifyType spotifyType,
    required final JobState state,
    final String? displayName,
    final int? progress,
    final String? error,
    final String? outputPath,
    required final DateTime createdAt,
    final DateTime? startedAt,
    final DateTime? finishedAt,
  }) = _$JobViewImpl;

  factory _JobView.fromJson(Map<String, dynamic> json) = _$JobViewImpl.fromJson;

  @override
  String get jobId;
  @override
  String get spotifyUri;
  @override
  SpotifyType get spotifyType;
  @override
  JobState get state;
  @override
  String? get displayName;
  @override
  int? get progress;
  @override
  String? get error;
  @override
  String? get outputPath;
  @override
  DateTime get createdAt;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get finishedAt;

  /// Create a copy of JobView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobViewImplCopyWith<_$JobViewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
