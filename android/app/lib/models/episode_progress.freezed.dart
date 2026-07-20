// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EpisodeProgress _$EpisodeProgressFromJson(Map<String, dynamic> json) {
  return _EpisodeProgress.fromJson(json);
}

/// @nodoc
mixin _$EpisodeProgress {
  String get episodeId => throw _privateConstructorUsedError;
  int get positionS => throw _privateConstructorUsedError;
  bool get played => throw _privateConstructorUsedError;

  /// Serializes this EpisodeProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EpisodeProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EpisodeProgressCopyWith<EpisodeProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EpisodeProgressCopyWith<$Res> {
  factory $EpisodeProgressCopyWith(
    EpisodeProgress value,
    $Res Function(EpisodeProgress) then,
  ) = _$EpisodeProgressCopyWithImpl<$Res, EpisodeProgress>;
  @useResult
  $Res call({String episodeId, int positionS, bool played});
}

/// @nodoc
class _$EpisodeProgressCopyWithImpl<$Res, $Val extends EpisodeProgress>
    implements $EpisodeProgressCopyWith<$Res> {
  _$EpisodeProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EpisodeProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? episodeId = null,
    Object? positionS = null,
    Object? played = null,
  }) {
    return _then(
      _value.copyWith(
            episodeId: null == episodeId
                ? _value.episodeId
                : episodeId // ignore: cast_nullable_to_non_nullable
                      as String,
            positionS: null == positionS
                ? _value.positionS
                : positionS // ignore: cast_nullable_to_non_nullable
                      as int,
            played: null == played
                ? _value.played
                : played // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EpisodeProgressImplCopyWith<$Res>
    implements $EpisodeProgressCopyWith<$Res> {
  factory _$$EpisodeProgressImplCopyWith(
    _$EpisodeProgressImpl value,
    $Res Function(_$EpisodeProgressImpl) then,
  ) = __$$EpisodeProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String episodeId, int positionS, bool played});
}

/// @nodoc
class __$$EpisodeProgressImplCopyWithImpl<$Res>
    extends _$EpisodeProgressCopyWithImpl<$Res, _$EpisodeProgressImpl>
    implements _$$EpisodeProgressImplCopyWith<$Res> {
  __$$EpisodeProgressImplCopyWithImpl(
    _$EpisodeProgressImpl _value,
    $Res Function(_$EpisodeProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EpisodeProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? episodeId = null,
    Object? positionS = null,
    Object? played = null,
  }) {
    return _then(
      _$EpisodeProgressImpl(
        episodeId: null == episodeId
            ? _value.episodeId
            : episodeId // ignore: cast_nullable_to_non_nullable
                  as String,
        positionS: null == positionS
            ? _value.positionS
            : positionS // ignore: cast_nullable_to_non_nullable
                  as int,
        played: null == played
            ? _value.played
            : played // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EpisodeProgressImpl implements _EpisodeProgress {
  const _$EpisodeProgressImpl({
    required this.episodeId,
    required this.positionS,
    required this.played,
  });

  factory _$EpisodeProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$EpisodeProgressImplFromJson(json);

  @override
  final String episodeId;
  @override
  final int positionS;
  @override
  final bool played;

  @override
  String toString() {
    return 'EpisodeProgress(episodeId: $episodeId, positionS: $positionS, played: $played)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EpisodeProgressImpl &&
            (identical(other.episodeId, episodeId) ||
                other.episodeId == episodeId) &&
            (identical(other.positionS, positionS) ||
                other.positionS == positionS) &&
            (identical(other.played, played) || other.played == played));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, episodeId, positionS, played);

  /// Create a copy of EpisodeProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EpisodeProgressImplCopyWith<_$EpisodeProgressImpl> get copyWith =>
      __$$EpisodeProgressImplCopyWithImpl<_$EpisodeProgressImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EpisodeProgressImplToJson(this);
  }
}

abstract class _EpisodeProgress implements EpisodeProgress {
  const factory _EpisodeProgress({
    required final String episodeId,
    required final int positionS,
    required final bool played,
  }) = _$EpisodeProgressImpl;

  factory _EpisodeProgress.fromJson(Map<String, dynamic> json) =
      _$EpisodeProgressImpl.fromJson;

  @override
  String get episodeId;
  @override
  int get positionS;
  @override
  bool get played;

  /// Create a copy of EpisodeProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EpisodeProgressImplCopyWith<_$EpisodeProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
