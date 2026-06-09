// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchResponseImpl _$$SearchResponseImplFromJson(Map<String, dynamic> json) =>
    _$SearchResponseImpl(
      results: (json['results'] as List<dynamic>)
          .map((e) => SearchResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$SearchResponseImplToJson(
  _$SearchResponseImpl instance,
) => <String, dynamic>{
  'results': instance.results.map((e) => e.toJson()).toList(),
};
