// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PodcastChannelImpl _$$PodcastChannelImplFromJson(Map<String, dynamic> json) =>
    _$PodcastChannelImpl(
      id: json['id'] as String?,
      feedUrl: json['feed_url'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$$PodcastChannelImplToJson(
  _$PodcastChannelImpl instance,
) => <String, dynamic>{
  if (instance.id case final value?) 'id': value,
  'feed_url': instance.feedUrl,
  'title': instance.title,
  if (instance.author case final value?) 'author': value,
  if (instance.imageUrl case final value?) 'image_url': value,
  if (instance.description case final value?) 'description': value,
};
