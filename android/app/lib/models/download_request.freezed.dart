// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DownloadRequest _$DownloadRequestFromJson(Map<String, dynamic> json) {
  return _DownloadRequest.fromJson(json);
}

/// @nodoc
mixin _$DownloadRequest {
  String get spotifyUri => throw _privateConstructorUsedError;

  /// Serializes this DownloadRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DownloadRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DownloadRequestCopyWith<DownloadRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DownloadRequestCopyWith<$Res> {
  factory $DownloadRequestCopyWith(
    DownloadRequest value,
    $Res Function(DownloadRequest) then,
  ) = _$DownloadRequestCopyWithImpl<$Res, DownloadRequest>;
  @useResult
  $Res call({String spotifyUri});
}

/// @nodoc
class _$DownloadRequestCopyWithImpl<$Res, $Val extends DownloadRequest>
    implements $DownloadRequestCopyWith<$Res> {
  _$DownloadRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DownloadRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? spotifyUri = null}) {
    return _then(
      _value.copyWith(
            spotifyUri: null == spotifyUri
                ? _value.spotifyUri
                : spotifyUri // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DownloadRequestImplCopyWith<$Res>
    implements $DownloadRequestCopyWith<$Res> {
  factory _$$DownloadRequestImplCopyWith(
    _$DownloadRequestImpl value,
    $Res Function(_$DownloadRequestImpl) then,
  ) = __$$DownloadRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String spotifyUri});
}

/// @nodoc
class __$$DownloadRequestImplCopyWithImpl<$Res>
    extends _$DownloadRequestCopyWithImpl<$Res, _$DownloadRequestImpl>
    implements _$$DownloadRequestImplCopyWith<$Res> {
  __$$DownloadRequestImplCopyWithImpl(
    _$DownloadRequestImpl _value,
    $Res Function(_$DownloadRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DownloadRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? spotifyUri = null}) {
    return _then(
      _$DownloadRequestImpl(
        spotifyUri: null == spotifyUri
            ? _value.spotifyUri
            : spotifyUri // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DownloadRequestImpl implements _DownloadRequest {
  const _$DownloadRequestImpl({required this.spotifyUri});

  factory _$DownloadRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$DownloadRequestImplFromJson(json);

  @override
  final String spotifyUri;

  @override
  String toString() {
    return 'DownloadRequest(spotifyUri: $spotifyUri)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DownloadRequestImpl &&
            (identical(other.spotifyUri, spotifyUri) ||
                other.spotifyUri == spotifyUri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, spotifyUri);

  /// Create a copy of DownloadRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DownloadRequestImplCopyWith<_$DownloadRequestImpl> get copyWith =>
      __$$DownloadRequestImplCopyWithImpl<_$DownloadRequestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DownloadRequestImplToJson(this);
  }
}

abstract class _DownloadRequest implements DownloadRequest {
  const factory _DownloadRequest({required final String spotifyUri}) =
      _$DownloadRequestImpl;

  factory _DownloadRequest.fromJson(Map<String, dynamic> json) =
      _$DownloadRequestImpl.fromJson;

  @override
  String get spotifyUri;

  /// Create a copy of DownloadRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DownloadRequestImplCopyWith<_$DownloadRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
