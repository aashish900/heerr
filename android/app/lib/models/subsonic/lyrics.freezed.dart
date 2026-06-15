// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lyrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Lyrics _$LyricsFromJson(Map<String, dynamic> json) {
  return _Lyrics.fromJson(json);
}

/// @nodoc
mixin _$Lyrics {
  String? get artist => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String? get value => throw _privateConstructorUsedError;

  /// Serializes this Lyrics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Lyrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LyricsCopyWith<Lyrics> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LyricsCopyWith<$Res> {
  factory $LyricsCopyWith(Lyrics value, $Res Function(Lyrics) then) =
      _$LyricsCopyWithImpl<$Res, Lyrics>;
  @useResult
  $Res call({String? artist, String? title, String? value});
}

/// @nodoc
class _$LyricsCopyWithImpl<$Res, $Val extends Lyrics>
    implements $LyricsCopyWith<$Res> {
  _$LyricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Lyrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? artist = freezed,
    Object? title = freezed,
    Object? value = freezed,
  }) {
    return _then(
      _value.copyWith(
            artist: freezed == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            value: freezed == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LyricsImplCopyWith<$Res> implements $LyricsCopyWith<$Res> {
  factory _$$LyricsImplCopyWith(
    _$LyricsImpl value,
    $Res Function(_$LyricsImpl) then,
  ) = __$$LyricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? artist, String? title, String? value});
}

/// @nodoc
class __$$LyricsImplCopyWithImpl<$Res>
    extends _$LyricsCopyWithImpl<$Res, _$LyricsImpl>
    implements _$$LyricsImplCopyWith<$Res> {
  __$$LyricsImplCopyWithImpl(
    _$LyricsImpl _value,
    $Res Function(_$LyricsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Lyrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? artist = freezed,
    Object? title = freezed,
    Object? value = freezed,
  }) {
    return _then(
      _$LyricsImpl(
        artist: freezed == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        value: freezed == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LyricsImpl implements _Lyrics {
  const _$LyricsImpl({this.artist, this.title, this.value});

  factory _$LyricsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LyricsImplFromJson(json);

  @override
  final String? artist;
  @override
  final String? title;
  @override
  final String? value;

  @override
  String toString() {
    return 'Lyrics(artist: $artist, title: $title, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LyricsImpl &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, artist, title, value);

  /// Create a copy of Lyrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LyricsImplCopyWith<_$LyricsImpl> get copyWith =>
      __$$LyricsImplCopyWithImpl<_$LyricsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LyricsImplToJson(this);
  }
}

abstract class _Lyrics implements Lyrics {
  const factory _Lyrics({
    final String? artist,
    final String? title,
    final String? value,
  }) = _$LyricsImpl;

  factory _Lyrics.fromJson(Map<String, dynamic> json) = _$LyricsImpl.fromJson;

  @override
  String? get artist;
  @override
  String? get title;
  @override
  String? get value;

  /// Create a copy of Lyrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LyricsImplCopyWith<_$LyricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
