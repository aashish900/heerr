import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/api_error.dart';
import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/lyrics.dart';

part 'lyrics.g.dart';

/// LRCLib public API base URL. No auth, no key. Free for all clients.
const String _kLrcLibBase = 'https://lrclib.net';

/// Wraps lyrics resolution for the Now Playing screen. P2.
///
/// Two-stage strategy:
///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
///      Skipped when [songId] is empty.
///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
///      directly. Skipped when [artist] or [title] is empty.
///
/// Returns [Lyrics] with `value` set to plain text when lyrics are found,
/// or `null` when neither source has them. All other [ApiError]s from
/// Navidrome rethrow so the UI shows the error pane.
@riverpod
Future<Lyrics?> lyricsFor(
  LyricsForRef ref,
  String songId,
  String artist,
  String title,
) async {
  // --- Stage 1: Navidrome getLyricsBySongId ---
  if (songId.trim().isNotEmpty) {
    try {
      final Dio subDio = await ref.watch(subsonicDioClientProvider.future);
      final Lyrics? fromNavidrome = await subsonicCall<Lyrics?>(
        () => subDio.get<dynamic>(
          SubsonicEndpoints.getLyricsBySongId,
          queryParameters: <String, dynamic>{'id': songId.trim()},
        ),
        (Map<String, dynamic> env) {
          final dynamic list = env['lyricsList'];
          if (list is! Map<String, dynamic>) return null;
          final dynamic structured = list['structuredLyrics'];
          if (structured is! List || structured.isEmpty) return null;
          final dynamic first = structured.first;
          if (first is! Map<String, dynamic>) return null;
          final dynamic lines = first['line'];
          if (lines is! List || lines.isEmpty) return null;
          final String text = lines
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> l) => (l['value'] as String?) ?? '')
              .join('\n')
              .trim();
          if (text.isEmpty) return null;
          return Lyrics(value: text);
        },
      );
      if (fromNavidrome != null) return fromNavidrome;
    } on NotFoundError {
      // Code 70 — Navidrome has no lyrics for this id. Fall through.
    }
    // Any other ApiError (auth, server error) is intentionally let through
    // so the error pane fires — don't silently fall back for real errors.
  }

  // --- Stage 2: LRCLib direct API ---
  final String a = artist.trim();
  final String t = title.trim();
  if (a.isEmpty || t.isEmpty) return null;

  try {
    final Dio lrcDio = Dio(BaseOptions(
      baseUrl: _kLrcLibBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final Response<dynamic> res = await lrcDio.get<dynamic>(
      '/api/get',
      queryParameters: <String, dynamic>{
        'artist_name': a,
        'track_name': t,
      },
    );
    final dynamic data = res.data;
    if (data is! Map<String, dynamic>) return null;
    final String? plain = data['plainLyrics'] as String?;
    if (plain == null || plain.trim().isEmpty) return null;
    return Lyrics(value: plain.trim());
  } on DioException catch (e) {
    // 404 = LRCLib found nothing — empty state.
    if (e.response?.statusCode == 404) return null;
    // Other network errors → empty state (LRCLib unreachable is non-fatal).
    return null;
  }
}
