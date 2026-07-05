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

  /// #26: timed lines when the source is synced (Navidrome structured
  /// lyrics with `start` offsets, or LRCLib `syncedLyrics` LRC). Null or
  /// empty → plain-text rendering of [value]. Serialized so the offline
  /// lyrics cache round-trips the sync data.
  List<LyricsLine>? get lines => throw _privateConstructorUsedError;

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
  $Res call({
    String? artist,
    String? title,
    String? value,
    List<LyricsLine>? lines,
  });
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
    Object? lines = freezed,
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
            lines: freezed == lines
                ? _value.lines
                : lines // ignore: cast_nullable_to_non_nullable
                      as List<LyricsLine>?,
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
  $Res call({
    String? artist,
    String? title,
    String? value,
    List<LyricsLine>? lines,
  });
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
    Object? lines = freezed,
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
        lines: freezed == lines
            ? _value._lines
            : lines // ignore: cast_nullable_to_non_nullable
                  as List<LyricsLine>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LyricsImpl implements _Lyrics {
  const _$LyricsImpl({
    this.artist,
    this.title,
    this.value,
    final List<LyricsLine>? lines,
  }) : _lines = lines;

  factory _$LyricsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LyricsImplFromJson(json);

  @override
  final String? artist;
  @override
  final String? title;
  @override
  final String? value;

  /// #26: timed lines when the source is synced (Navidrome structured
  /// lyrics with `start` offsets, or LRCLib `syncedLyrics` LRC). Null or
  /// empty → plain-text rendering of [value]. Serialized so the offline
  /// lyrics cache round-trips the sync data.
  final List<LyricsLine>? _lines;

  /// #26: timed lines when the source is synced (Navidrome structured
  /// lyrics with `start` offsets, or LRCLib `syncedLyrics` LRC). Null or
  /// empty → plain-text rendering of [value]. Serialized so the offline
  /// lyrics cache round-trips the sync data.
  @override
  List<LyricsLine>? get lines {
    final value = _lines;
    if (value == null) return null;
    if (_lines is EqualUnmodifiableListView) return _lines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Lyrics(artist: $artist, title: $title, value: $value, lines: $lines)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LyricsImpl &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.value, value) || other.value == value) &&
            const DeepCollectionEquality().equals(other._lines, _lines));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    artist,
    title,
    value,
    const DeepCollectionEquality().hash(_lines),
  );

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
    final List<LyricsLine>? lines,
  }) = _$LyricsImpl;

  factory _Lyrics.fromJson(Map<String, dynamic> json) = _$LyricsImpl.fromJson;

  @override
  String? get artist;
  @override
  String? get title;
  @override
  String? get value;

  /// #26: timed lines when the source is synced (Navidrome structured
  /// lyrics with `start` offsets, or LRCLib `syncedLyrics` LRC). Null or
  /// empty → plain-text rendering of [value]. Serialized so the offline
  /// lyrics cache round-trips the sync data.
  @override
  List<LyricsLine>? get lines;

  /// Create a copy of Lyrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LyricsImplCopyWith<_$LyricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LyricsLine _$LyricsLineFromJson(Map<String, dynamic> json) {
  return _LyricsLine.fromJson(json);
}

/// @nodoc
mixin _$LyricsLine {
  int get start => throw _privateConstructorUsedError;
  String get value => throw _privateConstructorUsedError;

  /// Serializes this LyricsLine to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LyricsLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LyricsLineCopyWith<LyricsLine> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LyricsLineCopyWith<$Res> {
  factory $LyricsLineCopyWith(
    LyricsLine value,
    $Res Function(LyricsLine) then,
  ) = _$LyricsLineCopyWithImpl<$Res, LyricsLine>;
  @useResult
  $Res call({int start, String value});
}

/// @nodoc
class _$LyricsLineCopyWithImpl<$Res, $Val extends LyricsLine>
    implements $LyricsLineCopyWith<$Res> {
  _$LyricsLineCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LyricsLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? start = null, Object? value = null}) {
    return _then(
      _value.copyWith(
            start: null == start
                ? _value.start
                : start // ignore: cast_nullable_to_non_nullable
                      as int,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LyricsLineImplCopyWith<$Res>
    implements $LyricsLineCopyWith<$Res> {
  factory _$$LyricsLineImplCopyWith(
    _$LyricsLineImpl value,
    $Res Function(_$LyricsLineImpl) then,
  ) = __$$LyricsLineImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int start, String value});
}

/// @nodoc
class __$$LyricsLineImplCopyWithImpl<$Res>
    extends _$LyricsLineCopyWithImpl<$Res, _$LyricsLineImpl>
    implements _$$LyricsLineImplCopyWith<$Res> {
  __$$LyricsLineImplCopyWithImpl(
    _$LyricsLineImpl _value,
    $Res Function(_$LyricsLineImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LyricsLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? start = null, Object? value = null}) {
    return _then(
      _$LyricsLineImpl(
        start: null == start
            ? _value.start
            : start // ignore: cast_nullable_to_non_nullable
                  as int,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LyricsLineImpl implements _LyricsLine {
  const _$LyricsLineImpl({required this.start, required this.value});

  factory _$LyricsLineImpl.fromJson(Map<String, dynamic> json) =>
      _$$LyricsLineImplFromJson(json);

  @override
  final int start;
  @override
  final String value;

  @override
  String toString() {
    return 'LyricsLine(start: $start, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LyricsLineImpl &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, start, value);

  /// Create a copy of LyricsLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LyricsLineImplCopyWith<_$LyricsLineImpl> get copyWith =>
      __$$LyricsLineImplCopyWithImpl<_$LyricsLineImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LyricsLineImplToJson(this);
  }
}

abstract class _LyricsLine implements LyricsLine {
  const factory _LyricsLine({
    required final int start,
    required final String value,
  }) = _$LyricsLineImpl;

  factory _LyricsLine.fromJson(Map<String, dynamic> json) =
      _$LyricsLineImpl.fromJson;

  @override
  int get start;
  @override
  String get value;

  /// Create a copy of LyricsLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LyricsLineImplCopyWith<_$LyricsLineImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
