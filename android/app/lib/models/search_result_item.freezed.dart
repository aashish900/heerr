// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SearchResultItem _$SearchResultItemFromJson(Map<String, dynamic> json) {
  return _SearchResultItem.fromJson(json);
}

/// @nodoc
mixin _$SearchResultItem {
  String get spotifyUri => throw _privateConstructorUsedError;
  String get spotifyUrl => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get artist => throw _privateConstructorUsedError;
  String? get album => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  String? get coverUrl => throw _privateConstructorUsedError;
  bool get alreadyDownloaded => throw _privateConstructorUsedError;
  String? get activeJobId => throw _privateConstructorUsedError;

  /// Serializes this SearchResultItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchResultItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultItemCopyWith<SearchResultItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultItemCopyWith<$Res> {
  factory $SearchResultItemCopyWith(
    SearchResultItem value,
    $Res Function(SearchResultItem) then,
  ) = _$SearchResultItemCopyWithImpl<$Res, SearchResultItem>;
  @useResult
  $Res call({
    String spotifyUri,
    String spotifyUrl,
    String title,
    String artist,
    String? album,
    int? durationMs,
    String? coverUrl,
    bool alreadyDownloaded,
    String? activeJobId,
  });
}

/// @nodoc
class _$SearchResultItemCopyWithImpl<$Res, $Val extends SearchResultItem>
    implements $SearchResultItemCopyWith<$Res> {
  _$SearchResultItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResultItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spotifyUri = null,
    Object? spotifyUrl = null,
    Object? title = null,
    Object? artist = null,
    Object? album = freezed,
    Object? durationMs = freezed,
    Object? coverUrl = freezed,
    Object? alreadyDownloaded = null,
    Object? activeJobId = freezed,
  }) {
    return _then(
      _value.copyWith(
            spotifyUri: null == spotifyUri
                ? _value.spotifyUri
                : spotifyUri // ignore: cast_nullable_to_non_nullable
                      as String,
            spotifyUrl: null == spotifyUrl
                ? _value.spotifyUrl
                : spotifyUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            artist: null == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String,
            album: freezed == album
                ? _value.album
                : album // ignore: cast_nullable_to_non_nullable
                      as String?,
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            coverUrl: freezed == coverUrl
                ? _value.coverUrl
                : coverUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            alreadyDownloaded: null == alreadyDownloaded
                ? _value.alreadyDownloaded
                : alreadyDownloaded // ignore: cast_nullable_to_non_nullable
                      as bool,
            activeJobId: freezed == activeJobId
                ? _value.activeJobId
                : activeJobId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchResultItemImplCopyWith<$Res>
    implements $SearchResultItemCopyWith<$Res> {
  factory _$$SearchResultItemImplCopyWith(
    _$SearchResultItemImpl value,
    $Res Function(_$SearchResultItemImpl) then,
  ) = __$$SearchResultItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String spotifyUri,
    String spotifyUrl,
    String title,
    String artist,
    String? album,
    int? durationMs,
    String? coverUrl,
    bool alreadyDownloaded,
    String? activeJobId,
  });
}

/// @nodoc
class __$$SearchResultItemImplCopyWithImpl<$Res>
    extends _$SearchResultItemCopyWithImpl<$Res, _$SearchResultItemImpl>
    implements _$$SearchResultItemImplCopyWith<$Res> {
  __$$SearchResultItemImplCopyWithImpl(
    _$SearchResultItemImpl _value,
    $Res Function(_$SearchResultItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResultItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? spotifyUri = null,
    Object? spotifyUrl = null,
    Object? title = null,
    Object? artist = null,
    Object? album = freezed,
    Object? durationMs = freezed,
    Object? coverUrl = freezed,
    Object? alreadyDownloaded = null,
    Object? activeJobId = freezed,
  }) {
    return _then(
      _$SearchResultItemImpl(
        spotifyUri: null == spotifyUri
            ? _value.spotifyUri
            : spotifyUri // ignore: cast_nullable_to_non_nullable
                  as String,
        spotifyUrl: null == spotifyUrl
            ? _value.spotifyUrl
            : spotifyUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: null == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String,
        album: freezed == album
            ? _value.album
            : album // ignore: cast_nullable_to_non_nullable
                  as String?,
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        coverUrl: freezed == coverUrl
            ? _value.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        alreadyDownloaded: null == alreadyDownloaded
            ? _value.alreadyDownloaded
            : alreadyDownloaded // ignore: cast_nullable_to_non_nullable
                  as bool,
        activeJobId: freezed == activeJobId
            ? _value.activeJobId
            : activeJobId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SearchResultItemImpl implements _SearchResultItem {
  const _$SearchResultItemImpl({
    required this.spotifyUri,
    required this.spotifyUrl,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.coverUrl,
    required this.alreadyDownloaded,
    this.activeJobId,
  });

  factory _$SearchResultItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchResultItemImplFromJson(json);

  @override
  final String spotifyUri;
  @override
  final String spotifyUrl;
  @override
  final String title;
  @override
  final String artist;
  @override
  final String? album;
  @override
  final int? durationMs;
  @override
  final String? coverUrl;
  @override
  final bool alreadyDownloaded;
  @override
  final String? activeJobId;

  @override
  String toString() {
    return 'SearchResultItem(spotifyUri: $spotifyUri, spotifyUrl: $spotifyUrl, title: $title, artist: $artist, album: $album, durationMs: $durationMs, coverUrl: $coverUrl, alreadyDownloaded: $alreadyDownloaded, activeJobId: $activeJobId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultItemImpl &&
            (identical(other.spotifyUri, spotifyUri) ||
                other.spotifyUri == spotifyUri) &&
            (identical(other.spotifyUrl, spotifyUrl) ||
                other.spotifyUrl == spotifyUrl) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.alreadyDownloaded, alreadyDownloaded) ||
                other.alreadyDownloaded == alreadyDownloaded) &&
            (identical(other.activeJobId, activeJobId) ||
                other.activeJobId == activeJobId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    spotifyUri,
    spotifyUrl,
    title,
    artist,
    album,
    durationMs,
    coverUrl,
    alreadyDownloaded,
    activeJobId,
  );

  /// Create a copy of SearchResultItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultItemImplCopyWith<_$SearchResultItemImpl> get copyWith =>
      __$$SearchResultItemImplCopyWithImpl<_$SearchResultItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchResultItemImplToJson(this);
  }
}

abstract class _SearchResultItem implements SearchResultItem {
  const factory _SearchResultItem({
    required final String spotifyUri,
    required final String spotifyUrl,
    required final String title,
    required final String artist,
    final String? album,
    final int? durationMs,
    final String? coverUrl,
    required final bool alreadyDownloaded,
    final String? activeJobId,
  }) = _$SearchResultItemImpl;

  factory _SearchResultItem.fromJson(Map<String, dynamic> json) =
      _$SearchResultItemImpl.fromJson;

  @override
  String get spotifyUri;
  @override
  String get spotifyUrl;
  @override
  String get title;
  @override
  String get artist;
  @override
  String? get album;
  @override
  int? get durationMs;
  @override
  String? get coverUrl;
  @override
  bool get alreadyDownloaded;
  @override
  String? get activeJobId;

  /// Create a copy of SearchResultItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultItemImplCopyWith<_$SearchResultItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
