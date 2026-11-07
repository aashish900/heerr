// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mix.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MixVibe _$MixVibeFromJson(Map<String, dynamic> json) {
  return _MixVibe.fromJson(json);
}

/// @nodoc
mixin _$MixVibe {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;

  /// Serializes this MixVibe to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MixVibe
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MixVibeCopyWith<MixVibe> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MixVibeCopyWith<$Res> {
  factory $MixVibeCopyWith(MixVibe value, $Res Function(MixVibe) then) =
      _$MixVibeCopyWithImpl<$Res, MixVibe>;
  @useResult
  $Res call({String id, String title});
}

/// @nodoc
class _$MixVibeCopyWithImpl<$Res, $Val extends MixVibe>
    implements $MixVibeCopyWith<$Res> {
  _$MixVibeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MixVibe
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? title = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MixVibeImplCopyWith<$Res> implements $MixVibeCopyWith<$Res> {
  factory _$$MixVibeImplCopyWith(
    _$MixVibeImpl value,
    $Res Function(_$MixVibeImpl) then,
  ) = __$$MixVibeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title});
}

/// @nodoc
class __$$MixVibeImplCopyWithImpl<$Res>
    extends _$MixVibeCopyWithImpl<$Res, _$MixVibeImpl>
    implements _$$MixVibeImplCopyWith<$Res> {
  __$$MixVibeImplCopyWithImpl(
    _$MixVibeImpl _value,
    $Res Function(_$MixVibeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MixVibe
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? title = null}) {
    return _then(
      _$MixVibeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MixVibeImpl implements _MixVibe {
  const _$MixVibeImpl({required this.id, required this.title});

  factory _$MixVibeImpl.fromJson(Map<String, dynamic> json) =>
      _$$MixVibeImplFromJson(json);

  @override
  final String id;
  @override
  final String title;

  @override
  String toString() {
    return 'MixVibe(id: $id, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MixVibeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title);

  /// Create a copy of MixVibe
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MixVibeImplCopyWith<_$MixVibeImpl> get copyWith =>
      __$$MixVibeImplCopyWithImpl<_$MixVibeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MixVibeImplToJson(this);
  }
}

abstract class _MixVibe implements MixVibe {
  const factory _MixVibe({
    required final String id,
    required final String title,
  }) = _$MixVibeImpl;

  factory _MixVibe.fromJson(Map<String, dynamic> json) = _$MixVibeImpl.fromJson;

  @override
  String get id;
  @override
  String get title;

  /// Create a copy of MixVibe
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MixVibeImplCopyWith<_$MixVibeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MixResponse _$MixResponseFromJson(Map<String, dynamic> json) {
  return _MixResponse.fromJson(json);
}

/// @nodoc
mixin _$MixResponse {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  bool get personalized => throw _privateConstructorUsedError;
  List<RecommendedTrack> get results => throw _privateConstructorUsedError;

  /// Serializes this MixResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MixResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MixResponseCopyWith<MixResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MixResponseCopyWith<$Res> {
  factory $MixResponseCopyWith(
    MixResponse value,
    $Res Function(MixResponse) then,
  ) = _$MixResponseCopyWithImpl<$Res, MixResponse>;
  @useResult
  $Res call({
    String id,
    String title,
    bool personalized,
    List<RecommendedTrack> results,
  });
}

/// @nodoc
class _$MixResponseCopyWithImpl<$Res, $Val extends MixResponse>
    implements $MixResponseCopyWith<$Res> {
  _$MixResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MixResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? personalized = null,
    Object? results = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            personalized: null == personalized
                ? _value.personalized
                : personalized // ignore: cast_nullable_to_non_nullable
                      as bool,
            results: null == results
                ? _value.results
                : results // ignore: cast_nullable_to_non_nullable
                      as List<RecommendedTrack>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MixResponseImplCopyWith<$Res>
    implements $MixResponseCopyWith<$Res> {
  factory _$$MixResponseImplCopyWith(
    _$MixResponseImpl value,
    $Res Function(_$MixResponseImpl) then,
  ) = __$$MixResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    bool personalized,
    List<RecommendedTrack> results,
  });
}

/// @nodoc
class __$$MixResponseImplCopyWithImpl<$Res>
    extends _$MixResponseCopyWithImpl<$Res, _$MixResponseImpl>
    implements _$$MixResponseImplCopyWith<$Res> {
  __$$MixResponseImplCopyWithImpl(
    _$MixResponseImpl _value,
    $Res Function(_$MixResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MixResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? personalized = null,
    Object? results = null,
  }) {
    return _then(
      _$MixResponseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        personalized: null == personalized
            ? _value.personalized
            : personalized // ignore: cast_nullable_to_non_nullable
                  as bool,
        results: null == results
            ? _value._results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<RecommendedTrack>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MixResponseImpl implements _MixResponse {
  const _$MixResponseImpl({
    required this.id,
    required this.title,
    required this.personalized,
    final List<RecommendedTrack> results = const <RecommendedTrack>[],
  }) : _results = results;

  factory _$MixResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$MixResponseImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final bool personalized;
  final List<RecommendedTrack> _results;
  @override
  @JsonKey()
  List<RecommendedTrack> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  @override
  String toString() {
    return 'MixResponse(id: $id, title: $title, personalized: $personalized, results: $results)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MixResponseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.personalized, personalized) ||
                other.personalized == personalized) &&
            const DeepCollectionEquality().equals(other._results, _results));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    personalized,
    const DeepCollectionEquality().hash(_results),
  );

  /// Create a copy of MixResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MixResponseImplCopyWith<_$MixResponseImpl> get copyWith =>
      __$$MixResponseImplCopyWithImpl<_$MixResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MixResponseImplToJson(this);
  }
}

abstract class _MixResponse implements MixResponse {
  const factory _MixResponse({
    required final String id,
    required final String title,
    required final bool personalized,
    final List<RecommendedTrack> results,
  }) = _$MixResponseImpl;

  factory _MixResponse.fromJson(Map<String, dynamic> json) =
      _$MixResponseImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  bool get personalized;
  @override
  List<RecommendedTrack> get results;

  /// Create a copy of MixResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MixResponseImplCopyWith<_$MixResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
