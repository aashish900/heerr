import 'package:freezed_annotation/freezed_annotation.dart';

import 'search_result_item.dart';

part 'search_response.freezed.dart';
part 'search_response.g.dart';

/// POST /api/v1/search response body.
/// Backend contract: `backend/app/schemas/search.py::SearchResponse`.
@freezed
class SearchResponse with _$SearchResponse {
  const factory SearchResponse({required List<SearchResultItem> results}) =
      _SearchResponse;

  factory SearchResponse.fromJson(Map<String, dynamic> json) =>
      _$SearchResponseFromJson(json);
}
