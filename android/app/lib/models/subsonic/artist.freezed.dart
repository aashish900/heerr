// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'artist.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Artist _$ArtistFromJson(Map<String, dynamic> json) {
  return _Artist.fromJson(json);
}

/// @nodoc
mixin _$Artist {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'coverArt')
  String? get coverArt => throw _privateConstructorUsedError;
  @JsonKey(name: 'albumCount')
  int? get albumCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'artistImageUrl')
  String? get artistImageUrl => throw _privateConstructorUsedError;
  List<Album> get album => throw _privateConstructorUsedError;

  /// Serializes this Artist to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Artist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ArtistCopyWith<Artist> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArtistCopyWith<$Res> {
  factory $ArtistCopyWith(Artist value, $Res Function(Artist) then) =
      _$ArtistCopyWithImpl<$Res, Artist>;
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'coverArt') String? coverArt,
    @JsonKey(name: 'albumCount') int? albumCount,
    @JsonKey(name: 'artistImageUrl') String? artistImageUrl,
    List<Album> album,
  });
}

/// @nodoc
class _$ArtistCopyWithImpl<$Res, $Val extends Artist>
    implements $ArtistCopyWith<$Res> {
  _$ArtistCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Artist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? coverArt = freezed,
    Object? albumCount = freezed,
    Object? artistImageUrl = freezed,
    Object? album = null,
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
            coverArt: freezed == coverArt
                ? _value.coverArt
                : coverArt // ignore: cast_nullable_to_non_nullable
                      as String?,
            albumCount: freezed == albumCount
                ? _value.albumCount
                : albumCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            artistImageUrl: freezed == artistImageUrl
                ? _value.artistImageUrl
                : artistImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            album: null == album
                ? _value.album
                : album // ignore: cast_nullable_to_non_nullable
                      as List<Album>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ArtistImplCopyWith<$Res> implements $ArtistCopyWith<$Res> {
  factory _$$ArtistImplCopyWith(
    _$ArtistImpl value,
    $Res Function(_$ArtistImpl) then,
  ) = __$$ArtistImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    @JsonKey(name: 'coverArt') String? coverArt,
    @JsonKey(name: 'albumCount') int? albumCount,
    @JsonKey(name: 'artistImageUrl') String? artistImageUrl,
    List<Album> album,
  });
}

/// @nodoc
class __$$ArtistImplCopyWithImpl<$Res>
    extends _$ArtistCopyWithImpl<$Res, _$ArtistImpl>
    implements _$$ArtistImplCopyWith<$Res> {
  __$$ArtistImplCopyWithImpl(
    _$ArtistImpl _value,
    $Res Function(_$ArtistImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Artist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? coverArt = freezed,
    Object? albumCount = freezed,
    Object? artistImageUrl = freezed,
    Object? album = null,
  }) {
    return _then(
      _$ArtistImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        coverArt: freezed == coverArt
            ? _value.coverArt
            : coverArt // ignore: cast_nullable_to_non_nullable
                  as String?,
        albumCount: freezed == albumCount
            ? _value.albumCount
            : albumCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        artistImageUrl: freezed == artistImageUrl
            ? _value.artistImageUrl
            : artistImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        album: null == album
            ? _value._album
            : album // ignore: cast_nullable_to_non_nullable
                  as List<Album>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ArtistImpl implements _Artist {
  const _$ArtistImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'coverArt') this.coverArt,
    @JsonKey(name: 'albumCount') this.albumCount,
    @JsonKey(name: 'artistImageUrl') this.artistImageUrl,
    final List<Album> album = const <Album>[],
  }) : _album = album;

  factory _$ArtistImpl.fromJson(Map<String, dynamic> json) =>
      _$$ArtistImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'coverArt')
  final String? coverArt;
  @override
  @JsonKey(name: 'albumCount')
  final int? albumCount;
  @override
  @JsonKey(name: 'artistImageUrl')
  final String? artistImageUrl;
  final List<Album> _album;
  @override
  @JsonKey()
  List<Album> get album {
    if (_album is EqualUnmodifiableListView) return _album;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_album);
  }

  @override
  String toString() {
    return 'Artist(id: $id, name: $name, coverArt: $coverArt, albumCount: $albumCount, artistImageUrl: $artistImageUrl, album: $album)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArtistImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.coverArt, coverArt) ||
                other.coverArt == coverArt) &&
            (identical(other.albumCount, albumCount) ||
                other.albumCount == albumCount) &&
            (identical(other.artistImageUrl, artistImageUrl) ||
                other.artistImageUrl == artistImageUrl) &&
            const DeepCollectionEquality().equals(other._album, _album));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    coverArt,
    albumCount,
    artistImageUrl,
    const DeepCollectionEquality().hash(_album),
  );

  /// Create a copy of Artist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ArtistImplCopyWith<_$ArtistImpl> get copyWith =>
      __$$ArtistImplCopyWithImpl<_$ArtistImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ArtistImplToJson(this);
  }
}

abstract class _Artist implements Artist {
  const factory _Artist({
    required final String id,
    required final String name,
    @JsonKey(name: 'coverArt') final String? coverArt,
    @JsonKey(name: 'albumCount') final int? albumCount,
    @JsonKey(name: 'artistImageUrl') final String? artistImageUrl,
    final List<Album> album,
  }) = _$ArtistImpl;

  factory _Artist.fromJson(Map<String, dynamic> json) = _$ArtistImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'coverArt')
  String? get coverArt;
  @override
  @JsonKey(name: 'albumCount')
  int? get albumCount;
  @override
  @JsonKey(name: 'artistImageUrl')
  String? get artistImageUrl;
  @override
  List<Album> get album;

  /// Create a copy of Artist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ArtistImplCopyWith<_$ArtistImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
