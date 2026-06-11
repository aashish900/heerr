// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'album.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Album _$AlbumFromJson(Map<String, dynamic> json) {
  return _Album.fromJson(json);
}

/// @nodoc
mixin _$Album {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get artist => throw _privateConstructorUsedError;
  @JsonKey(name: 'artistId')
  String? get artistId => throw _privateConstructorUsedError;
  @JsonKey(name: 'coverArt')
  String? get coverArt => throw _privateConstructorUsedError;
  @JsonKey(name: 'songCount')
  int? get songCount => throw _privateConstructorUsedError;
  int? get duration => throw _privateConstructorUsedError;
  int? get year => throw _privateConstructorUsedError;
  String? get genre => throw _privateConstructorUsedError;
  String? get created => throw _privateConstructorUsedError;
  List<Song> get song => throw _privateConstructorUsedError;

  /// Serializes this Album to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Album
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AlbumCopyWith<Album> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AlbumCopyWith<$Res> {
  factory $AlbumCopyWith(Album value, $Res Function(Album) then) =
      _$AlbumCopyWithImpl<$Res, Album>;
  @useResult
  $Res call({
    String id,
    String name,
    String? artist,
    @JsonKey(name: 'artistId') String? artistId,
    @JsonKey(name: 'coverArt') String? coverArt,
    @JsonKey(name: 'songCount') int? songCount,
    int? duration,
    int? year,
    String? genre,
    String? created,
    List<Song> song,
  });
}

/// @nodoc
class _$AlbumCopyWithImpl<$Res, $Val extends Album>
    implements $AlbumCopyWith<$Res> {
  _$AlbumCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Album
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artist = freezed,
    Object? artistId = freezed,
    Object? coverArt = freezed,
    Object? songCount = freezed,
    Object? duration = freezed,
    Object? year = freezed,
    Object? genre = freezed,
    Object? created = freezed,
    Object? song = null,
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
            artist: freezed == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String?,
            artistId: freezed == artistId
                ? _value.artistId
                : artistId // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverArt: freezed == coverArt
                ? _value.coverArt
                : coverArt // ignore: cast_nullable_to_non_nullable
                      as String?,
            songCount: freezed == songCount
                ? _value.songCount
                : songCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            duration: freezed == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as int?,
            year: freezed == year
                ? _value.year
                : year // ignore: cast_nullable_to_non_nullable
                      as int?,
            genre: freezed == genre
                ? _value.genre
                : genre // ignore: cast_nullable_to_non_nullable
                      as String?,
            created: freezed == created
                ? _value.created
                : created // ignore: cast_nullable_to_non_nullable
                      as String?,
            song: null == song
                ? _value.song
                : song // ignore: cast_nullable_to_non_nullable
                      as List<Song>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AlbumImplCopyWith<$Res> implements $AlbumCopyWith<$Res> {
  factory _$$AlbumImplCopyWith(
    _$AlbumImpl value,
    $Res Function(_$AlbumImpl) then,
  ) = __$$AlbumImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? artist,
    @JsonKey(name: 'artistId') String? artistId,
    @JsonKey(name: 'coverArt') String? coverArt,
    @JsonKey(name: 'songCount') int? songCount,
    int? duration,
    int? year,
    String? genre,
    String? created,
    List<Song> song,
  });
}

/// @nodoc
class __$$AlbumImplCopyWithImpl<$Res>
    extends _$AlbumCopyWithImpl<$Res, _$AlbumImpl>
    implements _$$AlbumImplCopyWith<$Res> {
  __$$AlbumImplCopyWithImpl(
    _$AlbumImpl _value,
    $Res Function(_$AlbumImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Album
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artist = freezed,
    Object? artistId = freezed,
    Object? coverArt = freezed,
    Object? songCount = freezed,
    Object? duration = freezed,
    Object? year = freezed,
    Object? genre = freezed,
    Object? created = freezed,
    Object? song = null,
  }) {
    return _then(
      _$AlbumImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: freezed == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String?,
        artistId: freezed == artistId
            ? _value.artistId
            : artistId // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverArt: freezed == coverArt
            ? _value.coverArt
            : coverArt // ignore: cast_nullable_to_non_nullable
                  as String?,
        songCount: freezed == songCount
            ? _value.songCount
            : songCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        duration: freezed == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as int?,
        year: freezed == year
            ? _value.year
            : year // ignore: cast_nullable_to_non_nullable
                  as int?,
        genre: freezed == genre
            ? _value.genre
            : genre // ignore: cast_nullable_to_non_nullable
                  as String?,
        created: freezed == created
            ? _value.created
            : created // ignore: cast_nullable_to_non_nullable
                  as String?,
        song: null == song
            ? _value._song
            : song // ignore: cast_nullable_to_non_nullable
                  as List<Song>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AlbumImpl implements _Album {
  const _$AlbumImpl({
    required this.id,
    required this.name,
    this.artist,
    @JsonKey(name: 'artistId') this.artistId,
    @JsonKey(name: 'coverArt') this.coverArt,
    @JsonKey(name: 'songCount') this.songCount,
    this.duration,
    this.year,
    this.genre,
    this.created,
    final List<Song> song = const <Song>[],
  }) : _song = song;

  factory _$AlbumImpl.fromJson(Map<String, dynamic> json) =>
      _$$AlbumImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? artist;
  @override
  @JsonKey(name: 'artistId')
  final String? artistId;
  @override
  @JsonKey(name: 'coverArt')
  final String? coverArt;
  @override
  @JsonKey(name: 'songCount')
  final int? songCount;
  @override
  final int? duration;
  @override
  final int? year;
  @override
  final String? genre;
  @override
  final String? created;
  final List<Song> _song;
  @override
  @JsonKey()
  List<Song> get song {
    if (_song is EqualUnmodifiableListView) return _song;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_song);
  }

  @override
  String toString() {
    return 'Album(id: $id, name: $name, artist: $artist, artistId: $artistId, coverArt: $coverArt, songCount: $songCount, duration: $duration, year: $year, genre: $genre, created: $created, song: $song)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AlbumImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.artistId, artistId) ||
                other.artistId == artistId) &&
            (identical(other.coverArt, coverArt) ||
                other.coverArt == coverArt) &&
            (identical(other.songCount, songCount) ||
                other.songCount == songCount) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.genre, genre) || other.genre == genre) &&
            (identical(other.created, created) || other.created == created) &&
            const DeepCollectionEquality().equals(other._song, _song));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    artist,
    artistId,
    coverArt,
    songCount,
    duration,
    year,
    genre,
    created,
    const DeepCollectionEquality().hash(_song),
  );

  /// Create a copy of Album
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AlbumImplCopyWith<_$AlbumImpl> get copyWith =>
      __$$AlbumImplCopyWithImpl<_$AlbumImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AlbumImplToJson(this);
  }
}

abstract class _Album implements Album {
  const factory _Album({
    required final String id,
    required final String name,
    final String? artist,
    @JsonKey(name: 'artistId') final String? artistId,
    @JsonKey(name: 'coverArt') final String? coverArt,
    @JsonKey(name: 'songCount') final int? songCount,
    final int? duration,
    final int? year,
    final String? genre,
    final String? created,
    final List<Song> song,
  }) = _$AlbumImpl;

  factory _Album.fromJson(Map<String, dynamic> json) = _$AlbumImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get artist;
  @override
  @JsonKey(name: 'artistId')
  String? get artistId;
  @override
  @JsonKey(name: 'coverArt')
  String? get coverArt;
  @override
  @JsonKey(name: 'songCount')
  int? get songCount;
  @override
  int? get duration;
  @override
  int? get year;
  @override
  String? get genre;
  @override
  String? get created;
  @override
  List<Song> get song;

  /// Create a copy of Album
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AlbumImplCopyWith<_$AlbumImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
