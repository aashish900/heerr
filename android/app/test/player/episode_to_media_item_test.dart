import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/models/podcast_episode.dart';
import 'package:heerr/player/episode_to_media_item.dart';

PodcastEpisode _episode({
  required bool downloaded,
  String? imageUrl,
  int? durationS,
}) =>
    PodcastEpisode(
      id: 'e1',
      channelId: 'c1',
      guid: 'guid-1',
      title: 'Episode One',
      enclosureUrl: 'https://podcast.example/e1.mp3',
      downloaded: downloaded,
      positionS: 0,
      played: false,
      imageUrl: imageUrl,
      durationS: durationS,
    );

const String base = 'http://heerr.test:8000/api/v1';
const String token = 'raw-token-xyz';

void main() {
  group('episodeToMediaItem', () {
    test('downloaded episode uses the backend Range-audio proxy URL', () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: true),
        heerrBaseUrl: base,
        token: token,
      );

      expect(
        item.id,
        '$base/podcasts/episodes/e1/audio?token=$token',
      );
    });

    test('not-yet-downloaded episode uses the public enclosure URL directly',
        () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: false),
        heerrBaseUrl: base,
        token: token,
      );

      expect(item.id, 'https://podcast.example/e1.mp3');
    });

    test('carries episodeId and channelId in extras', () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: false),
        heerrBaseUrl: base,
        token: token,
      );

      expect(item.extras?['episodeId'], 'e1');
      expect(item.extras?['channelId'], 'c1');
    });

    test('falls back to the launcher icon when there is no episode image',
        () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: false),
        heerrBaseUrl: base,
        token: token,
      );

      expect(item.artUri.toString(), contains('mipmap/ic_launcher'));
    });

    test('uses the episode image when present', () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: false, imageUrl: 'https://ex.com/art.jpg'),
        heerrBaseUrl: base,
        token: token,
      );

      expect(item.artUri.toString(), 'https://ex.com/art.jpg');
    });

    test('maps durationS to a Duration', () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: false, durationS: 90),
        heerrBaseUrl: base,
        token: token,
      );

      expect(item.duration, const Duration(seconds: 90));
    });
  });

  group('isEpisodeMediaItem / episodeIdFromMediaItem', () {
    test('true + id for an episode item', () {
      final MediaItem item = episodeToMediaItem(
        episode: _episode(downloaded: false),
        heerrBaseUrl: base,
        token: token,
      );
      expect(isEpisodeMediaItem(item), isTrue);
      expect(episodeIdFromMediaItem(item), 'e1');
    });

    test('false + null for a non-episode item', () {
      const MediaItem item = MediaItem(id: 'file:///song.mp3', title: 'song');
      expect(isEpisodeMediaItem(item), isFalse);
      expect(episodeIdFromMediaItem(item), isNull);
    });

    test('false + null for a null item', () {
      expect(isEpisodeMediaItem(null), isFalse);
      expect(episodeIdFromMediaItem(null), isNull);
    });
  });
}
