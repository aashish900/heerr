// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'offline_manifest.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OfflineManifest _$OfflineManifestFromJson(Map<String, dynamic> json) {
  return _OfflineManifest.fromJson(json);
}

/// @nodoc
mixin _$OfflineManifest {
  Set<String> get markedAlbums => throw _privateConstructorUsedError;
  Set<String> get markedPlaylists =>
      throw _privateConstructorUsedError; // L7: marker for "everything under this artist". On each sync tick
  // `OfflineSync` expands the set via `libraryArtistProvider` →
  // `Artist.album[].id`, so the union with `markedAlbums` is the real
  // download target. Stored separately (rather than fanning out at
  // mark time) so a new album from a marked artist is picked up
  // automatically on the next sync — no manual re-mark.
  Set<String> get markedArtists => throw _privateConstructorUsedError;
  Map<String, OfflineSongEntry> get songs => throw _privateConstructorUsedError;
  int? get estimatedTotalBytes => throw _privateConstructorUsedError;
  DateTime? get estimatedAt => throw _privateConstructorUsedError;

  /// Serializes this OfflineManifest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OfflineManifest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OfflineManifestCopyWith<OfflineManifest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OfflineManifestCopyWith<$Res> {
  factory $OfflineManifestCopyWith(
    OfflineManifest value,
    $Res Function(OfflineManifest) then,
  ) = _$OfflineManifestCopyWithImpl<$Res, OfflineManifest>;
  @useResult
  $Res call({
    Set<String> markedAlbums,
    Set<String> markedPlaylists,
    Set<String> markedArtists,
    Map<String, OfflineSongEntry> songs,
    int? estimatedTotalBytes,
    DateTime? estimatedAt,
  });
}

/// @nodoc
class _$OfflineManifestCopyWithImpl<$Res, $Val extends OfflineManifest>
    implements $OfflineManifestCopyWith<$Res> {
  _$OfflineManifestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OfflineManifest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? markedAlbums = null,
    Object? markedPlaylists = null,
    Object? markedArtists = null,
    Object? songs = null,
    Object? estimatedTotalBytes = freezed,
    Object? estimatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            markedAlbums: null == markedAlbums
                ? _value.markedAlbums
                : markedAlbums // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
            markedPlaylists: null == markedPlaylists
                ? _value.markedPlaylists
                : markedPlaylists // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
            markedArtists: null == markedArtists
                ? _value.markedArtists
                : markedArtists // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
            songs: null == songs
                ? _value.songs
                : songs // ignore: cast_nullable_to_non_nullable
                      as Map<String, OfflineSongEntry>,
            estimatedTotalBytes: freezed == estimatedTotalBytes
                ? _value.estimatedTotalBytes
                : estimatedTotalBytes // ignore: cast_nullable_to_non_nullable
                      as int?,
            estimatedAt: freezed == estimatedAt
                ? _value.estimatedAt
                : estimatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OfflineManifestImplCopyWith<$Res>
    implements $OfflineManifestCopyWith<$Res> {
  factory _$$OfflineManifestImplCopyWith(
    _$OfflineManifestImpl value,
    $Res Function(_$OfflineManifestImpl) then,
  ) = __$$OfflineManifestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Set<String> markedAlbums,
    Set<String> markedPlaylists,
    Set<String> markedArtists,
    Map<String, OfflineSongEntry> songs,
    int? estimatedTotalBytes,
    DateTime? estimatedAt,
  });
}

/// @nodoc
class __$$OfflineManifestImplCopyWithImpl<$Res>
    extends _$OfflineManifestCopyWithImpl<$Res, _$OfflineManifestImpl>
    implements _$$OfflineManifestImplCopyWith<$Res> {
  __$$OfflineManifestImplCopyWithImpl(
    _$OfflineManifestImpl _value,
    $Res Function(_$OfflineManifestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OfflineManifest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? markedAlbums = null,
    Object? markedPlaylists = null,
    Object? markedArtists = null,
    Object? songs = null,
    Object? estimatedTotalBytes = freezed,
    Object? estimatedAt = freezed,
  }) {
    return _then(
      _$OfflineManifestImpl(
        markedAlbums: null == markedAlbums
            ? _value._markedAlbums
            : markedAlbums // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        markedPlaylists: null == markedPlaylists
            ? _value._markedPlaylists
            : markedPlaylists // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        markedArtists: null == markedArtists
            ? _value._markedArtists
            : markedArtists // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        songs: null == songs
            ? _value._songs
            : songs // ignore: cast_nullable_to_non_nullable
                  as Map<String, OfflineSongEntry>,
        estimatedTotalBytes: freezed == estimatedTotalBytes
            ? _value.estimatedTotalBytes
            : estimatedTotalBytes // ignore: cast_nullable_to_non_nullable
                  as int?,
        estimatedAt: freezed == estimatedAt
            ? _value.estimatedAt
            : estimatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OfflineManifestImpl
    with DiagnosticableTreeMixin
    implements _OfflineManifest {
  const _$OfflineManifestImpl({
    final Set<String> markedAlbums = const <String>{},
    final Set<String> markedPlaylists = const <String>{},
    final Set<String> markedArtists = const <String>{},
    final Map<String, OfflineSongEntry> songs =
        const <String, OfflineSongEntry>{},
    this.estimatedTotalBytes,
    this.estimatedAt,
  }) : _markedAlbums = markedAlbums,
       _markedPlaylists = markedPlaylists,
       _markedArtists = markedArtists,
       _songs = songs;

  factory _$OfflineManifestImpl.fromJson(Map<String, dynamic> json) =>
      _$$OfflineManifestImplFromJson(json);

  final Set<String> _markedAlbums;
  @override
  @JsonKey()
  Set<String> get markedAlbums {
    if (_markedAlbums is EqualUnmodifiableSetView) return _markedAlbums;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_markedAlbums);
  }

  final Set<String> _markedPlaylists;
  @override
  @JsonKey()
  Set<String> get markedPlaylists {
    if (_markedPlaylists is EqualUnmodifiableSetView) return _markedPlaylists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_markedPlaylists);
  }

  // L7: marker for "everything under this artist". On each sync tick
  // `OfflineSync` expands the set via `libraryArtistProvider` →
  // `Artist.album[].id`, so the union with `markedAlbums` is the real
  // download target. Stored separately (rather than fanning out at
  // mark time) so a new album from a marked artist is picked up
  // automatically on the next sync — no manual re-mark.
  final Set<String> _markedArtists;
  // L7: marker for "everything under this artist". On each sync tick
  // `OfflineSync` expands the set via `libraryArtistProvider` →
  // `Artist.album[].id`, so the union with `markedAlbums` is the real
  // download target. Stored separately (rather than fanning out at
  // mark time) so a new album from a marked artist is picked up
  // automatically on the next sync — no manual re-mark.
  @override
  @JsonKey()
  Set<String> get markedArtists {
    if (_markedArtists is EqualUnmodifiableSetView) return _markedArtists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_markedArtists);
  }

  final Map<String, OfflineSongEntry> _songs;
  @override
  @JsonKey()
  Map<String, OfflineSongEntry> get songs {
    if (_songs is EqualUnmodifiableMapView) return _songs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_songs);
  }

  @override
  final int? estimatedTotalBytes;
  @override
  final DateTime? estimatedAt;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'OfflineManifest(markedAlbums: $markedAlbums, markedPlaylists: $markedPlaylists, markedArtists: $markedArtists, songs: $songs, estimatedTotalBytes: $estimatedTotalBytes, estimatedAt: $estimatedAt)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'OfflineManifest'))
      ..add(DiagnosticsProperty('markedAlbums', markedAlbums))
      ..add(DiagnosticsProperty('markedPlaylists', markedPlaylists))
      ..add(DiagnosticsProperty('markedArtists', markedArtists))
      ..add(DiagnosticsProperty('songs', songs))
      ..add(DiagnosticsProperty('estimatedTotalBytes', estimatedTotalBytes))
      ..add(DiagnosticsProperty('estimatedAt', estimatedAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OfflineManifestImpl &&
            const DeepCollectionEquality().equals(
              other._markedAlbums,
              _markedAlbums,
            ) &&
            const DeepCollectionEquality().equals(
              other._markedPlaylists,
              _markedPlaylists,
            ) &&
            const DeepCollectionEquality().equals(
              other._markedArtists,
              _markedArtists,
            ) &&
            const DeepCollectionEquality().equals(other._songs, _songs) &&
            (identical(other.estimatedTotalBytes, estimatedTotalBytes) ||
                other.estimatedTotalBytes == estimatedTotalBytes) &&
            (identical(other.estimatedAt, estimatedAt) ||
                other.estimatedAt == estimatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_markedAlbums),
    const DeepCollectionEquality().hash(_markedPlaylists),
    const DeepCollectionEquality().hash(_markedArtists),
    const DeepCollectionEquality().hash(_songs),
    estimatedTotalBytes,
    estimatedAt,
  );

  /// Create a copy of OfflineManifest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OfflineManifestImplCopyWith<_$OfflineManifestImpl> get copyWith =>
      __$$OfflineManifestImplCopyWithImpl<_$OfflineManifestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OfflineManifestImplToJson(this);
  }
}

abstract class _OfflineManifest implements OfflineManifest {
  const factory _OfflineManifest({
    final Set<String> markedAlbums,
    final Set<String> markedPlaylists,
    final Set<String> markedArtists,
    final Map<String, OfflineSongEntry> songs,
    final int? estimatedTotalBytes,
    final DateTime? estimatedAt,
  }) = _$OfflineManifestImpl;

  factory _OfflineManifest.fromJson(Map<String, dynamic> json) =
      _$OfflineManifestImpl.fromJson;

  @override
  Set<String> get markedAlbums;
  @override
  Set<String> get markedPlaylists; // L7: marker for "everything under this artist". On each sync tick
  // `OfflineSync` expands the set via `libraryArtistProvider` →
  // `Artist.album[].id`, so the union with `markedAlbums` is the real
  // download target. Stored separately (rather than fanning out at
  // mark time) so a new album from a marked artist is picked up
  // automatically on the next sync — no manual re-mark.
  @override
  Set<String> get markedArtists;
  @override
  Map<String, OfflineSongEntry> get songs;
  @override
  int? get estimatedTotalBytes;
  @override
  DateTime? get estimatedAt;

  /// Create a copy of OfflineManifest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OfflineManifestImplCopyWith<_$OfflineManifestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OfflineSongEntry _$OfflineSongEntryFromJson(Map<String, dynamic> json) {
  return _OfflineSongEntry.fromJson(json);
}

/// @nodoc
mixin _$OfflineSongEntry {
  OfflineSongState get state => throw _privateConstructorUsedError;
  String? get localPath => throw _privateConstructorUsedError;
  int? get size => throw _privateConstructorUsedError;
  String? get suffix => throw _privateConstructorUsedError;
  DateTime? get downloadedAt => throw _privateConstructorUsedError;
  String? get lastError => throw _privateConstructorUsedError;

  /// Serializes this OfflineSongEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OfflineSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OfflineSongEntryCopyWith<OfflineSongEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OfflineSongEntryCopyWith<$Res> {
  factory $OfflineSongEntryCopyWith(
    OfflineSongEntry value,
    $Res Function(OfflineSongEntry) then,
  ) = _$OfflineSongEntryCopyWithImpl<$Res, OfflineSongEntry>;
  @useResult
  $Res call({
    OfflineSongState state,
    String? localPath,
    int? size,
    String? suffix,
    DateTime? downloadedAt,
    String? lastError,
  });
}

/// @nodoc
class _$OfflineSongEntryCopyWithImpl<$Res, $Val extends OfflineSongEntry>
    implements $OfflineSongEntryCopyWith<$Res> {
  _$OfflineSongEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OfflineSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? localPath = freezed,
    Object? size = freezed,
    Object? suffix = freezed,
    Object? downloadedAt = freezed,
    Object? lastError = freezed,
  }) {
    return _then(
      _value.copyWith(
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as OfflineSongState,
            localPath: freezed == localPath
                ? _value.localPath
                : localPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            size: freezed == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int?,
            suffix: freezed == suffix
                ? _value.suffix
                : suffix // ignore: cast_nullable_to_non_nullable
                      as String?,
            downloadedAt: freezed == downloadedAt
                ? _value.downloadedAt
                : downloadedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastError: freezed == lastError
                ? _value.lastError
                : lastError // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OfflineSongEntryImplCopyWith<$Res>
    implements $OfflineSongEntryCopyWith<$Res> {
  factory _$$OfflineSongEntryImplCopyWith(
    _$OfflineSongEntryImpl value,
    $Res Function(_$OfflineSongEntryImpl) then,
  ) = __$$OfflineSongEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    OfflineSongState state,
    String? localPath,
    int? size,
    String? suffix,
    DateTime? downloadedAt,
    String? lastError,
  });
}

/// @nodoc
class __$$OfflineSongEntryImplCopyWithImpl<$Res>
    extends _$OfflineSongEntryCopyWithImpl<$Res, _$OfflineSongEntryImpl>
    implements _$$OfflineSongEntryImplCopyWith<$Res> {
  __$$OfflineSongEntryImplCopyWithImpl(
    _$OfflineSongEntryImpl _value,
    $Res Function(_$OfflineSongEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OfflineSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? localPath = freezed,
    Object? size = freezed,
    Object? suffix = freezed,
    Object? downloadedAt = freezed,
    Object? lastError = freezed,
  }) {
    return _then(
      _$OfflineSongEntryImpl(
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as OfflineSongState,
        localPath: freezed == localPath
            ? _value.localPath
            : localPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        size: freezed == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int?,
        suffix: freezed == suffix
            ? _value.suffix
            : suffix // ignore: cast_nullable_to_non_nullable
                  as String?,
        downloadedAt: freezed == downloadedAt
            ? _value.downloadedAt
            : downloadedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastError: freezed == lastError
            ? _value.lastError
            : lastError // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OfflineSongEntryImpl
    with DiagnosticableTreeMixin
    implements _OfflineSongEntry {
  const _$OfflineSongEntryImpl({
    required this.state,
    this.localPath,
    this.size,
    this.suffix,
    this.downloadedAt,
    this.lastError,
  });

  factory _$OfflineSongEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$OfflineSongEntryImplFromJson(json);

  @override
  final OfflineSongState state;
  @override
  final String? localPath;
  @override
  final int? size;
  @override
  final String? suffix;
  @override
  final DateTime? downloadedAt;
  @override
  final String? lastError;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'OfflineSongEntry(state: $state, localPath: $localPath, size: $size, suffix: $suffix, downloadedAt: $downloadedAt, lastError: $lastError)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'OfflineSongEntry'))
      ..add(DiagnosticsProperty('state', state))
      ..add(DiagnosticsProperty('localPath', localPath))
      ..add(DiagnosticsProperty('size', size))
      ..add(DiagnosticsProperty('suffix', suffix))
      ..add(DiagnosticsProperty('downloadedAt', downloadedAt))
      ..add(DiagnosticsProperty('lastError', lastError));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OfflineSongEntryImpl &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.localPath, localPath) ||
                other.localPath == localPath) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.suffix, suffix) || other.suffix == suffix) &&
            (identical(other.downloadedAt, downloadedAt) ||
                other.downloadedAt == downloadedAt) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    state,
    localPath,
    size,
    suffix,
    downloadedAt,
    lastError,
  );

  /// Create a copy of OfflineSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OfflineSongEntryImplCopyWith<_$OfflineSongEntryImpl> get copyWith =>
      __$$OfflineSongEntryImplCopyWithImpl<_$OfflineSongEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OfflineSongEntryImplToJson(this);
  }
}

abstract class _OfflineSongEntry implements OfflineSongEntry {
  const factory _OfflineSongEntry({
    required final OfflineSongState state,
    final String? localPath,
    final int? size,
    final String? suffix,
    final DateTime? downloadedAt,
    final String? lastError,
  }) = _$OfflineSongEntryImpl;

  factory _OfflineSongEntry.fromJson(Map<String, dynamic> json) =
      _$OfflineSongEntryImpl.fromJson;

  @override
  OfflineSongState get state;
  @override
  String? get localPath;
  @override
  int? get size;
  @override
  String? get suffix;
  @override
  DateTime? get downloadedAt;
  @override
  String? get lastError;

  /// Create a copy of OfflineSongEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OfflineSongEntryImplCopyWith<_$OfflineSongEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
