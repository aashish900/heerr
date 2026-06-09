import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/download_request.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/models/search_request.dart';
import 'package:heerr/models/search_response.dart';
import 'package:heerr/models/search_result_item.dart';

void main() {
  group('SearchRequest', () {
    test('serializes to snake_case keys + JsonValue type string', () {
      const SearchRequest req = SearchRequest(
        query: 'tame impala',
        type: SpotifyType.track,
        limit: 10,
      );
      expect(req.toJson(), <String, dynamic>{
        'query': 'tame impala',
        'type': 'track',
        'limit': 10,
      });
    });

    test('round-trip via JSON', () {
      const SearchRequest a = SearchRequest(
        query: 'q',
        type: SpotifyType.playlist,
      );
      final SearchRequest b = SearchRequest.fromJson(a.toJson());
      expect(b, equals(a));
      expect(b.limit, 20); // default
    });
  });

  group('SearchResultItem + SearchResponse', () {
    test('parses the backend payload shape from /search', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'spotify_uri': 'spotify:track:abc123',
            'spotify_url': 'https://open.spotify.com/track/abc123',
            'title': 'The Less I Know The Better',
            'artist': 'Tame Impala',
            'album': 'Currents',
            'duration_ms': 216320,
            'cover_url': 'https://i.scdn.co/image/xyz',
            'already_downloaded': false,
            'active_job_id': null,
          },
        ],
      };
      final SearchResponse r = SearchResponse.fromJson(payload);

      expect(r.results, hasLength(1));
      final SearchResultItem item = r.results.first;
      expect(item.spotifyUri, 'spotify:track:abc123');
      expect(item.spotifyUrl, 'https://open.spotify.com/track/abc123');
      expect(item.title, 'The Less I Know The Better');
      expect(item.artist, 'Tame Impala');
      expect(item.album, 'Currents');
      expect(item.durationMs, 216320);
      expect(item.coverUrl, 'https://i.scdn.co/image/xyz');
      expect(item.alreadyDownloaded, isFalse);
      expect(item.activeJobId, isNull);
    });

    test('round-trip via JSON', () {
      const SearchResponse a = SearchResponse(
        results: <SearchResultItem>[
          SearchResultItem(
            spotifyUri: 'spotify:album:xyz',
            spotifyUrl: 'https://open.spotify.com/album/xyz',
            title: 'Currents',
            artist: 'Tame Impala',
            alreadyDownloaded: true,
            activeJobId: 'job-123',
          ),
        ],
      );
      final SearchResponse b = SearchResponse.fromJson(a.toJson());
      expect(b, equals(a));
    });

    test('nullable fields omitted when null (include_if_null: false)', () {
      const SearchResultItem item = SearchResultItem(
        spotifyUri: 'spotify:track:1',
        spotifyUrl: 'https://open.spotify.com/track/1',
        title: 't',
        artist: 'a',
        alreadyDownloaded: false,
      );
      final Map<String, dynamic> json = item.toJson();
      expect(json.containsKey('album'), isFalse);
      expect(json.containsKey('duration_ms'), isFalse);
      expect(json.containsKey('cover_url'), isFalse);
      expect(json.containsKey('active_job_id'), isFalse);
    });
  });

  group('DownloadRequest', () {
    test('round-trip via JSON', () {
      const DownloadRequest a = DownloadRequest(
        spotifyUri: 'spotify:track:abc',
      );
      expect(a.toJson(), <String, dynamic>{'spotify_uri': 'spotify:track:abc'});
      final DownloadRequest b = DownloadRequest.fromJson(a.toJson());
      expect(b, equals(a));
    });
  });

  group('DownloadResponse', () {
    test('parses backend payload + enum mapping', () {
      final DownloadResponse r = DownloadResponse.fromJson(
        <String, dynamic>{
          'job_id': '550e8400-e29b-41d4-a716-446655440000',
          'state': 'queued',
          'deduped': false,
        },
      );
      expect(r.jobId, '550e8400-e29b-41d4-a716-446655440000');
      expect(r.state, JobState.queued);
      expect(r.state.isTerminal, isFalse);
      expect(r.deduped, isFalse);
    });

    test('deduped=true with state=done', () {
      final DownloadResponse r = DownloadResponse.fromJson(
        <String, dynamic>{
          'job_id': 'jid',
          'state': 'done',
          'deduped': true,
        },
      );
      expect(r.state, JobState.done);
      expect(r.state.isTerminal, isTrue);
      expect(r.deduped, isTrue);
    });
  });

  group('JobView', () {
    test('parses every field from /status/{id} payload', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'job_id': 'j-1',
        'spotify_uri': 'spotify:track:1',
        'spotify_type': 'track',
        'state': 'done',
        'progress': null,
        'error': null,
        'output_path': '/data/media/music/Tame Impala/Currents/01.mp3',
        'created_at': '2026-06-09T10:00:00Z',
        'started_at': '2026-06-09T10:00:01Z',
        'finished_at': '2026-06-09T10:00:42Z',
      };
      final JobView j = JobView.fromJson(payload);
      expect(j.jobId, 'j-1');
      expect(j.spotifyUri, 'spotify:track:1');
      expect(j.spotifyType, SpotifyType.track);
      expect(j.state, JobState.done);
      expect(j.outputPath, '/data/media/music/Tame Impala/Currents/01.mp3');
      expect(j.createdAt.isUtc, isTrue);
      expect(j.startedAt!.isUtc, isTrue);
      expect(j.finishedAt!.isUtc, isTrue);
    });

    test('round-trip via JSON preserves DateTime equality', () {
      final JobView a = JobView(
        jobId: 'j',
        spotifyUri: 'spotify:track:x',
        spotifyType: SpotifyType.track,
        state: JobState.failed,
        error: 'spotdl exited 1',
        createdAt: DateTime.utc(2026, 6, 9, 10),
        startedAt: DateTime.utc(2026, 6, 9, 10),
        finishedAt: DateTime.utc(2026, 6, 9, 10, 0, 5),
      );
      final JobView b = JobView.fromJson(a.toJson());
      expect(b, equals(a));
    });
  });

  group('QueueResponse', () {
    test('parses empty + populated lists', () {
      final QueueResponse empty = QueueResponse.fromJson(<String, dynamic>{
        'active': <Map<String, dynamic>>[],
        'recent': <Map<String, dynamic>>[],
      });
      expect(empty.active, isEmpty);
      expect(empty.recent, isEmpty);

      final QueueResponse populated = QueueResponse.fromJson(<String, dynamic>{
        'active': <Map<String, dynamic>>[
          <String, dynamic>{
            'job_id': 'j-running',
            'spotify_uri': 'spotify:track:run',
            'spotify_type': 'track',
            'state': 'running',
            'progress': null,
            'error': null,
            'output_path': null,
            'created_at': '2026-06-09T09:00:00Z',
            'started_at': '2026-06-09T09:00:01Z',
            'finished_at': null,
          },
        ],
        'recent': <Map<String, dynamic>>[
          <String, dynamic>{
            'job_id': 'j-done',
            'spotify_uri': 'spotify:album:done',
            'spotify_type': 'album',
            'state': 'done',
            'progress': null,
            'error': null,
            'output_path': null,
            'created_at': '2026-06-09T08:00:00Z',
            'started_at': '2026-06-09T08:00:01Z',
            'finished_at': '2026-06-09T08:01:01Z',
          },
        ],
      });
      expect(populated.active.single.state, JobState.running);
      expect(populated.recent.single.state, JobState.done);
    });
  });

  group('JobStateX.isTerminal', () {
    test('done + failed are terminal; queued + running are not', () {
      expect(JobState.done.isTerminal, isTrue);
      expect(JobState.failed.isTerminal, isTrue);
      expect(JobState.queued.isTerminal, isFalse);
      expect(JobState.running.isTerminal, isFalse);
    });
  });
}
