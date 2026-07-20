// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'podcast_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PodcastChannel _$PodcastChannelFromJson(Map<String, dynamic> json) {
  return _PodcastChannel.fromJson(json);
}

/// @nodoc
mixin _$PodcastChannel {
  String? get id => throw _privateConstructorUsedError;
  String get feedUrl => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get author => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Serializes this PodcastChannel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PodcastChannel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PodcastChannelCopyWith<PodcastChannel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PodcastChannelCopyWith<$Res> {
  factory $PodcastChannelCopyWith(
    PodcastChannel value,
    $Res Function(PodcastChannel) then,
  ) = _$PodcastChannelCopyWithImpl<$Res, PodcastChannel>;
  @useResult
  $Res call({
    String? id,
    String feedUrl,
    String title,
    String? author,
    String? imageUrl,
    String? description,
  });
}

/// @nodoc
class _$PodcastChannelCopyWithImpl<$Res, $Val extends PodcastChannel>
    implements $PodcastChannelCopyWith<$Res> {
  _$PodcastChannelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PodcastChannel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? feedUrl = null,
    Object? title = null,
    Object? author = freezed,
    Object? imageUrl = freezed,
    Object? description = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String?,
            feedUrl: null == feedUrl
                ? _value.feedUrl
                : feedUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            author: freezed == author
                ? _value.author
                : author // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PodcastChannelImplCopyWith<$Res>
    implements $PodcastChannelCopyWith<$Res> {
  factory _$$PodcastChannelImplCopyWith(
    _$PodcastChannelImpl value,
    $Res Function(_$PodcastChannelImpl) then,
  ) = __$$PodcastChannelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? id,
    String feedUrl,
    String title,
    String? author,
    String? imageUrl,
    String? description,
  });
}

/// @nodoc
class __$$PodcastChannelImplCopyWithImpl<$Res>
    extends _$PodcastChannelCopyWithImpl<$Res, _$PodcastChannelImpl>
    implements _$$PodcastChannelImplCopyWith<$Res> {
  __$$PodcastChannelImplCopyWithImpl(
    _$PodcastChannelImpl _value,
    $Res Function(_$PodcastChannelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PodcastChannel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? feedUrl = null,
    Object? title = null,
    Object? author = freezed,
    Object? imageUrl = freezed,
    Object? description = freezed,
  }) {
    return _then(
      _$PodcastChannelImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String?,
        feedUrl: null == feedUrl
            ? _value.feedUrl
            : feedUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        author: freezed == author
            ? _value.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PodcastChannelImpl implements _PodcastChannel {
  const _$PodcastChannelImpl({
    this.id,
    required this.feedUrl,
    required this.title,
    this.author,
    this.imageUrl,
    this.description,
  });

  factory _$PodcastChannelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PodcastChannelImplFromJson(json);

  @override
  final String? id;
  @override
  final String feedUrl;
  @override
  final String title;
  @override
  final String? author;
  @override
  final String? imageUrl;
  @override
  final String? description;

  @override
  String toString() {
    return 'PodcastChannel(id: $id, feedUrl: $feedUrl, title: $title, author: $author, imageUrl: $imageUrl, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PodcastChannelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.feedUrl, feedUrl) || other.feedUrl == feedUrl) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    feedUrl,
    title,
    author,
    imageUrl,
    description,
  );

  /// Create a copy of PodcastChannel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PodcastChannelImplCopyWith<_$PodcastChannelImpl> get copyWith =>
      __$$PodcastChannelImplCopyWithImpl<_$PodcastChannelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PodcastChannelImplToJson(this);
  }
}

abstract class _PodcastChannel implements PodcastChannel {
  const factory _PodcastChannel({
    final String? id,
    required final String feedUrl,
    required final String title,
    final String? author,
    final String? imageUrl,
    final String? description,
  }) = _$PodcastChannelImpl;

  factory _PodcastChannel.fromJson(Map<String, dynamic> json) =
      _$PodcastChannelImpl.fromJson;

  @override
  String? get id;
  @override
  String get feedUrl;
  @override
  String get title;
  @override
  String? get author;
  @override
  String? get imageUrl;
  @override
  String? get description;

  /// Create a copy of PodcastChannel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PodcastChannelImplCopyWith<_$PodcastChannelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
