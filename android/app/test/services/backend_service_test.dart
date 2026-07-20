import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/services/backend_service.dart';

// W1 (#41): container-free transport tests for the heerr-backend service,
// same pattern as subsonic_library_service_test.dart — a scripted adapter,
// no ProviderContainer.

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastRequest = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

(BackendService, _FakeAdapter) _service(
  FutureOr<ResponseBody> Function(RequestOptions) responder,
) {
  final _FakeAdapter adapter = _FakeAdapter(responder);
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
  return (BackendService(dio), adapter);
}

ResponseBody _json(String body, int status) {
  return ResponseBody.fromString(
    body,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _noContent() => ResponseBody.fromString('', 204);

void main() {
  group('deleteLibrarySong', () {
    test('issues DELETE /library/song with the path in the body', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"deleted": true, "path": "A/B/01 - S.mp3"}', 200),
      );

      await service.deleteLibrarySong('A/B/01 - S.mp3');

      final RequestOptions req = adapter.lastRequest!;
      expect(req.method, 'DELETE');
      expect(req.path, '/library/song');
      expect(
        jsonEncode(req.data),
        jsonEncode(<String, String>{'path': 'A/B/01 - S.mp3'}),
      );
    });

    test('404 maps to NotFoundError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "file not found in the music library"}', 404),
      );
      await expectLater(
        service.deleteLibrarySong('A/B/gone.mp3'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('403 maps to ForbiddenError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "insufficient scope"}', 403),
      );
      await expectLater(
        service.deleteLibrarySong('A/B/01 - S.mp3'),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.deleteLibrarySong('A/B/01 - S.mp3'),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('editLibrarySong', () {
    test('issues PATCH /library/song as multipart with only set fields',
        () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"updated": true, "path": "A/B/01 - S.mp3", '
            '"fields": ["title", "artist"]}', 200),
      );

      await service.editLibrarySong(
        path: 'A/B/01 - S.mp3',
        title: 'New Title',
        artist: 'A, B',
      );

      final RequestOptions req = adapter.lastRequest!;
      expect(req.method, 'PATCH');
      expect(req.path, '/library/song');
      final FormData form = req.data as FormData;
      final Map<String, String> fields =
          <String, String>{for (final MapEntry<String, String> f in form.fields) f.key: f.value};
      expect(fields, <String, String>{
        'path': 'A/B/01 - S.mp3',
        'title': 'New Title',
        'artist': 'A, B',
      });
      expect(fields.containsKey('album'), isFalse);
      expect(form.files, isEmpty);
    });

    test('attaches the cover as a JPEG multipart file', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"updated": true, "path": "p.mp3", '
            '"fields": ["cover"]}', 200),
      );

      await service.editLibrarySong(
        path: 'p.mp3',
        coverBytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0x00]),
      );

      final FormData form = (adapter.lastRequest!.data as FormData);
      expect(form.files, hasLength(1));
      final MapEntry<String, MultipartFile> cover = form.files.first;
      expect(cover.key, 'cover');
      expect(cover.value.filename, 'cover.jpg');
      expect(cover.value.contentType?.mimeType, 'image/jpeg');
    });

    test('404 maps to NotFoundError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "file not found in the music library"}', 404),
      );
      await expectLater(
        service.editLibrarySong(path: 'gone.mp3', title: 'x'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('403 maps to ForbiddenError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "insufficient scope"}', 403),
      );
      await expectLater(
        service.editLibrarySong(path: 'p.mp3', title: 'x'),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.editLibrarySong(path: 'p.mp3', title: 'x'),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('logout', () {
    test('issues POST /auth/logout and completes on 204', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _noContent(),
      );

      await service.logout();

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/auth/logout');
    });

    test('401 maps to an ApiError (caller swallows it)', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "invalid or expired token"}', 401),
      );
      await expectLater(
        service.logout(),
        throwsA(isA<ApiError>()),
      );
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.logout(),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('health', () {
    test('issues GET /health and returns true on {"status": "ok"}',
        () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"status": "ok"}', 200),
      );

      final bool online = await service.health();

      expect(online, isTrue);
      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/health');
    });

    test('returns false when status is not "ok"', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"status": "degraded"}', 200),
      );

      expect(await service.health(), isFalse);
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.health(),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  // PC1 (#53): podcast endpoint wrappers.

  group('searchPodcasts', () {
    test('issues POST /podcasts/search and parses results', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json(
          '{"results": [{"feed_url": "https://ex.com/f.xml", '
          '"title": "Show", "author": null, "image_url": null, '
          '"description": null}]}',
          200,
        ),
      );

      final result = await service.searchPodcasts('test query', limit: 10);

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/podcasts/search');
      expect(
        adapter.lastRequest!.data,
        <String, dynamic>{'query': 'test query', 'limit': 10},
      );
      expect(result, hasLength(1));
      expect(result.single.title, 'Show');
      expect(result.single.id, isNull);
    });
  });

  group('subscribePodcast', () {
    test('issues POST /podcasts/subscribe with feed_url', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json(
          '{"id": "c1", "feed_url": "https://ex.com/f.xml", '
          '"title": "Show", "author": null, "image_url": null, '
          '"description": null}',
          200,
        ),
      );

      final channel =
          await service.subscribePodcast('https://ex.com/f.xml');

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/podcasts/subscribe');
      expect(
        adapter.lastRequest!.data,
        <String, dynamic>{'feed_url': 'https://ex.com/f.xml'},
      );
      expect(channel.id, 'c1');
    });
  });

  group('unsubscribePodcast', () {
    test('issues DELETE /podcasts/subscribe/{channelId}', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _noContent(),
      );

      await service.unsubscribePodcast('c1');

      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.path, '/podcasts/subscribe/c1');
    });

    test('404 maps to NotFoundError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "not subscribed to this channel"}', 404),
      );
      await expectLater(
        service.unsubscribePodcast('c1'),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  group('podcastSubscriptions', () {
    test('issues GET /podcasts/subscriptions and parses channels', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json(
          '{"channels": [{"id": "c1", "feed_url": "https://ex.com/f.xml", '
          '"title": "Show", "author": null, "image_url": null, '
          '"description": null}]}',
          200,
        ),
      );

      final result = await service.podcastSubscriptions();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/podcasts/subscriptions');
      expect(result, hasLength(1));
      expect(result.single.id, 'c1');
    });
  });

  group('podcastEpisodes', () {
    test('issues GET .../episodes with limit/offset query params', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"episodes": [], "total": 0}', 200),
      );

      final result =
          await service.podcastEpisodes('c1', limit: 5, offset: 10);

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/podcasts/channels/c1/episodes');
      expect(
        adapter.lastRequest!.queryParameters,
        <String, dynamic>{'limit': 5, 'offset': 10},
      );
      expect(result.total, 0);
      expect(result.episodes, isEmpty);
    });

    test('PA2 (#53): includes sort in the query when provided', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"episodes": [], "total": 0}', 200),
      );

      await service.podcastEpisodes('c1', sort: 'oldest');

      expect(
        adapter.lastRequest!.queryParameters,
        <String, dynamic>{'limit': 20, 'offset': 0, 'sort': 'oldest'},
      );
    });
  });

  group('podcastEpisodeFeed (PA1/PR3, #53)', () {
    test('issues GET /podcasts/episodes with filter/limit/offset', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"episodes": [], "total": 0}', 200),
      );

      final result = await service.podcastEpisodeFeed(
        'in_progress',
        limit: 5,
        offset: 10,
      );

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/podcasts/episodes');
      expect(
        adapter.lastRequest!.queryParameters,
        <String, dynamic>{'filter': 'in_progress', 'limit': 5, 'offset': 10},
      );
      expect(result.total, 0);
      expect(result.episodes, isEmpty);
    });

    test('parses channel title/art alongside each episode', () async {
      final (BackendService service, _) = _service(
        (_) => _json(
          '{"episodes": [{"id": "e1", "channel_id": "c1", '
          '"channel_title": "Show A", "channel_image_url": "https://a/art.png", '
          '"guid": "g1", "title": "Episode 1", "description": null, '
          '"published_at": null, "duration_s": null, '
          '"enclosure_url": "https://a/e1.mp3", "enclosure_type": null, '
          '"image_url": null, "episode_no": null, "season_no": null, '
          '"downloaded": false, "position_s": 0, "played": false}], '
          '"total": 1}',
          200,
        ),
      );

      final result = await service.podcastEpisodeFeed('latest');

      expect(result.total, 1);
      expect(result.episodes.single.channelTitle, 'Show A');
      expect(result.episodes.single.channelImageUrl, 'https://a/art.png');
    });
  });

  group('refreshPodcastChannel', () {
    test('issues POST /podcasts/channels/{channelId}/refresh', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json(
          '{"id": "c1", "feed_url": "https://ex.com/f.xml", '
          '"title": "Show", "author": null, "image_url": null, '
          '"description": null}',
          200,
        ),
      );

      final channel = await service.refreshPodcastChannel('c1');

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/podcasts/channels/c1/refresh');
      expect(channel.id, 'c1');
    });
  });

  group('downloadPodcastEpisode', () {
    test('issues POST /podcasts/episodes/{episodeId}/download', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json(
          '{"job_id": "j1", "state": "queued", "deduped": false}',
          202,
        ),
      );

      final res = await service.downloadPodcastEpisode('e1');

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/podcasts/episodes/e1/download');
      expect(res.jobId, 'j1');
      expect(res.deduped, isFalse);
    });
  });

  group('updateEpisodeProgress', () {
    test('issues PUT .../progress with position_s + played', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json(
          '{"episode_id": "e1", "position_s": 90, "played": false}',
          200,
        ),
      );

      final res = await service.updateEpisodeProgress(
        'e1',
        positionS: 90,
        played: false,
      );

      expect(adapter.lastRequest!.method, 'PUT');
      expect(adapter.lastRequest!.path, '/podcasts/episodes/e1/progress');
      expect(
        adapter.lastRequest!.data,
        <String, dynamic>{'position_s': 90, 'played': false},
      );
      expect(res.positionS, 90);
    });
  });
}
