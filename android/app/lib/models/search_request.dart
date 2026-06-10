import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'search_request.freezed.dart';
part 'search_request.g.dart';

/// POST /api/v1/search request body.
/// Backend contract: `backend/app/schemas/search.py::SearchRequest`.
@freezed
class SearchRequest with _$SearchRequest {
  const factory SearchRequest({
    required String query,
    required ContentType type,
    @Default(20) int limit,
  }) = _SearchRequest;

  factory SearchRequest.fromJson(Map<String, dynamic> json) =>
      _$SearchRequestFromJson(json);
}
