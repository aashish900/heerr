// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recommended_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecommendedTrack _$RecommendedTrackFromJson(Map<String, dynamic> json) {
  return _RecommendedTrack.fromJson(json);
}

/// @nodoc
mixin _$RecommendedTrack {
  String get title => throw _privateConstructorUsedError;
  String get artist => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_url')
  String get sourceUrl => throw _privateConstructorUsedError;
  double? get score => throw _privateConstructorUsedError;
  bool get inLibrary => throw _privateConstructorUsedError;

  /// Serializes this RecommendedTrack to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecommendedTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecommendedTrackCopyWith<RecommendedTrack> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendedTrackCopyWith<$Res> {
  factory $RecommendedTrackCopyWith(
    RecommendedTrack value,
    $Res Function(RecommendedTrack) then,
  ) = _$RecommendedTrackCopyWithImpl<$Res, RecommendedTrack>;
  @useResult
  $Res call({
    String title,
    String artist,
    @JsonKey(name: 'source_url') String sourceUrl,
    double? score,
    bool inLibrary,
  });
}

/// @nodoc
class _$RecommendedTrackCopyWithImpl<$Res, $Val extends RecommendedTrack>
    implements $RecommendedTrackCopyWith<$Res> {
  _$RecommendedTrackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecommendedTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? artist = null,
    Object? sourceUrl = null,
    Object? score = freezed,
    Object? inLibrary = null,
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
            sourceUrl: null == sourceUrl
                ? _value.sourceUrl
                : sourceUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            score: freezed == score
                ? _value.score
                : score // ignore: cast_nullable_to_non_nullable
                      as double?,
            inLibrary: null == inLibrary
                ? _value.inLibrary
                : inLibrary // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecommendedTrackImplCopyWith<$Res>
    implements $RecommendedTrackCopyWith<$Res> {
  factory _$$RecommendedTrackImplCopyWith(
    _$RecommendedTrackImpl value,
    $Res Function(_$RecommendedTrackImpl) then,
  ) = __$$RecommendedTrackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String title,
    String artist,
    @JsonKey(name: 'source_url') String sourceUrl,
    double? score,
    bool inLibrary,
  });
}

/// @nodoc
class __$$RecommendedTrackImplCopyWithImpl<$Res>
    extends _$RecommendedTrackCopyWithImpl<$Res, _$RecommendedTrackImpl>
    implements _$$RecommendedTrackImplCopyWith<$Res> {
  __$$RecommendedTrackImplCopyWithImpl(
    _$RecommendedTrackImpl _value,
    $Res Function(_$RecommendedTrackImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecommendedTrack
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? artist = null,
    Object? sourceUrl = null,
    Object? score = freezed,
    Object? inLibrary = null,
  }) {
    return _then(
      _$RecommendedTrackImpl(
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: null == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceUrl: null == sourceUrl
            ? _value.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        score: freezed == score
            ? _value.score
            : score // ignore: cast_nullable_to_non_nullable
                  as double?,
        inLibrary: null == inLibrary
            ? _value.inLibrary
            : inLibrary // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecommendedTrackImpl implements _RecommendedTrack {
  const _$RecommendedTrackImpl({
    required this.title,
    required this.artist,
    @JsonKey(name: 'source_url') required this.sourceUrl,
    this.score,
    this.inLibrary = false,
  });

  factory _$RecommendedTrackImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendedTrackImplFromJson(json);

  @override
  final String title;
  @override
  final String artist;
  @override
  @JsonKey(name: 'source_url')
  final String sourceUrl;
  @override
  final double? score;
  @override
  @JsonKey()
  final bool inLibrary;

  @override
  String toString() {
    return 'RecommendedTrack(title: $title, artist: $artist, sourceUrl: $sourceUrl, score: $score, inLibrary: $inLibrary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendedTrackImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.inLibrary, inLibrary) ||
                other.inLibrary == inLibrary));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, title, artist, sourceUrl, score, inLibrary);

  /// Create a copy of RecommendedTrack
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendedTrackImplCopyWith<_$RecommendedTrackImpl> get copyWith =>
      __$$RecommendedTrackImplCopyWithImpl<_$RecommendedTrackImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendedTrackImplToJson(this);
  }
}

abstract class _RecommendedTrack implements RecommendedTrack {
  const factory _RecommendedTrack({
    required final String title,
    required final String artist,
    @JsonKey(name: 'source_url') required final String sourceUrl,
    final double? score,
    final bool inLibrary,
  }) = _$RecommendedTrackImpl;

  factory _RecommendedTrack.fromJson(Map<String, dynamic> json) =
      _$RecommendedTrackImpl.fromJson;

  @override
  String get title;
  @override
  String get artist;
  @override
  @JsonKey(name: 'source_url')
  String get sourceUrl;
  @override
  double? get score;
  @override
  bool get inLibrary;

  /// Create a copy of RecommendedTrack
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecommendedTrackImplCopyWith<_$RecommendedTrackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
