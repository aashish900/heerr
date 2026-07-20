// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'podcast_episode.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PodcastEpisode _$PodcastEpisodeFromJson(Map<String, dynamic> json) {
  return _PodcastEpisode.fromJson(json);
}

/// @nodoc
mixin _$PodcastEpisode {
  String get id => throw _privateConstructorUsedError;
  String get channelId => throw _privateConstructorUsedError;
  String get guid => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  DateTime? get publishedAt => throw _privateConstructorUsedError;
  int? get durationS => throw _privateConstructorUsedError;
  String get enclosureUrl => throw _privateConstructorUsedError;
  String? get enclosureType => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  int? get episodeNo => throw _privateConstructorUsedError;
  int? get seasonNo => throw _privateConstructorUsedError;
  bool get downloaded => throw _privateConstructorUsedError;
  int get positionS => throw _privateConstructorUsedError;
  bool get played => throw _privateConstructorUsedError;

  /// Serializes this PodcastEpisode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PodcastEpisode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PodcastEpisodeCopyWith<PodcastEpisode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PodcastEpisodeCopyWith<$Res> {
  factory $PodcastEpisodeCopyWith(
    PodcastEpisode value,
    $Res Function(PodcastEpisode) then,
  ) = _$PodcastEpisodeCopyWithImpl<$Res, PodcastEpisode>;
  @useResult
  $Res call({
    String id,
    String channelId,
    String guid,
    String title,
    String? description,
    DateTime? publishedAt,
    int? durationS,
    String enclosureUrl,
    String? enclosureType,
    String? imageUrl,
    int? episodeNo,
    int? seasonNo,
    bool downloaded,
    int positionS,
    bool played,
  });
}

/// @nodoc
class _$PodcastEpisodeCopyWithImpl<$Res, $Val extends PodcastEpisode>
    implements $PodcastEpisodeCopyWith<$Res> {
  _$PodcastEpisodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PodcastEpisode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? channelId = null,
    Object? guid = null,
    Object? title = null,
    Object? description = freezed,
    Object? publishedAt = freezed,
    Object? durationS = freezed,
    Object? enclosureUrl = null,
    Object? enclosureType = freezed,
    Object? imageUrl = freezed,
    Object? episodeNo = freezed,
    Object? seasonNo = freezed,
    Object? downloaded = null,
    Object? positionS = null,
    Object? played = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            channelId: null == channelId
                ? _value.channelId
                : channelId // ignore: cast_nullable_to_non_nullable
                      as String,
            guid: null == guid
                ? _value.guid
                : guid // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            publishedAt: freezed == publishedAt
                ? _value.publishedAt
                : publishedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            durationS: freezed == durationS
                ? _value.durationS
                : durationS // ignore: cast_nullable_to_non_nullable
                      as int?,
            enclosureUrl: null == enclosureUrl
                ? _value.enclosureUrl
                : enclosureUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            enclosureType: freezed == enclosureType
                ? _value.enclosureType
                : enclosureType // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            episodeNo: freezed == episodeNo
                ? _value.episodeNo
                : episodeNo // ignore: cast_nullable_to_non_nullable
                      as int?,
            seasonNo: freezed == seasonNo
                ? _value.seasonNo
                : seasonNo // ignore: cast_nullable_to_non_nullable
                      as int?,
            downloaded: null == downloaded
                ? _value.downloaded
                : downloaded // ignore: cast_nullable_to_non_nullable
                      as bool,
            positionS: null == positionS
                ? _value.positionS
                : positionS // ignore: cast_nullable_to_non_nullable
                      as int,
            played: null == played
                ? _value.played
                : played // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PodcastEpisodeImplCopyWith<$Res>
    implements $PodcastEpisodeCopyWith<$Res> {
  factory _$$PodcastEpisodeImplCopyWith(
    _$PodcastEpisodeImpl value,
    $Res Function(_$PodcastEpisodeImpl) then,
  ) = __$$PodcastEpisodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String channelId,
    String guid,
    String title,
    String? description,
    DateTime? publishedAt,
    int? durationS,
    String enclosureUrl,
    String? enclosureType,
    String? imageUrl,
    int? episodeNo,
    int? seasonNo,
    bool downloaded,
    int positionS,
    bool played,
  });
}

/// @nodoc
class __$$PodcastEpisodeImplCopyWithImpl<$Res>
    extends _$PodcastEpisodeCopyWithImpl<$Res, _$PodcastEpisodeImpl>
    implements _$$PodcastEpisodeImplCopyWith<$Res> {
  __$$PodcastEpisodeImplCopyWithImpl(
    _$PodcastEpisodeImpl _value,
    $Res Function(_$PodcastEpisodeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PodcastEpisode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? channelId = null,
    Object? guid = null,
    Object? title = null,
    Object? description = freezed,
    Object? publishedAt = freezed,
    Object? durationS = freezed,
    Object? enclosureUrl = null,
    Object? enclosureType = freezed,
    Object? imageUrl = freezed,
    Object? episodeNo = freezed,
    Object? seasonNo = freezed,
    Object? downloaded = null,
    Object? positionS = null,
    Object? played = null,
  }) {
    return _then(
      _$PodcastEpisodeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        channelId: null == channelId
            ? _value.channelId
            : channelId // ignore: cast_nullable_to_non_nullable
                  as String,
        guid: null == guid
            ? _value.guid
            : guid // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        publishedAt: freezed == publishedAt
            ? _value.publishedAt
            : publishedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        durationS: freezed == durationS
            ? _value.durationS
            : durationS // ignore: cast_nullable_to_non_nullable
                  as int?,
        enclosureUrl: null == enclosureUrl
            ? _value.enclosureUrl
            : enclosureUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        enclosureType: freezed == enclosureType
            ? _value.enclosureType
            : enclosureType // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        episodeNo: freezed == episodeNo
            ? _value.episodeNo
            : episodeNo // ignore: cast_nullable_to_non_nullable
                  as int?,
        seasonNo: freezed == seasonNo
            ? _value.seasonNo
            : seasonNo // ignore: cast_nullable_to_non_nullable
                  as int?,
        downloaded: null == downloaded
            ? _value.downloaded
            : downloaded // ignore: cast_nullable_to_non_nullable
                  as bool,
        positionS: null == positionS
            ? _value.positionS
            : positionS // ignore: cast_nullable_to_non_nullable
                  as int,
        played: null == played
            ? _value.played
            : played // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PodcastEpisodeImpl implements _PodcastEpisode {
  const _$PodcastEpisodeImpl({
    required this.id,
    required this.channelId,
    required this.guid,
    required this.title,
    this.description,
    this.publishedAt,
    this.durationS,
    required this.enclosureUrl,
    this.enclosureType,
    this.imageUrl,
    this.episodeNo,
    this.seasonNo,
    required this.downloaded,
    required this.positionS,
    required this.played,
  });

  factory _$PodcastEpisodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$PodcastEpisodeImplFromJson(json);

  @override
  final String id;
  @override
  final String channelId;
  @override
  final String guid;
  @override
  final String title;
  @override
  final String? description;
  @override
  final DateTime? publishedAt;
  @override
  final int? durationS;
  @override
  final String enclosureUrl;
  @override
  final String? enclosureType;
  @override
  final String? imageUrl;
  @override
  final int? episodeNo;
  @override
  final int? seasonNo;
  @override
  final bool downloaded;
  @override
  final int positionS;
  @override
  final bool played;

  @override
  String toString() {
    return 'PodcastEpisode(id: $id, channelId: $channelId, guid: $guid, title: $title, description: $description, publishedAt: $publishedAt, durationS: $durationS, enclosureUrl: $enclosureUrl, enclosureType: $enclosureType, imageUrl: $imageUrl, episodeNo: $episodeNo, seasonNo: $seasonNo, downloaded: $downloaded, positionS: $positionS, played: $played)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PodcastEpisodeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.guid, guid) || other.guid == guid) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.durationS, durationS) ||
                other.durationS == durationS) &&
            (identical(other.enclosureUrl, enclosureUrl) ||
                other.enclosureUrl == enclosureUrl) &&
            (identical(other.enclosureType, enclosureType) ||
                other.enclosureType == enclosureType) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.episodeNo, episodeNo) ||
                other.episodeNo == episodeNo) &&
            (identical(other.seasonNo, seasonNo) ||
                other.seasonNo == seasonNo) &&
            (identical(other.downloaded, downloaded) ||
                other.downloaded == downloaded) &&
            (identical(other.positionS, positionS) ||
                other.positionS == positionS) &&
            (identical(other.played, played) || other.played == played));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    channelId,
    guid,
    title,
    description,
    publishedAt,
    durationS,
    enclosureUrl,
    enclosureType,
    imageUrl,
    episodeNo,
    seasonNo,
    downloaded,
    positionS,
    played,
  );

  /// Create a copy of PodcastEpisode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PodcastEpisodeImplCopyWith<_$PodcastEpisodeImpl> get copyWith =>
      __$$PodcastEpisodeImplCopyWithImpl<_$PodcastEpisodeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PodcastEpisodeImplToJson(this);
  }
}

abstract class _PodcastEpisode implements PodcastEpisode {
  const factory _PodcastEpisode({
    required final String id,
    required final String channelId,
    required final String guid,
    required final String title,
    final String? description,
    final DateTime? publishedAt,
    final int? durationS,
    required final String enclosureUrl,
    final String? enclosureType,
    final String? imageUrl,
    final int? episodeNo,
    final int? seasonNo,
    required final bool downloaded,
    required final int positionS,
    required final bool played,
  }) = _$PodcastEpisodeImpl;

  factory _PodcastEpisode.fromJson(Map<String, dynamic> json) =
      _$PodcastEpisodeImpl.fromJson;

  @override
  String get id;
  @override
  String get channelId;
  @override
  String get guid;
  @override
  String get title;
  @override
  String? get description;
  @override
  DateTime? get publishedAt;
  @override
  int? get durationS;
  @override
  String get enclosureUrl;
  @override
  String? get enclosureType;
  @override
  String? get imageUrl;
  @override
  int? get episodeNo;
  @override
  int? get seasonNo;
  @override
  bool get downloaded;
  @override
  int get positionS;
  @override
  bool get played;

  /// Create a copy of PodcastEpisode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PodcastEpisodeImplCopyWith<_$PodcastEpisodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
