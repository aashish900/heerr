import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/api_error.dart';
import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/lyrics.dart';

part 'lyrics.g.dart';

/// Wraps `GET /rest/getLyrics.view?artist=<artist>&title=<title>`. P2.
///
/// Returns:
///  - The parsed [Lyrics] (with `value` non-empty) when Navidrome has
///    lyrics for the track.
///  - `null` when there are no lyrics for the track. Two paths arrive
///    here, both treated as "empty state, not error":
///      * Subsonic error code 70 (`NotFoundError`).
///      * `lyrics.value` is missing or empty in the envelope.
///
/// All other [ApiError]s rethrow — the UI surfaces them via the standard
/// error pane / snackbar.
@riverpod
Future<Lyrics?> lyricsFor(
  LyricsForRef ref,
  String artist,
  String title,
) async {
  final String trimmedArtist = artist.trim();
  final String trimmedTitle = title.trim();
  if (trimmedArtist.isEmpty || trimmedTitle.isEmpty) return null;

  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  try {
    final Lyrics lyrics = await subsonicCall<Lyrics>(
      () => dio.get<dynamic>(
        SubsonicEndpoints.getLyrics,
        queryParameters: <String, dynamic>{
          'artist': trimmedArtist,
          'title': trimmedTitle,
        },
      ),
      (Map<String, dynamic> env) {
        final dynamic block = env['lyrics'];
        if (block is! Map<String, dynamic>) return const Lyrics();
        return Lyrics.fromJson(block);
      },
    );
    final String? value = lyrics.value;
    if (value == null || value.trim().isEmpty) return null;
    return lyrics;
  } on NotFoundError {
    // Code 70 from Navidrome = "no lyrics for this track". Empty state,
    // not an error worth surfacing in the UI.
    return null;
  }
}
