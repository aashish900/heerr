import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/player/search_result_to_media_item.dart';

void main() {
  const String base = 'http://heerr.test:8000/api/v1';
  const String token = 'tok-1';
  const String watch = 'https://music.youtube.com/watch?v=abc123';

  SearchResultItem item({
    String? album = 'Currents',
    int? durationMs = 467000,
    String? coverUrl = 'https://i.ytimg.com/cover.jpg',
  }) {
    return SearchResultItem(
      sourceUrl: watch,
      sourceType: 'song',
      title: 'Let It Happen',
      artist: 'Tame Impala',
      album: album,
      durationMs: durationMs,
      coverUrl: coverUrl,
      alreadyDownloaded: false,
    );
  }

  group('searchResultToMediaItem', () {
    test('id is the preview-stream URL, not a Subsonic/file URI', () {
      final mediaItem = searchResultToMediaItem(
        item: item(),
        heerrBaseUrl: base,
        token: token,
      );

      expect(mediaItem.id, startsWith('$base/preview/stream?'));
      expect(mediaItem.id, contains('source_url=https%3A%2F%2Fmusic.youtube.com'));
      expect(mediaItem.id, contains('token=tok-1'));
      // Proves the Subsonic-stream / file path was not taken.
      expect(mediaItem.id, isNot(contains('stream.view')));
      expect(mediaItem.id, isNot(startsWith('file:')));
    });

    test('flags the item as a preview and carries the source URL', () {
      final mediaItem = searchResultToMediaItem(
        item: item(),
        heerrBaseUrl: base,
        token: token,
      );

      expect(mediaItem.extras?['preview'], isTrue);
      expect(mediaItem.extras?['sourceUrl'], watch);
      expect(mediaItem.extras?.containsKey('subsonicId'), isFalse);
    });

    test('maps title/artist/album/duration from the result', () {
      final mediaItem = searchResultToMediaItem(
        item: item(),
        heerrBaseUrl: base,
        token: token,
      );

      expect(mediaItem.title, 'Let It Happen');
      expect(mediaItem.artist, 'Tame Impala');
      expect(mediaItem.album, 'Currents');
      expect(mediaItem.duration, const Duration(milliseconds: 467000));
    });

    test('null duration stays null', () {
      final mediaItem = searchResultToMediaItem(
        item: item(durationMs: null),
        heerrBaseUrl: base,
        token: token,
      );
      expect(mediaItem.duration, isNull);
    });

    test('uses the cover URL for art when present', () {
      final mediaItem = searchResultToMediaItem(
        item: item(),
        heerrBaseUrl: base,
        token: token,
      );
      expect(mediaItem.artUri.toString(), 'https://i.ytimg.com/cover.jpg');
    });

    test('falls back to the launcher icon when cover is missing', () {
      final mediaItem = searchResultToMediaItem(
        item: item(coverUrl: null),
        heerrBaseUrl: base,
        token: token,
      );
      expect(mediaItem.artUri.toString(), contains('mipmap/ic_launcher'));
    });
  });
}
