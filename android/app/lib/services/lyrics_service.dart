import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_error.dart';
import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/subsonic/lyrics.dart';

part 'lyrics_service.g.dart';

/// LRCLib public API base URL. No auth, no key. Free for all clients.
const String _kLrcLibBase = 'https://lrclib.net';

/// A10: transport seam for the two-stage lyrics resolution (P2). Owns the
/// Subsonic [Dio] for stage 1 and builds a throwaway LRCLib [Dio] for stage 2
/// itself, so the `lyricsFor` provider no longer constructs any transport.
class LyricsService {
  LyricsService(this._subsonicDio, {Dio? lrcLibDio})
      : _lrcLibDio = lrcLibDio ??
            Dio(BaseOptions(
              baseUrl: _kLrcLibBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _subsonicDio;
  final Dio _lrcLibDio;

  /// Resolve lyrics for a track, returning null when neither source has them.
  ///
  /// Stage 1: Navidrome `getLyricsBySongId.view?id=<songId>` (skipped when
  /// [songId] is empty). Stage 2 (on null/skip/code-70): LRCLib `GET /api/get`
  /// keyed by [artist] + [title] (skipped when either is empty). Non-404
  /// non-70 Subsonic [ApiError]s propagate so the UI shows the error pane.
  Future<Lyrics?> resolve({
    required String songId,
    required String artist,
    required String title,
  }) async {
    if (songId.trim().isNotEmpty) {
      try {
        final Lyrics? fromNavidrome = await subsonicCall<Lyrics?>(
          () => _subsonicDio.get<dynamic>(
            SubsonicEndpoints.getLyricsBySongId,
            queryParameters: <String, dynamic>{'id': songId.trim()},
          ),
          _parseStructuredLyrics,
        );
        if (fromNavidrome != null) return fromNavidrome;
      } on NotFoundError {
        // Code 70 — Navidrome has no lyrics for this id. Fall through.
      }
      // Any other ApiError (auth, server error) is intentionally let through
      // so the error pane fires — don't silently fall back for real errors.
    }

    final String a = artist.trim();
    final String t = title.trim();
    if (a.isEmpty || t.isEmpty) return null;

    try {
      final Response<dynamic> res = await _lrcLibDio.get<dynamic>(
        '/api/get',
        queryParameters: <String, dynamic>{'artist_name': a, 'track_name': t},
      );
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) return null;
      final String? plain = data['plainLyrics'] as String?;
      if (plain == null || plain.trim().isEmpty) return null;
      return Lyrics(value: plain.trim());
    } on DioException catch (e) {
      // 404 = LRCLib found nothing; other network errors are non-fatal too.
      if (e.response?.statusCode == 404) return null;
      return null;
    }
  }

  static Lyrics? _parseStructuredLyrics(Map<String, dynamic> env) {
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
  }
}

/// Async provider so the service is built once the Subsonic [Dio] is ready.
/// Tests overriding `subsonicDioClientProvider` flow through unchanged.
@riverpod
Future<LyricsService> lyricsService(LyricsServiceRef ref) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return LyricsService(dio);
}
