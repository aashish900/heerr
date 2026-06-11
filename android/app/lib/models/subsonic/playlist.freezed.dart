// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playlist.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Playlist _$PlaylistFromJson(Map<String, dynamic> json) {
  return _Playlist.fromJson(json);
}

/// @nodoc
mixin _$Playlist {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;
  String? get owner => throw _privateConstructorUsedError;
  bool? get public => throw _privateConstructorUsedError;
  @JsonKey(name: 'songCount')
  int? get songCount => throw _privateConstructorUsedError;
  int? get duration => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  String? get changed => throw _privateConstructorUsedError;
  @JsonKey(name: 'coverArt')
  String? get coverArt => throw _privateConstructorUsedError;
  List<Song> get entry => throw _privateConstructorUsedError;

  /// Serializes this Playlist to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Playlist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlaylistCopyWith<Playlist> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlaylistCopyWith<$Res> {
  factory $PlaylistCopyWith(Playlist value, $Res Function(Playlist) then) =
      _$PlaylistCopyWithImpl<$Res, Playlist>;
  @useResult
  $Res call({
    String id,
    String name,
    String? comment,
    String? owner,
    bool? public,
    @JsonKey(name: 'songCount') int? songCount,
    int? duration,
    String? created,
    String? changed,
    @JsonKey(name: 'coverArt') String? coverArt,
    List<Song> entry,
  });
}

/// @nodoc
class _$PlaylistCopyWithImpl<$Res, $Val extends Playlist>
    implements $PlaylistCopyWith<$Res> {
  _$PlaylistCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Playlist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? comment = freezed,
    Object? owner = freezed,
    Object? public = freezed,
    Object? songCount = freezed,
    Object? duration = freezed,
    Object? created = freezed,
    Object? changed = freezed,
    Object? coverArt = freezed,
    Object? entry = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            comment: freezed == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String?,
            owner: freezed == owner
                ? _value.owner
                : owner // ignore: cast_nullable_to_non_nullable
                      as String?,
            public: freezed == public
                ? _value.public
                : public // ignore: cast_nullable_to_non_nullable
                      as bool?,
            songCount: freezed == songCount
                ? _value.songCount
                : songCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            duration: freezed == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as int?,
            created: freezed == created
                ? _value.created
                : created // ignore: cast_nullable_to_non_nullable
                      as String?,
            changed: freezed == changed
                ? _value.changed
                : changed // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverArt: freezed == coverArt
                ? _value.coverArt
                : coverArt // ignore: cast_nullable_to_non_nullable
                      as String?,
            entry: null == entry
                ? _value.entry
                : entry // ignore: cast_nullable_to_non_nullable
                      as List<Song>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlaylistImplCopyWith<$Res>
    implements $PlaylistCopyWith<$Res> {
  factory _$$PlaylistImplCopyWith(
    _$PlaylistImpl value,
    $Res Function(_$PlaylistImpl) then,
  ) = __$$PlaylistImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? comment,
    String? owner,
    bool? public,
    @JsonKey(name: 'songCount') int? songCount,
    int? duration,
    String? created,
    String? changed,
    @JsonKey(name: 'coverArt') String? coverArt,
    List<Song> entry,
  });
}

/// @nodoc
class __$$PlaylistImplCopyWithImpl<$Res>
    extends _$PlaylistCopyWithImpl<$Res, _$PlaylistImpl>
    implements _$$PlaylistImplCopyWith<$Res> {
  __$$PlaylistImplCopyWithImpl(
    _$PlaylistImpl _value,
    $Res Function(_$PlaylistImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Playlist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? comment = freezed,
    Object? owner = freezed,
    Object? public = freezed,
    Object? songCount = freezed,
    Object? duration = freezed,
    Object? created = freezed,
    Object? changed = freezed,
    Object? coverArt = freezed,
    Object? entry = null,
  }) {
    return _then(
      _$PlaylistImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        comment: freezed == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
        owner: freezed == owner
            ? _value.owner
            : owner // ignore: cast_nullable_to_non_nullable
                  as String?,
        public: freezed == public
            ? _value.public
            : public // ignore: cast_nullable_to_non_nullable
                  as bool?,
        songCount: freezed == songCount
            ? _value.songCount
            : songCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        duration: freezed == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as int?,
        created: freezed == created
            ? _value.created
            : created // ignore: cast_nullable_to_non_nullable
                  as String?,
        changed: freezed == changed
            ? _value.changed
            : changed // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverArt: freezed == coverArt
            ? _value.coverArt
            : coverArt // ignore: cast_nullable_to_non_nullable
                  as String?,
        entry: null == entry
            ? _value._entry
            : entry // ignore: cast_nullable_to_non_nullable
                  as List<Song>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlaylistImpl implements _Playlist {
  const _$PlaylistImpl({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.public,
    @JsonKey(name: 'songCount') this.songCount,
    this.duration,
    this.created,
    this.changed,
    @JsonKey(name: 'coverArt') this.coverArt,
    final List<Song> entry = const <Song>[],
  }) : _entry = entry;

  factory _$PlaylistImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlaylistImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? comment;
  @override
  final String? owner;
  @override
  final bool? public;
  @override
  @JsonKey(name: 'songCount')
  final int? songCount;
  @override
  final int? duration;
  @override
  final String? created;
  @override
  final String? changed;
  @override
  @JsonKey(name: 'coverArt')
  final String? coverArt;
  final List<Song> _entry;
  @override
  @JsonKey()
  List<Song> get entry {
    if (_entry is EqualUnmodifiableListView) return _entry;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entry);
  }

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, comment: $comment, owner: $owner, public: $public, songCount: $songCount, duration: $duration, created: $created, changed: $changed, coverArt: $coverArt, entry: $entry)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlaylistImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.public, public) || other.public == public) &&
            (identical(other.songCount, songCount) ||
                other.songCount == songCount) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.changed, changed) || other.changed == changed) &&
            (identical(other.coverArt, coverArt) ||
                other.coverArt == coverArt) &&
            const DeepCollectionEquality().equals(other._entry, _entry));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    comment,
    owner,
    public,
    songCount,
    duration,
    created,
    changed,
    coverArt,
    const DeepCollectionEquality().hash(_entry),
  );

  /// Create a copy of Playlist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlaylistImplCopyWith<_$PlaylistImpl> get copyWith =>
      __$$PlaylistImplCopyWithImpl<_$PlaylistImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlaylistImplToJson(this);
  }
}

abstract class _Playlist implements Playlist {
  const factory _Playlist({
    required final String id,
    required final String name,
    final String? comment,
    final String? owner,
    final bool? public,
    @JsonKey(name: 'songCount') final int? songCount,
    final int? duration,
    final String? created,
    final String? changed,
    @JsonKey(name: 'coverArt') final String? coverArt,
    final List<Song> entry,
  }) = _$PlaylistImpl;

  factory _Playlist.fromJson(Map<String, dynamic> json) =
      _$PlaylistImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get comment;
  @override
  String? get owner;
  @override
  bool? get public;
  @override
  @JsonKey(name: 'songCount')
  int? get songCount;
  @override
  int? get duration;
  @override
  String? get created;
  @override
  String? get changed;
  @override
  @JsonKey(name: 'coverArt')
  String? get coverArt;
  @override
  List<Song> get entry;

  /// Create a copy of Playlist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlaylistImplCopyWith<_$PlaylistImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
