import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/lyrics.dart';
import '../../services/lyrics_service.dart';

part 'lyrics.g.dart';

/// Wraps lyrics resolution for the Now Playing screen (P2). The two-stage
/// strategy (Navidrome `getLyricsBySongId` → LRCLib fallback) lives in
/// [LyricsService]; this provider is now pure state orchestration.
///
/// Returns [Lyrics] with `value` set to plain text when lyrics are found, or
/// `null` when neither source has them. Non-404 non-70 Navidrome [ApiError]s
/// propagate so the UI shows the error pane.
@riverpod
Future<Lyrics?> lyricsFor(
  LyricsForRef ref,
  String songId,
  String artist,
  String title,
) async {
  final LyricsService service =
      await ref.watch(lyricsServiceProvider.future);
  return service.resolve(songId: songId, artist: artist, title: title);
}
