import 'package:freezed_annotation/freezed_annotation.dart';

import 'album.dart';
import 'artist.dart';
import 'song.dart';

part 'search_result3.freezed.dart';
part 'search_result3.g.dart';

/// The `searchResult3` payload of the Subsonic `search3` endpoint. Empty
/// sections are omitted by Subsonic; the `@Default` keeps callers from
/// having to null-check.
@freezed
class SearchResult3 with _$SearchResult3 {
  const factory SearchResult3({
    @Default(<Artist>[]) List<Artist> artist,
    @Default(<Album>[]) List<Album> album,
    @Default(<Song>[]) List<Song> song,
  }) = _SearchResult3;

  factory SearchResult3.fromJson(Map<String, dynamic> json) =>
      _$SearchResult3FromJson(json);
}
