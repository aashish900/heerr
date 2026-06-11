import 'package:freezed_annotation/freezed_annotation.dart';

import 'song.dart';

part 'playlist.freezed.dart';
part 'playlist.g.dart';

/// A playlist from a Subsonic response.
///
/// `getPlaylists` returns lightweight summaries (no `entry`).
/// `getPlaylist(id)` returns one playlist with its `entry` list populated
/// (each entry is a [Song]).
///
/// `created` / `changed` are ISO-8601 timestamp strings as Subsonic emits
/// them; kept as `String` rather than `DateTime` so a malformed value from
/// a non-Navidrome Subsonic server doesn't break deserialisation.
@freezed
class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String name,
    String? comment,
    String? owner,
    bool? public,
    @JsonKey(name: 'songCount') int? songCount,
    int? duration,
    String? created,
    String? changed,
    @JsonKey(name: 'coverArt') String? coverArt,
    @Default(<Song>[]) List<Song> entry,
  }) = _Playlist;

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);
}
