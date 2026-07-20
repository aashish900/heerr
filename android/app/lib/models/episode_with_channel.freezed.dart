// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode_with_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EpisodeWithChannel _$EpisodeWithChannelFromJson(Map<String, dynamic> json) {
  return _EpisodeWithChannel.fromJson(json);
}

/// @nodoc
mixin _$EpisodeWithChannel {
  String get id => throw _privateConstructorUsedError;
  String get channelId => throw _privateConstructorUsedError;
  String get channelTitle => throw _privateConstructorUsedError;
  String? get channelImageUrl => throw _privateConstructorUsedError;
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

  /// Serializes this EpisodeWithChannel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EpisodeWithChannel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EpisodeWithChannelCopyWith<EpisodeWithChannel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EpisodeWithChannelCopyWith<$Res> {
  factory $EpisodeWithChannelCopyWith(
    EpisodeWithChannel value,
    $Res Function(EpisodeWithChannel) then,
  ) = _$EpisodeWithChannelCopyWithImpl<$Res, EpisodeWithChannel>;
  @useResult
  $Res call({
    String id,
    String channelId,
    String channelTitle,
    String? channelImageUrl,
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
class _$EpisodeWithChannelCopyWithImpl<$Res, $Val extends EpisodeWithChannel>
    implements $EpisodeWithChannelCopyWith<$Res> {
  _$EpisodeWithChannelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EpisodeWithChannel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? channelId = null,
    Object? channelTitle = null,
    Object? channelImageUrl = freezed,
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
            channelTitle: null == channelTitle
                ? _value.channelTitle
                : channelTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            channelImageUrl: freezed == channelImageUrl
                ? _value.channelImageUrl
                : channelImageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$EpisodeWithChannelImplCopyWith<$Res>
    implements $EpisodeWithChannelCopyWith<$Res> {
  factory _$$EpisodeWithChannelImplCopyWith(
    _$EpisodeWithChannelImpl value,
    $Res Function(_$EpisodeWithChannelImpl) then,
  ) = __$$EpisodeWithChannelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String channelId,
    String channelTitle,
    String? channelImageUrl,
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
class __$$EpisodeWithChannelImplCopyWithImpl<$Res>
    extends _$EpisodeWithChannelCopyWithImpl<$Res, _$EpisodeWithChannelImpl>
    implements _$$EpisodeWithChannelImplCopyWith<$Res> {
  __$$EpisodeWithChannelImplCopyWithImpl(
    _$EpisodeWithChannelImpl _value,
    $Res Function(_$EpisodeWithChannelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EpisodeWithChannel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? channelId = null,
    Object? channelTitle = null,
    Object? channelImageUrl = freezed,
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
      _$EpisodeWithChannelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        channelId: null == channelId
            ? _value.channelId
            : channelId // ignore: cast_nullable_to_non_nullable
                  as String,
        channelTitle: null == channelTitle
            ? _value.channelTitle
            : channelTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        channelImageUrl: freezed == channelImageUrl
            ? _value.channelImageUrl
            : channelImageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$EpisodeWithChannelImpl implements _EpisodeWithChannel {
  const _$EpisodeWithChannelImpl({
    required this.id,
    required this.channelId,
    required this.channelTitle,
    this.channelImageUrl,
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

  factory _$EpisodeWithChannelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EpisodeWithChannelImplFromJson(json);

  @override
  final String id;
  @override
  final String channelId;
  @override
  final String channelTitle;
  @override
  final String? channelImageUrl;
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
    return 'EpisodeWithChannel(id: $id, channelId: $channelId, channelTitle: $channelTitle, channelImageUrl: $channelImageUrl, guid: $guid, title: $title, description: $description, publishedAt: $publishedAt, durationS: $durationS, enclosureUrl: $enclosureUrl, enclosureType: $enclosureType, imageUrl: $imageUrl, episodeNo: $episodeNo, seasonNo: $seasonNo, downloaded: $downloaded, positionS: $positionS, played: $played)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EpisodeWithChannelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.channelTitle, channelTitle) ||
                other.channelTitle == channelTitle) &&
            (identical(other.channelImageUrl, channelImageUrl) ||
                other.channelImageUrl == channelImageUrl) &&
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
    channelTitle,
    channelImageUrl,
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

  /// Create a copy of EpisodeWithChannel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EpisodeWithChannelImplCopyWith<_$EpisodeWithChannelImpl> get copyWith =>
      __$$EpisodeWithChannelImplCopyWithImpl<_$EpisodeWithChannelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EpisodeWithChannelImplToJson(this);
  }
}

abstract class _EpisodeWithChannel implements EpisodeWithChannel {
  const factory _EpisodeWithChannel({
    required final String id,
    required final String channelId,
    required final String channelTitle,
    final String? channelImageUrl,
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
  }) = _$EpisodeWithChannelImpl;

  factory _EpisodeWithChannel.fromJson(Map<String, dynamic> json) =
      _$EpisodeWithChannelImpl.fromJson;

  @override
  String get id;
  @override
  String get channelId;
  @override
  String get channelTitle;
  @override
  String? get channelImageUrl;
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

  /// Create a copy of EpisodeWithChannel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EpisodeWithChannelImplCopyWith<_$EpisodeWithChannelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
