import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/providers/job_status.dart';

// ---------------------------------------------------------------------------
// Helpers (mirror queue_test.dart).
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
  Duration interval = const Duration(seconds: 2),
}) {
  return ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith((_) => dio),
      jobStatusPollIntervalProvider.overrideWith((_) => interval),
    ],
  );
}

Map<String, dynamic> _jobJson({
  String jobId = 'job-1',
  String state = 'queued',
  String? error,
  String? outputPath,
  String? finishedAt,
}) {
  return <String, dynamic>{
    'job_id': jobId,
    'source_url': 'https://www.youtube.com/watch?v=test',
    'source_type': 'song',
    'state': state,
    'created_at': '2026-06-09T12:00:00Z',
    'error': ?error,
    'output_path': ?outputPath,
    'finished_at': ?finishedAt,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JobStatus — initial fetch', () {
    test('fires GET /status/{id} once and parses the response', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _jobJson(jobId: 'abc-123', state: 'running')),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      // Listen so the provider stays alive between read and await.
      c.listen<AsyncValue<JobView>>(
        jobStatusProvider('abc-123'),
        (_, _) {},
      );

      final JobView j = await c.read(jobStatusProvider('abc-123').future);
      expect(j.jobId, 'abc-123');
      expect(j.state, JobState.running);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/status/abc-123');
      expect(adapter.requests.single.method, 'GET');
    });
  });

  group('JobStatus — polling cadence', () {
    test('non-terminal state → keeps polling every interval', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _jobJson(state: 'running')),
        );
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<JobView>>(jobStatusProvider('j1'), (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(2));

        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
      });
    });

    test('respects jobStatusPollIntervalProvider override', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _jobJson(state: 'queued')),
        );
        final ProviderContainer c = _container(
          dio: _dioWith(adapter),
          interval: const Duration(seconds: 1),
        );
        addTearDown(c.dispose);

        c.listen<AsyncValue<JobView>>(jobStatusProvider('j1'), (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        async.elapse(const Duration(seconds: 3));
        async.elapse(const Duration(microseconds: 1));
        // initial + 3 ticks at 1s.
        expect(adapter.requests, hasLength(4));
      });
    });

    test('transient error keeps polling', () {
      fakeAsync((FakeAsync async) {
        int n = 0;
        final _CountingAdapter adapter = _CountingAdapter((_) {
          n++;
          if (n == 2) {
            return _json(500, <String, dynamic>{'detail': 'transient'});
          }
          return _json(200, _jobJson(state: 'running'));
        });
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<JobView>>(jobStatusProvider('j1'), (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(2));
        expect(c.read(jobStatusProvider('j1')), isA<AsyncError<JobView>>());

        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
        expect(c.read(jobStatusProvider('j1')), isA<AsyncData<JobView>>());
      });
    });
  });

  group('JobStatus — terminal stops polling', () {
    test('initial state already done → no further ticks', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _jobJson(state: 'done')),
        );
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<JobView>>(jobStatusProvider('j1'), (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(microseconds: 1));
        // No further polling.
        expect(adapter.requests, hasLength(1));
      });
    });

    test('transitions running → done → polling stops on the terminal tick', () {
      fakeAsync((FakeAsync async) {
        int n = 0;
        final _CountingAdapter adapter = _CountingAdapter((_) {
          n++;
          if (n <= 2) {
            return _json(200, _jobJson(state: 'running'));
          }
          return _json(200, _jobJson(state: 'done'));
        });
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<JobView>>(jobStatusProvider('j1'), (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        // Tick 2: still running → schedule next.
        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(2));

        // Tick 3: done → no further schedule.
        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
        expect(
          c.read(jobStatusProvider('j1')).valueOrNull?.state,
          JobState.done,
        );

        // 30 more elapsed seconds → still 3.
        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(3));
      });
    });

    test('failed state also halts polling', () {
      fakeAsync((FakeAsync async) {
        final _CountingAdapter adapter = _CountingAdapter(
          (_) => _json(200, _jobJson(state: 'failed', error: 'download tool bad')),
        );
        final ProviderContainer c = _container(dio: _dioWith(adapter));
        addTearDown(c.dispose);

        c.listen<AsyncValue<JobView>>(jobStatusProvider('j1'), (_, _) {});
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));

        async.elapse(const Duration(seconds: 30));
        async.elapse(const Duration(microseconds: 1));
        expect(adapter.requests, hasLength(1));
      });
    });
  });
}
