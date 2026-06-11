// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result3.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SearchResult3 _$SearchResult3FromJson(Map<String, dynamic> json) {
  return _SearchResult3.fromJson(json);
}

/// @nodoc
mixin _$SearchResult3 {
  List<Artist> get artist => throw _privateConstructorUsedError;
  List<Album> get album => throw _privateConstructorUsedError;
  List<Song> get song => throw _privateConstructorUsedError;

  /// Serializes this SearchResult3 to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchResult3
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResult3CopyWith<SearchResult3> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResult3CopyWith<$Res> {
  factory $SearchResult3CopyWith(
    SearchResult3 value,
    $Res Function(SearchResult3) then,
  ) = _$SearchResult3CopyWithImpl<$Res, SearchResult3>;
  @useResult
  $Res call({List<Artist> artist, List<Album> album, List<Song> song});
}

/// @nodoc
class _$SearchResult3CopyWithImpl<$Res, $Val extends SearchResult3>
    implements $SearchResult3CopyWith<$Res> {
  _$SearchResult3CopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResult3
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? artist = null,
    Object? album = null,
    Object? song = null,
  }) {
    return _then(
      _value.copyWith(
            artist: null == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as List<Artist>,
            album: null == album
                ? _value.album
                : album // ignore: cast_nullable_to_non_nullable
                      as List<Album>,
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
abstract class _$$SearchResult3ImplCopyWith<$Res>
    implements $SearchResult3CopyWith<$Res> {
  factory _$$SearchResult3ImplCopyWith(
    _$SearchResult3Impl value,
    $Res Function(_$SearchResult3Impl) then,
  ) = __$$SearchResult3ImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Artist> artist, List<Album> album, List<Song> song});
}

/// @nodoc
class __$$SearchResult3ImplCopyWithImpl<$Res>
    extends _$SearchResult3CopyWithImpl<$Res, _$SearchResult3Impl>
    implements _$$SearchResult3ImplCopyWith<$Res> {
  __$$SearchResult3ImplCopyWithImpl(
    _$SearchResult3Impl _value,
    $Res Function(_$SearchResult3Impl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResult3
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? artist = null,
    Object? album = null,
    Object? song = null,
  }) {
    return _then(
      _$SearchResult3Impl(
        artist: null == artist
            ? _value._artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as List<Artist>,
        album: null == album
            ? _value._album
            : album // ignore: cast_nullable_to_non_nullable
                  as List<Album>,
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
class _$SearchResult3Impl implements _SearchResult3 {
  const _$SearchResult3Impl({
    final List<Artist> artist = const <Artist>[],
    final List<Album> album = const <Album>[],
    final List<Song> song = const <Song>[],
  }) : _artist = artist,
       _album = album,
       _song = song;

  factory _$SearchResult3Impl.fromJson(Map<String, dynamic> json) =>
      _$$SearchResult3ImplFromJson(json);

  final List<Artist> _artist;
  @override
  @JsonKey()
  List<Artist> get artist {
    if (_artist is EqualUnmodifiableListView) return _artist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artist);
  }

  final List<Album> _album;
  @override
  @JsonKey()
  List<Album> get album {
    if (_album is EqualUnmodifiableListView) return _album;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_album);
  }

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
    return 'SearchResult3(artist: $artist, album: $album, song: $song)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResult3Impl &&
            const DeepCollectionEquality().equals(other._artist, _artist) &&
            const DeepCollectionEquality().equals(other._album, _album) &&
            const DeepCollectionEquality().equals(other._song, _song));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_artist),
    const DeepCollectionEquality().hash(_album),
    const DeepCollectionEquality().hash(_song),
  );

  /// Create a copy of SearchResult3
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResult3ImplCopyWith<_$SearchResult3Impl> get copyWith =>
      __$$SearchResult3ImplCopyWithImpl<_$SearchResult3Impl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchResult3ImplToJson(this);
  }
}

abstract class _SearchResult3 implements SearchResult3 {
  const factory _SearchResult3({
    final List<Artist> artist,
    final List<Album> album,
    final List<Song> song,
  }) = _$SearchResult3Impl;

  factory _SearchResult3.fromJson(Map<String, dynamic> json) =
      _$SearchResult3Impl.fromJson;

  @override
  List<Artist> get artist;
  @override
  List<Album> get album;
  @override
  List<Song> get song;

  /// Create a copy of SearchResult3
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResult3ImplCopyWith<_$SearchResult3Impl> get copyWith =>
      throw _privateConstructorUsedError;
}
