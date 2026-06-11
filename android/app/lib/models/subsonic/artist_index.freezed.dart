// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'artist_index.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ArtistIndex _$ArtistIndexFromJson(Map<String, dynamic> json) {
  return _ArtistIndex.fromJson(json);
}

/// @nodoc
mixin _$ArtistIndex {
  String get name => throw _privateConstructorUsedError;
  List<Artist> get artist => throw _privateConstructorUsedError;

  /// Serializes this ArtistIndex to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ArtistIndex
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ArtistIndexCopyWith<ArtistIndex> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ArtistIndexCopyWith<$Res> {
  factory $ArtistIndexCopyWith(
    ArtistIndex value,
    $Res Function(ArtistIndex) then,
  ) = _$ArtistIndexCopyWithImpl<$Res, ArtistIndex>;
  @useResult
  $Res call({String name, List<Artist> artist});
}

/// @nodoc
class _$ArtistIndexCopyWithImpl<$Res, $Val extends ArtistIndex>
    implements $ArtistIndexCopyWith<$Res> {
  _$ArtistIndexCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ArtistIndex
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? artist = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            artist: null == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as List<Artist>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ArtistIndexImplCopyWith<$Res>
    implements $ArtistIndexCopyWith<$Res> {
  factory _$$ArtistIndexImplCopyWith(
    _$ArtistIndexImpl value,
    $Res Function(_$ArtistIndexImpl) then,
  ) = __$$ArtistIndexImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, List<Artist> artist});
}

/// @nodoc
class __$$ArtistIndexImplCopyWithImpl<$Res>
    extends _$ArtistIndexCopyWithImpl<$Res, _$ArtistIndexImpl>
    implements _$$ArtistIndexImplCopyWith<$Res> {
  __$$ArtistIndexImplCopyWithImpl(
    _$ArtistIndexImpl _value,
    $Res Function(_$ArtistIndexImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ArtistIndex
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? artist = null}) {
    return _then(
      _$ArtistIndexImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: null == artist
            ? _value._artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as List<Artist>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ArtistIndexImpl implements _ArtistIndex {
  const _$ArtistIndexImpl({
    required this.name,
    final List<Artist> artist = const <Artist>[],
  }) : _artist = artist;

  factory _$ArtistIndexImpl.fromJson(Map<String, dynamic> json) =>
      _$$ArtistIndexImplFromJson(json);

  @override
  final String name;
  final List<Artist> _artist;
  @override
  @JsonKey()
  List<Artist> get artist {
    if (_artist is EqualUnmodifiableListView) return _artist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artist);
  }

  @override
  String toString() {
    return 'ArtistIndex(name: $name, artist: $artist)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ArtistIndexImpl &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._artist, _artist));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    const DeepCollectionEquality().hash(_artist),
  );

  /// Create a copy of ArtistIndex
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ArtistIndexImplCopyWith<_$ArtistIndexImpl> get copyWith =>
      __$$ArtistIndexImplCopyWithImpl<_$ArtistIndexImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ArtistIndexImplToJson(this);
  }
}

abstract class _ArtistIndex implements ArtistIndex {
  const factory _ArtistIndex({
    required final String name,
    final List<Artist> artist,
  }) = _$ArtistIndexImpl;

  factory _ArtistIndex.fromJson(Map<String, dynamic> json) =
      _$ArtistIndexImpl.fromJson;

  @override
  String get name;
  @override
  List<Artist> get artist;

  /// Create a copy of ArtistIndex
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ArtistIndexImplCopyWith<_$ArtistIndexImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
