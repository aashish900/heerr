import 'package:freezed_annotation/freezed_annotation.dart';

part 'lyrics.freezed.dart';
part 'lyrics.g.dart';

/// Response payload for `GET /rest/getLyrics.view?artist=…&title=…`.
///
/// Subsonic classic lyrics envelope:
/// ```
/// {
///   "lyrics": {
///     "artist": "Tame Impala",
///     "title":  "Let It Happen",
///     "value":  "It's always the same…"
///   }
/// }
/// ```
///
/// All three fields are optional on the wire — Navidrome sometimes returns
/// an empty `lyrics` element when nothing is known about the track, which
/// the lyrics provider maps to a "no lyrics" empty state at the UI layer.
@freezed
class Lyrics with _$Lyrics {
  const factory Lyrics({
    String? artist,
    String? title,
    String? value,
  }) = _Lyrics;

  factory Lyrics.fromJson(Map<String, dynamic> json) =>
      _$LyricsFromJson(json);
}
