import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_result_item.freezed.dart';
part 'search_result_item.g.dart';

/// One row in the `/search` response.
/// Backend contract: `backend/app/schemas/search.py::SearchResultItem`.
@freezed
class SearchResultItem with _$SearchResultItem {
  const factory SearchResultItem({
    required String sourceUrl,
    required String sourceType,
    required String title,
    required String artist,
    String? album,
    int? durationMs,
    String? coverUrl,
    required bool alreadyDownloaded,
    String? activeJobId,
  }) = _SearchResultItem;

  factory SearchResultItem.fromJson(Map<String, dynamic> json) =>
      _$SearchResultItemFromJson(json);
}
