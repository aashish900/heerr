import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/player/podcast_audio_url.dart';

void main() {
  const String base = 'http://heerr.test:8000/api/v1';
  const String episodeId = 'e1';
  const String token = 'raw-token-xyz';

  group('buildPodcastAudioUrl', () {
    test('appends the episode audio path and encodes the token', () {
      final String url = buildPodcastAudioUrl(
        heerrBaseUrl: base,
        episodeId: episodeId,
        token: token,
      );

      expect(url, '$base/podcasts/episodes/$episodeId/audio?token=$token');
    });

    test('strips a single trailing slash on the base url', () {
      final String url = buildPodcastAudioUrl(
        heerrBaseUrl: '$base/',
        episodeId: episodeId,
        token: token,
      );

      expect(url, startsWith('$base/podcasts/episodes/$episodeId/audio?'));
      expect(url, isNot(contains('/v1//podcasts')));
    });
  });
}
