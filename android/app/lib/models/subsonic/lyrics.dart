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

    /// #26: timed lines when the source is synced (Navidrome structured
    /// lyrics with `start` offsets, or LRCLib `syncedLyrics` LRC). Null or
    /// empty → plain-text rendering of [value]. Serialized so the offline
    /// lyrics cache round-trips the sync data.
    List<LyricsLine>? lines,
  }) = _Lyrics;

  factory Lyrics.fromJson(Map<String, dynamic> json) =>
      _$LyricsFromJson(json);
}

/// One timed lyrics line: [start] is the offset from track start in
/// milliseconds.
@freezed
class LyricsLine with _$LyricsLine {
  const factory LyricsLine({
    required int start,
    required String value,
  }) = _LyricsLine;

  factory LyricsLine.fromJson(Map<String, dynamic> json) =>
      _$LyricsLineFromJson(json);
}

/// #26: parse an LRC document (LRCLib `syncedLyrics`) into timed lines.
///
/// Handles `[mm:ss.xx]` and `[mm:ss.xxx]` timestamps, multiple timestamps
/// per line (the text repeats at each), and skips metadata tags
/// (`[ar:…]`, `[ti:…]`, …) and untimed lines. Output is sorted by start.
/// Returns an empty list when nothing parses — callers treat that as
/// "not synced".
List<LyricsLine> parseLrc(String lrc) {
  final RegExp stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:\.(\d{1,3}))?\]');
  final List<LyricsLine> out = <LyricsLine>[];
  for (final String raw in lrc.split('\n')) {
    final Iterable<RegExpMatch> stamps = stamp.allMatches(raw);
    if (stamps.isEmpty) continue;
    final String text = raw.substring(stamps.last.end).trim();
    if (text.isEmpty) continue;
    for (final RegExpMatch m in stamps) {
      final int min = int.parse(m.group(1)!);
      final int sec = int.parse(m.group(2)!);
      final String frac = m.group(3) ?? '0';
      // ".5" = 500ms, ".50" = 500ms, ".500" = 500ms.
      final int ms = (int.parse(frac) * (1000 / _pow10(frac.length))).round();
      out.add(LyricsLine(
        start: (min * 60 + sec) * 1000 + ms,
        value: text,
      ));
    }
  }
  out.sort((LyricsLine a, LyricsLine b) => a.start.compareTo(b.start));
  return out;
}

int _pow10(int n) => switch (n) { 1 => 10, 2 => 100, _ => 1000 };
