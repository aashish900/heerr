// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'song.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Song _$SongFromJson(Map<String, dynamic> json) {
  return _Song.fromJson(json);
}

/// @nodoc
mixin _$Song {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get artist => throw _privateConstructorUsedError;
  @JsonKey(name: 'artistId')
  String? get artistId => throw _privateConstructorUsedError;
  String? get album => throw _privateConstructorUsedError;
  @JsonKey(name: 'albumId')
  String? get albumId => throw _privateConstructorUsedError;
  @JsonKey(name: 'coverArt')
  String? get coverArt => throw _privateConstructorUsedError;
  int? get duration => throw _privateConstructorUsedError;
  int? get track => throw _privateConstructorUsedError;
  int? get year => throw _privateConstructorUsedError;
  String? get genre => throw _privateConstructorUsedError;
  String? get suffix => throw _privateConstructorUsedError;
  @JsonKey(name: 'contentType')
  String? get contentType => throw _privateConstructorUsedError;
  @JsonKey(name: 'bitRate')
  int? get bitRate => throw _privateConstructorUsedError;
  String? get path => throw _privateConstructorUsedError;
  @JsonKey(name: 'isVideo')
  bool? get isVideo => throw _privateConstructorUsedError;
  int? get size => throw _privateConstructorUsedError;

  /// Serializes this Song to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongCopyWith<Song> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongCopyWith<$Res> {
  factory $SongCopyWith(Song value, $Res Function(Song) then) =
      _$SongCopyWithImpl<$Res, Song>;
  @useResult
  $Res call({
    String id,
    String title,
    String? artist,
    @JsonKey(name: 'artistId') String? artistId,
    String? album,
    @JsonKey(name: 'albumId') String? albumId,
    @JsonKey(name: 'coverArt') String? coverArt,
    int? duration,
    int? track,
    int? year,
    String? genre,
    String? suffix,
    @JsonKey(name: 'contentType') String? contentType,
    @JsonKey(name: 'bitRate') int? bitRate,
    String? path,
    @JsonKey(name: 'isVideo') bool? isVideo,
    int? size,
  });
}

/// @nodoc
class _$SongCopyWithImpl<$Res, $Val extends Song>
    implements $SongCopyWith<$Res> {
  _$SongCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artist = freezed,
    Object? artistId = freezed,
    Object? album = freezed,
    Object? albumId = freezed,
    Object? coverArt = freezed,
    Object? duration = freezed,
    Object? track = freezed,
    Object? year = freezed,
    Object? genre = freezed,
    Object? suffix = freezed,
    Object? contentType = freezed,
    Object? bitRate = freezed,
    Object? path = freezed,
    Object? isVideo = freezed,
    Object? size = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            artist: freezed == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String?,
            artistId: freezed == artistId
                ? _value.artistId
                : artistId // ignore: cast_nullable_to_non_nullable
                      as String?,
            album: freezed == album
                ? _value.album
                : album // ignore: cast_nullable_to_non_nullable
                      as String?,
            albumId: freezed == albumId
                ? _value.albumId
                : albumId // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverArt: freezed == coverArt
                ? _value.coverArt
                : coverArt // ignore: cast_nullable_to_non_nullable
                      as String?,
            duration: freezed == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as int?,
            track: freezed == track
                ? _value.track
                : track // ignore: cast_nullable_to_non_nullable
                      as int?,
            year: freezed == year
                ? _value.year
                : year // ignore: cast_nullable_to_non_nullable
                      as int?,
            genre: freezed == genre
                ? _value.genre
                : genre // ignore: cast_nullable_to_non_nullable
                      as String?,
            suffix: freezed == suffix
                ? _value.suffix
                : suffix // ignore: cast_nullable_to_non_nullable
                      as String?,
            contentType: freezed == contentType
                ? _value.contentType
                : contentType // ignore: cast_nullable_to_non_nullable
                      as String?,
            bitRate: freezed == bitRate
                ? _value.bitRate
                : bitRate // ignore: cast_nullable_to_non_nullable
                      as int?,
            path: freezed == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String?,
            isVideo: freezed == isVideo
                ? _value.isVideo
                : isVideo // ignore: cast_nullable_to_non_nullable
                      as bool?,
            size: freezed == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SongImplCopyWith<$Res> implements $SongCopyWith<$Res> {
  factory _$$SongImplCopyWith(
    _$SongImpl value,
    $Res Function(_$SongImpl) then,
  ) = __$$SongImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? artist,
    @JsonKey(name: 'artistId') String? artistId,
    String? album,
    @JsonKey(name: 'albumId') String? albumId,
    @JsonKey(name: 'coverArt') String? coverArt,
    int? duration,
    int? track,
    int? year,
    String? genre,
    String? suffix,
    @JsonKey(name: 'contentType') String? contentType,
    @JsonKey(name: 'bitRate') int? bitRate,
    String? path,
    @JsonKey(name: 'isVideo') bool? isVideo,
    int? size,
  });
}

/// @nodoc
class __$$SongImplCopyWithImpl<$Res>
    extends _$SongCopyWithImpl<$Res, _$SongImpl>
    implements _$$SongImplCopyWith<$Res> {
  __$$SongImplCopyWithImpl(_$SongImpl _value, $Res Function(_$SongImpl) _then)
    : super(_value, _then);

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artist = freezed,
    Object? artistId = freezed,
    Object? album = freezed,
    Object? albumId = freezed,
    Object? coverArt = freezed,
    Object? duration = freezed,
    Object? track = freezed,
    Object? year = freezed,
    Object? genre = freezed,
    Object? suffix = freezed,
    Object? contentType = freezed,
    Object? bitRate = freezed,
    Object? path = freezed,
    Object? isVideo = freezed,
    Object? size = freezed,
  }) {
    return _then(
      _$SongImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: freezed == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String?,
        artistId: freezed == artistId
            ? _value.artistId
            : artistId // ignore: cast_nullable_to_non_nullable
                  as String?,
        album: freezed == album
            ? _value.album
            : album // ignore: cast_nullable_to_non_nullable
                  as String?,
        albumId: freezed == albumId
            ? _value.albumId
            : albumId // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverArt: freezed == coverArt
            ? _value.coverArt
            : coverArt // ignore: cast_nullable_to_non_nullable
                  as String?,
        duration: freezed == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as int?,
        track: freezed == track
            ? _value.track
            : track // ignore: cast_nullable_to_non_nullable
                  as int?,
        year: freezed == year
            ? _value.year
            : year // ignore: cast_nullable_to_non_nullable
                  as int?,
        genre: freezed == genre
            ? _value.genre
            : genre // ignore: cast_nullable_to_non_nullable
                  as String?,
        suffix: freezed == suffix
            ? _value.suffix
            : suffix // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentType: freezed == contentType
            ? _value.contentType
            : contentType // ignore: cast_nullable_to_non_nullable
                  as String?,
        bitRate: freezed == bitRate
            ? _value.bitRate
            : bitRate // ignore: cast_nullable_to_non_nullable
                  as int?,
        path: freezed == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String?,
        isVideo: freezed == isVideo
            ? _value.isVideo
            : isVideo // ignore: cast_nullable_to_non_nullable
                  as bool?,
        size: freezed == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongImpl implements _Song {
  const _$SongImpl({
    required this.id,
    required this.title,
    this.artist,
    @JsonKey(name: 'artistId') this.artistId,
    this.album,
    @JsonKey(name: 'albumId') this.albumId,
    @JsonKey(name: 'coverArt') this.coverArt,
    this.duration,
    this.track,
    this.year,
    this.genre,
    this.suffix,
    @JsonKey(name: 'contentType') this.contentType,
    @JsonKey(name: 'bitRate') this.bitRate,
    this.path,
    @JsonKey(name: 'isVideo') this.isVideo,
    this.size,
  });

  factory _$SongImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? artist;
  @override
  @JsonKey(name: 'artistId')
  final String? artistId;
  @override
  final String? album;
  @override
  @JsonKey(name: 'albumId')
  final String? albumId;
  @override
  @JsonKey(name: 'coverArt')
  final String? coverArt;
  @override
  final int? duration;
  @override
  final int? track;
  @override
  final int? year;
  @override
  final String? genre;
  @override
  final String? suffix;
  @override
  @JsonKey(name: 'contentType')
  final String? contentType;
  @override
  @JsonKey(name: 'bitRate')
  final int? bitRate;
  @override
  final String? path;
  @override
  @JsonKey(name: 'isVideo')
  final bool? isVideo;
  @override
  final int? size;

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist, artistId: $artistId, album: $album, albumId: $albumId, coverArt: $coverArt, duration: $duration, track: $track, year: $year, genre: $genre, suffix: $suffix, contentType: $contentType, bitRate: $bitRate, path: $path, isVideo: $isVideo, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.artistId, artistId) ||
                other.artistId == artistId) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.albumId, albumId) || other.albumId == albumId) &&
            (identical(other.coverArt, coverArt) ||
                other.coverArt == coverArt) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.track, track) || other.track == track) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.genre, genre) || other.genre == genre) &&
            (identical(other.suffix, suffix) || other.suffix == suffix) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.bitRate, bitRate) || other.bitRate == bitRate) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.isVideo, isVideo) || other.isVideo == isVideo) &&
            (identical(other.size, size) || other.size == size));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    artist,
    artistId,
    album,
    albumId,
    coverArt,
    duration,
    track,
    year,
    genre,
    suffix,
    contentType,
    bitRate,
    path,
    isVideo,
    size,
  );

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongImplCopyWith<_$SongImpl> get copyWith =>
      __$$SongImplCopyWithImpl<_$SongImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongImplToJson(this);
  }
}

abstract class _Song implements Song {
  const factory _Song({
    required final String id,
    required final String title,
    final String? artist,
    @JsonKey(name: 'artistId') final String? artistId,
    final String? album,
    @JsonKey(name: 'albumId') final String? albumId,
    @JsonKey(name: 'coverArt') final String? coverArt,
    final int? duration,
    final int? track,
    final int? year,
    final String? genre,
    final String? suffix,
    @JsonKey(name: 'contentType') final String? contentType,
    @JsonKey(name: 'bitRate') final int? bitRate,
    final String? path,
    @JsonKey(name: 'isVideo') final bool? isVideo,
    final int? size,
  }) = _$SongImpl;

  factory _Song.fromJson(Map<String, dynamic> json) = _$SongImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get artist;
  @override
  @JsonKey(name: 'artistId')
  String? get artistId;
  @override
  String? get album;
  @override
  @JsonKey(name: 'albumId')
  String? get albumId;
  @override
  @JsonKey(name: 'coverArt')
  String? get coverArt;
  @override
  int? get duration;
  @override
  int? get track;
  @override
  int? get year;
  @override
  String? get genre;
  @override
  String? get suffix;
  @override
  @JsonKey(name: 'contentType')
  String? get contentType;
  @override
  @JsonKey(name: 'bitRate')
  int? get bitRate;
  @override
  String? get path;
  @override
  @JsonKey(name: 'isVideo')
  bool? get isVideo;
  @override
  int? get size;

  /// Create a copy of Song
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongImplCopyWith<_$SongImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
