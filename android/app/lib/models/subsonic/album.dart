import 'package:freezed_annotation/freezed_annotation.dart';

import 'song.dart';

part 'album.freezed.dart';
part 'album.g.dart';

/// A single album from a Subsonic response.
///
/// `getArtist(id)` returns albums without a `song` list (album list only).
/// `getAlbum(id)` returns one album with its `song` list populated.
/// `search3.album[]` returns albums without songs.
@freezed
class Album with _$Album {
  const factory Album({
    required String id,
    required String name,
    String? artist,
    @JsonKey(name: 'artistId') String? artistId,
    @JsonKey(name: 'coverArt') String? coverArt,
    @JsonKey(name: 'songCount') int? songCount,
    int? duration,
    int? year,
    String? genre,
    String? created,
    @Default(<Song>[]) List<Song> song,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}
