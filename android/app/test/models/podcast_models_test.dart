import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/enums.dart';
import 'package:heerr/models/episode_download_response.dart';
import 'package:heerr/models/episode_list_response.dart';
import 'package:heerr/models/episode_progress.dart';
import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/models/podcast_episode.dart';

// PC1 (#53): round-trip serialization for the podcast model set, mirroring
// backend/app/schemas/podcast.py.

void main() {
  group('PodcastChannel', () {
    test('round-trips a Podcast Index search result (no id)', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'feed_url': 'https://example.com/feed.xml',
        'title': 'The Test Show',
        'author': 'A. Host',
        'image_url': 'https://example.com/art.jpg',
        'description': 'A show about tests.',
      };
      final PodcastChannel channel = PodcastChannel.fromJson(json);
      expect(channel.id, isNull);
      expect(channel.feedUrl, 'https://example.com/feed.xml');
      expect(channel.title, 'The Test Show');
      expect(channel.toJson()['feed_url'], 'https://example.com/feed.xml');
    });

    test('round-trips an ingested/subscribed channel (id set)', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'c1',
        'feed_url': 'https://example.com/feed.xml',
        'title': 'The Test Show',
        'author': null,
        'image_url': null,
        'description': null,
      };
      final PodcastChannel channel = PodcastChannel.fromJson(json);
      expect(channel.id, 'c1');
      expect(channel.author, isNull);
    });
  });

  group('PodcastEpisode', () {
    test('round-trips with progress fields', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'e1',
        'channel_id': 'c1',
        'guid': 'guid-1',
        'title': 'Episode One',
        'description': 'First episode',
        'published_at': '2026-07-01T00:00:00Z',
        'duration_s': 1800,
        'enclosure_url': 'https://example.com/e1.mp3',
        'enclosure_type': 'audio/mpeg',
        'image_url': null,
        'episode_no': 1,
        'season_no': null,
        'downloaded': true,
        'position_s': 120,
        'played': false,
      };
      final PodcastEpisode ep = PodcastEpisode.fromJson(json);
      expect(ep.id, 'e1');
      expect(ep.channelId, 'c1');
      expect(ep.durationS, 1800);
      expect(ep.downloaded, isTrue);
      expect(ep.positionS, 120);
      expect(ep.played, isFalse);
      expect(ep.publishedAt, DateTime.parse('2026-07-01T00:00:00Z'));

      final Map<String, dynamic> back = ep.toJson();
      expect(back['enclosure_url'], 'https://example.com/e1.mp3');
      expect(back['position_s'], 120);
    });
  });

  group('EpisodeListResponse', () {
    test('round-trips a page of episodes + total', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'episodes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'e1',
            'channel_id': 'c1',
            'guid': 'guid-1',
            'title': 'Episode One',
            'description': null,
            'published_at': null,
            'duration_s': null,
            'enclosure_url': 'https://example.com/e1.mp3',
            'enclosure_type': null,
            'image_url': null,
            'episode_no': null,
            'season_no': null,
            'downloaded': false,
            'position_s': 0,
            'played': false,
          },
        ],
        'total': 42,
      };
      final EpisodeListResponse res = EpisodeListResponse.fromJson(json);
      expect(res.total, 42);
      expect(res.episodes, hasLength(1));
      expect(res.episodes.single.id, 'e1');
    });
  });

  group('EpisodeDownloadResponse', () {
    test('round-trips job dispatch response', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'job_id': 'j1',
        'state': 'queued',
        'deduped': false,
      };
      final EpisodeDownloadResponse res =
          EpisodeDownloadResponse.fromJson(json);
      expect(res.jobId, 'j1');
      expect(res.state, JobState.queued);
      expect(res.deduped, isFalse);
    });
  });

  group('EpisodeProgress', () {
    test('round-trips resume position', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'episode_id': 'e1',
        'position_s': 300,
        'played': true,
      };
      final EpisodeProgress res = EpisodeProgress.fromJson(json);
      expect(res.episodeId, 'e1');
      expect(res.positionS, 300);
      expect(res.played, isTrue);
    });
  });
}
