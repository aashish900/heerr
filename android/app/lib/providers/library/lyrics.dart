import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/lyrics.dart';
import '../../offline/lyrics_cache.dart';
import '../../offline/offline_paths.dart';
import '../../services/lyrics_service.dart';
import '../server_creds.dart';

part 'lyrics.g.dart';

/// Wraps lyrics resolution for the Now Playing screen (P2). The two-stage
/// strategy (Navidrome `getLyricsBySongId` → LRCLib fallback) lives in
/// [LyricsService]; this provider orchestrates state plus the #26 offline
/// cache: every successful resolve is persisted per-server, and the cache
/// is served when the network resolve fails or comes back empty (the
/// tailnet-unreachable case), so downloaded songs keep their lyrics.
///
/// Returns [Lyrics] (with timed `lines` when the source was synced), or
/// `null` when neither source nor the cache has them. Non-404 non-70
/// Navidrome [ApiError]s propagate only when the cache has nothing.
@riverpod
Future<Lyrics?> lyricsFor(
  LyricsForRef ref,
  String songId,
  String artist,
  String title,
) async {
  final LyricsService service =
      await ref.watch(lyricsServiceProvider.future);
  final ServerCreds creds = ref.watch(serverCredsProvider);
  final OfflinePaths paths = await ref.watch(offlinePathsProvider.future);
  final LyricsCache cache = LyricsCache(paths);
  final bool cacheable = songId.trim().isNotEmpty;

  try {
    final Lyrics? resolved =
        await service.resolve(songId: songId, artist: artist, title: title);
    if (!cacheable) return resolved;
    if (resolved != null) {
      await cache.write(creds, songId, resolved);
      return resolved;
    }
    // Both sources empty — LRCLib network failures also surface as null,
    // so fall back to anything cached before declaring "no lyrics".
    return cache.read(creds, songId);
  } on ApiError {
    if (cacheable) {
      final Lyrics? cached = await cache.read(creds, songId);
      if (cached != null) return cached;
    }
    rethrow;
  }
}
