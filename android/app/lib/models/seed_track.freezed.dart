// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'seed_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SeedTrack _$SeedTrackFromJson(Map<String, dynamic> json) {
  return _SeedTrack.fromJson(json);
}

/// @nodoc
mixin _$SeedTrack {
  String get title => throw _privateConstructorUsedError;
  String get artist => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_url')
  String? get sourceUrl => throw _privateConstructorUsedError;

  /// Serializes this SeedTrack to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SeedTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeedTrackCopyWith<SeedTrack> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeedTrackCopyWith<$Res> {
  factory $SeedTrackCopyWith(SeedTrack value, $Res Function(SeedTrack) then) =
      _$SeedTrackCopyWithImpl<$Res, SeedTrack>;
  @useResult
  $Res call({
    String title,
    String artist,
    @JsonKey(name: 'source_url') String? sourceUrl,
  });
}

/// @nodoc
class _$SeedTrackCopyWithImpl<$Res, $Val extends SeedTrack>
    implements $SeedTrackCopyWith<$Res> {
  _$SeedTrackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SeedTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? artist = null,
    Object? sourceUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            artist: null == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceUrl: freezed == sourceUrl
                ? _value.sourceUrl
                : sourceUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SeedTrackImplCopyWith<$Res>
    implements $SeedTrackCopyWith<$Res> {
  factory _$$SeedTrackImplCopyWith(
    _$SeedTrackImpl value,
    $Res Function(_$SeedTrackImpl) then,
  ) = __$$SeedTrackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String title,
    String artist,
    @JsonKey(name: 'source_url') String? sourceUrl,
  });
}

/// @nodoc
class __$$SeedTrackImplCopyWithImpl<$Res>
    extends _$SeedTrackCopyWithImpl<$Res, _$SeedTrackImpl>
    implements _$$SeedTrackImplCopyWith<$Res> {
  __$$SeedTrackImplCopyWithImpl(
    _$SeedTrackImpl _value,
    $Res Function(_$SeedTrackImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SeedTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? artist = null,
    Object? sourceUrl = freezed,
  }) {
    return _then(
      _$SeedTrackImpl(
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: null == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceUrl: freezed == sourceUrl
            ? _value.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SeedTrackImpl implements _SeedTrack {
  const _$SeedTrackImpl({
    required this.title,
    required this.artist,
    @JsonKey(name: 'source_url') this.sourceUrl,
  });

  factory _$SeedTrackImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeedTrackImplFromJson(json);

  @override
  final String title;
  @override
  final String artist;
  @override
  @JsonKey(name: 'source_url')
  final String? sourceUrl;

  @override
  String toString() {
    return 'SeedTrack(title: $title, artist: $artist, sourceUrl: $sourceUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeedTrackImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, artist, sourceUrl);

  /// Create a copy of SeedTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeedTrackImplCopyWith<_$SeedTrackImpl> get copyWith =>
      __$$SeedTrackImplCopyWithImpl<_$SeedTrackImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeedTrackImplToJson(this);
  }
}

abstract class _SeedTrack implements SeedTrack {
  const factory _SeedTrack({
    required final String title,
    required final String artist,
    @JsonKey(name: 'source_url') final String? sourceUrl,
  }) = _$SeedTrackImpl;

  factory _SeedTrack.fromJson(Map<String, dynamic> json) =
      _$SeedTrackImpl.fromJson;

  @override
  String get title;
  @override
  String get artist;
  @override
  @JsonKey(name: 'source_url')
  String? get sourceUrl;

  /// Create a copy of SeedTrack
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeedTrackImplCopyWith<_$SeedTrackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
