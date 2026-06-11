import 'package:freezed_annotation/freezed_annotation.dart';

part 'song.freezed.dart';
part 'song.g.dart';

/// A single song / track from a Subsonic response.
///
/// Subsonic returns songs in three contexts: `getAlbum.song[]`,
/// `getPlaylist.entry[]`, and `search3.song[]`. Same wire shape in all three.
///
/// Field names mirror the Subsonic API ("camelCase on the wire") — `@JsonKey`
/// overrides exist for multi-word fields to bypass the project-global
/// `field_rename: snake` in `android/app/build.yaml`.
@freezed
class Song with _$Song {
  const factory Song({
    required String id,
    required String title,
    String? artist,
    @JsonKey(name: 'artistId') String? artistId,
    String? album,
    @JsonKey(name: 'albumId') String? albumId,
    @JsonKey(name: 'coverArt') String? coverArt,
    int? duration,
    int? track,
    int? year,
    String? genre,
    String? suffix,
    @JsonKey(name: 'contentType') String? contentType,
    @JsonKey(name: 'bitRate') int? bitRate,
    String? path,
    @JsonKey(name: 'isVideo') bool? isVideo,
    int? size,
  }) = _Song;

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}
