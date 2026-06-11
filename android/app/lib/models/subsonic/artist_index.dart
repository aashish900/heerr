import 'package:freezed_annotation/freezed_annotation.dart';

import 'artist.dart';

part 'artist_index.freezed.dart';
part 'artist_index.g.dart';

/// One alphabetical bucket from the `getArtists` response. Navidrome
/// groups by first letter after applying `ignoredArticles` (the/a/an/etc.)
/// — `name` is the bucket letter, `artist` the list of artists in it.
@freezed
class ArtistIndex with _$ArtistIndex {
  const factory ArtistIndex({
    required String name,
    @Default(<Artist>[]) List<Artist> artist,
  }) = _ArtistIndex;

  factory ArtistIndex.fromJson(Map<String, dynamic> json) =>
      _$ArtistIndexFromJson(json);
}
