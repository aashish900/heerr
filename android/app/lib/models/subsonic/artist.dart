import 'package:freezed_annotation/freezed_annotation.dart';

import 'album.dart';

part 'artist.freezed.dart';
part 'artist.g.dart';

/// A single artist entry from a Subsonic response.
///
/// `getArtists` returns these grouped by [ArtistIndex] under alphabetical
/// buckets. `getArtist(id)` returns one Artist with its `album` list
/// populated (a separate top-level call).
///
/// Field names mirror Subsonic's camelCase wire format — see
/// `android/app/lib/models/subsonic/song.dart` for the field-rename
/// rationale.
@freezed
class Artist with _$Artist {
  const factory Artist({
    required String id,
    required String name,
    @JsonKey(name: 'coverArt') String? coverArt,
    @JsonKey(name: 'albumCount') int? albumCount,
    @JsonKey(name: 'artistImageUrl') String? artistImageUrl,
    @Default(<Album>[]) List<Album> album,
  }) = _Artist;

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
}
