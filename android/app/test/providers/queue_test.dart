import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/providers/queue.dart';

// ---------------------------------------------------------------------------
// Helpers — same `_FakeAdapter` shape used elsewhere.
// ---------------------------------------------------------------------------

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.responder);
  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

Dio _dioWith(_CountingAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

ProviderContainer _container({
  required Dio dio,
  Duration interval = const Duration(seconds: 3),
}) {
  return ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith((_) => dio),
      queuePollIntervalProvider.overrideWith((_) => interval),
    ],
  );
}

Map<String, dynamic> _emptyQueue() {
  return <String, dynamic>{
    'active': <Map<String, dynamic>>[],
    'recent': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _queueWith({
  List<Map<String, dynamic>>? active,
  List<Map<String, dynamic>>? recent,
}) {
  return <String, dynamic>{
    'active': active ?? <Map<String, dynamic>>[],
    'recent': recent ?? <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _jobJson({
  String jobId = 'job-1',
  String state = 'queued',
  String spotifyUri = 'https://www.youtube.com/watch?v=test',
}) {
  return <String, dynamic>{
    'job_id': jobId,
    'source_url': spotifyUri,
    'source_type': 'song',
    'state': state,
    'created_at': '2026-06-09T12:00:00Z',
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Queue — initial fetch', () {
    test('fires GET /queue once and parses the response', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _queueWith(active: <Map<String, dynamic>>[_jobJson()])),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      final QueueResponse r = await c.read(queueProvider.future);
      expect(r.active, hasLength(1));
      expect(r.recent, isEmpty);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/queue');
      expect(adapter.requests.single.method, 'GET');
    });
  });

  group('Queue — periodic polling', () {
    test('ticks at the configured interval (3 ticks observed)', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _emptyQueue()),
        );
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        // Subscribe so the provider stays alive between ticks.
        c.listen<AsyncValue<QueueResponse>>(
          queueProvider,
          (AsyncValue<QueueResponse>? _, AsyncValue<QueueResponse> _) {},
        );

        // Drain the initial fetch's microtasks.
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        // Tick #2 at t=3s.
        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(2));

        // Tick #3 at t=6s.
        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
      });
    });

    test('respects the queuePollIntervalProvider override', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _emptyQueue()),
        );
        final ProviderContainer c = _container(
          dio: _dioWith(adapter),
          interval: const Duration(seconds: 1),
        );
        addTearDown(c.dispose);

        c.listen<AsyncValue<QueueResponse>>(queueProvider, (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        // 3 elapsed seconds at 1s interval → 3 more requests.
        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(4));
      });
    });

    test('keeps polling after a transient error (state becomes error then '
        'next tick fires again)', () {
      fakeAsync((FakeAsync async) {
        int n = 0;
        final _CountingAdapter adapter = _CountingAdapter((_) {
          n++;
          if (n == 2) {
            return _json(500, <String, dynamic>{'detail': 'transient'});
          }
          return _json(200, _emptyQueue());
        });
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<QueueResponse>>(queueProvider, (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        // Second tick: 500.
        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(2));
        expect(c.read(queueProvider), isA<AsyncError<QueueResponse>>());

        // Third tick still fires — error doesn't stop the cycle.
        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
        expect(c.read(queueProvider), isA<AsyncData<QueueResponse>>());
      });
    });
  });

  group('Queue — pause / resume', () {
    test('pause stops the timer (no ticks while paused)', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _emptyQueue()),
        );
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<QueueResponse>>(queueProvider, (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        c.read(queueProvider.notifier).pause();
        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));
      });
    });

    test('resume force-fires a tick and restarts the schedule', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _emptyQueue()),
        );
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<QueueResponse>>(queueProvider, (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        c.read(queueProvider.notifier).pause();
        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        // Resume → immediate fetch + schedule resumes.
        c.read(queueProvider.notifier).resume();
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(2));

        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
      });
    });
  });
}
