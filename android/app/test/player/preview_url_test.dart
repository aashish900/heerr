import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/player/preview_url.dart';

void main() {
  const String base = 'http://heerr.test:8000/api/v1';
  const String watch = 'https://music.youtube.com/watch?v=abc123';
  const String token = 'raw-token-xyz';

  group('buildPreviewStreamUrl', () {
    test('appends the preview path and encodes both query params', () {
      final String url = buildPreviewStreamUrl(
        heerrBaseUrl: base,
        sourceUrl: watch,
        token: token,
      );

      expect(url, startsWith('$base/preview/stream?'));
      // The watch URL's reserved chars must be percent-encoded, not raw.
      expect(url, contains('source_url=https%3A%2F%2Fmusic.youtube.com'));
      expect(url, contains('token=raw-token-xyz'));
    });

    test('round-trips: parsed query decodes back to the originals', () {
      final Uri parsed = Uri.parse(
        buildPreviewStreamUrl(heerrBaseUrl: base, sourceUrl: watch, token: token),
      );

      expect(parsed.path, '/api/v1/preview/stream');
      expect(parsed.queryParameters['source_url'], watch);
      expect(parsed.queryParameters['token'], token);
    });

    test('strips a single trailing slash on the base url', () {
      final String url = buildPreviewStreamUrl(
        heerrBaseUrl: '$base/',
        sourceUrl: watch,
        token: token,
      );

      expect(url, startsWith('$base/preview/stream?'));
      expect(url, isNot(contains('/v1//preview')));
    });
  });
}
