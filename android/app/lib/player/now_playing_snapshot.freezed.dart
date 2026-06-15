// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'now_playing_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NowPlayingSnapshot _$NowPlayingSnapshotFromJson(Map<String, dynamic> json) {
  return _NowPlayingSnapshot.fromJson(json);
}

/// @nodoc
mixin _$NowPlayingSnapshot {
  List<Song> get songs => throw _privateConstructorUsedError;
  int get currentIndex => throw _privateConstructorUsedError;
  int get positionMs => throw _privateConstructorUsedError;
  int get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this NowPlayingSnapshot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NowPlayingSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NowPlayingSnapshotCopyWith<NowPlayingSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NowPlayingSnapshotCopyWith<$Res> {
  factory $NowPlayingSnapshotCopyWith(
    NowPlayingSnapshot value,
    $Res Function(NowPlayingSnapshot) then,
  ) = _$NowPlayingSnapshotCopyWithImpl<$Res, NowPlayingSnapshot>;
  @useResult
  $Res call({
    List<Song> songs,
    int currentIndex,
    int positionMs,
    int updatedAt,
  });
}

/// @nodoc
class _$NowPlayingSnapshotCopyWithImpl<$Res, $Val extends NowPlayingSnapshot>
    implements $NowPlayingSnapshotCopyWith<$Res> {
  _$NowPlayingSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NowPlayingSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? songs = null,
    Object? currentIndex = null,
    Object? positionMs = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            songs: null == songs
                ? _value.songs
                : songs // ignore: cast_nullable_to_non_nullable
                      as List<Song>,
            currentIndex: null == currentIndex
                ? _value.currentIndex
                : currentIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            positionMs: null == positionMs
                ? _value.positionMs
                : positionMs // ignore: cast_nullable_to_non_nullable
                      as int,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NowPlayingSnapshotImplCopyWith<$Res>
    implements $NowPlayingSnapshotCopyWith<$Res> {
  factory _$$NowPlayingSnapshotImplCopyWith(
    _$NowPlayingSnapshotImpl value,
    $Res Function(_$NowPlayingSnapshotImpl) then,
  ) = __$$NowPlayingSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Song> songs,
    int currentIndex,
    int positionMs,
    int updatedAt,
  });
}

/// @nodoc
class __$$NowPlayingSnapshotImplCopyWithImpl<$Res>
    extends _$NowPlayingSnapshotCopyWithImpl<$Res, _$NowPlayingSnapshotImpl>
    implements _$$NowPlayingSnapshotImplCopyWith<$Res> {
  __$$NowPlayingSnapshotImplCopyWithImpl(
    _$NowPlayingSnapshotImpl _value,
    $Res Function(_$NowPlayingSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NowPlayingSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? songs = null,
    Object? currentIndex = null,
    Object? positionMs = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$NowPlayingSnapshotImpl(
        songs: null == songs
            ? _value._songs
            : songs // ignore: cast_nullable_to_non_nullable
                  as List<Song>,
        currentIndex: null == currentIndex
            ? _value.currentIndex
            : currentIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        positionMs: null == positionMs
            ? _value.positionMs
            : positionMs // ignore: cast_nullable_to_non_nullable
                  as int,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NowPlayingSnapshotImpl implements _NowPlayingSnapshot {
  const _$NowPlayingSnapshotImpl({
    final List<Song> songs = const <Song>[],
    this.currentIndex = 0,
    this.positionMs = 0,
    this.updatedAt = 0,
  }) : _songs = songs;

  factory _$NowPlayingSnapshotImpl.fromJson(Map<String, dynamic> json) =>
      _$$NowPlayingSnapshotImplFromJson(json);

  final List<Song> _songs;
  @override
  @JsonKey()
  List<Song> get songs {
    if (_songs is EqualUnmodifiableListView) return _songs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_songs);
  }

  @override
  @JsonKey()
  final int currentIndex;
  @override
  @JsonKey()
  final int positionMs;
  @override
  @JsonKey()
  final int updatedAt;

  @override
  String toString() {
    return 'NowPlayingSnapshot(songs: $songs, currentIndex: $currentIndex, positionMs: $positionMs, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NowPlayingSnapshotImpl &&
            const DeepCollectionEquality().equals(other._songs, _songs) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_songs),
    currentIndex,
    positionMs,
    updatedAt,
  );

  /// Create a copy of NowPlayingSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NowPlayingSnapshotImplCopyWith<_$NowPlayingSnapshotImpl> get copyWith =>
      __$$NowPlayingSnapshotImplCopyWithImpl<_$NowPlayingSnapshotImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NowPlayingSnapshotImplToJson(this);
  }
}

abstract class _NowPlayingSnapshot implements NowPlayingSnapshot {
  const factory _NowPlayingSnapshot({
    final List<Song> songs,
    final int currentIndex,
    final int positionMs,
    final int updatedAt,
  }) = _$NowPlayingSnapshotImpl;

  factory _NowPlayingSnapshot.fromJson(Map<String, dynamic> json) =
      _$NowPlayingSnapshotImpl.fromJson;

  @override
  List<Song> get songs;
  @override
  int get currentIndex;
  @override
  int get positionMs;
  @override
  int get updatedAt;

  /// Create a copy of NowPlayingSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NowPlayingSnapshotImplCopyWith<_$NowPlayingSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
