import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/client.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/providers/download.dart';

// ---------------------------------------------------------------------------
// Helpers — same `_FakeAdapter` shape as test/api/client_test.dart.
// ---------------------------------------------------------------------------

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);
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

Dio _dioWith(_FakeAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

ProviderContainer _container(Dio dio) {
  return ProviderContainer(
    overrides: <Override>[dioClientProvider.overrideWith((_) => dio)],
  );
}

Map<String, dynamic> _payload({
  String jobId = 'job-1',
  JobState state = JobState.queued,
  bool deduped = false,
}) {
  return <String, dynamic>{
    'job_id': jobId,
    'state': state.name,
    'deduped': deduped,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DownloadDispatcher state', () {
    test('initial in-flight set is empty', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(downloadDispatcherProvider), isEmpty);
    });
  });

  group('dispatch — happy paths', () {
    test('POSTs /download with the URI in the body', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(202, _payload()),
      );
      final ProviderContainer c = _container(_dioWith(adapter));
      addTearDown(c.dispose);

      final DownloadResponse res = await c
          .read(downloadDispatcherProvider.notifier)
          .dispatch('spotify:track:abc');

      expect(res.jobId, 'job-1');
      expect(res.state, JobState.queued);
      expect(res.deduped, isFalse);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/download');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, <String, dynamic>{
        'spotify_uri': 'spotify:track:abc',
      });
    });

    test('forwards display_name when provided', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(202, _payload()),
      );
      final ProviderContainer c = _container(_dioWith(adapter));
      addTearDown(c.dispose);

      await c.read(downloadDispatcherProvider.notifier).dispatch(
            'spotify:track:abc',
            displayName: 'Imagine — John Lennon',
          );
      expect(adapter.requests.single.data, <String, dynamic>{
        'spotify_uri': 'spotify:track:abc',
        'display_name': 'Imagine — John Lennon',
      });
    });

    test('deduped response is surfaced through DownloadResponse.deduped', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
          200,
          _payload(jobId: 'existing-1', state: JobState.done, deduped: true),
        ),
      );
      final ProviderContainer c = _container(_dioWith(adapter));
      addTearDown(c.dispose);

      final DownloadResponse res = await c
          .read(downloadDispatcherProvider.notifier)
          .dispatch('spotify:track:abc');

      expect(res.deduped, isTrue);
      expect(res.state, JobState.done);
    });

    test('in-flight set contains the URI while the request is mid-flight, '
        'and clears on success', () async {
      // Hold the response in a Completer so we can observe state between
      // dispatch() and the response landing.
      final Completer<ResponseBody> gate = Completer<ResponseBody>();
      final _FakeAdapter adapter = _FakeAdapter((_) => gate.future);
      final ProviderContainer c = _container(_dioWith(adapter));
      addTearDown(c.dispose);

      // Subscribe so state changes can be observed even with autoDispose
      // semantics elsewhere.
      final List<Set<String>> seen = <Set<String>>[];
      c.listen<Set<String>>(
        downloadDispatcherProvider,
        (Set<String>? _, Set<String> next) => seen.add(next),
        fireImmediately: true,
      );

      final Future<DownloadResponse> pending = c
          .read(downloadDispatcherProvider.notifier)
          .dispatch('spotify:track:abc');

      // Mid-flight: the URI is in the set.
      expect(c.read(downloadDispatcherProvider), <String>{'spotify:track:abc'});

      gate.complete(_json(202, _payload()));
      await pending;

      // After completion: set is empty again.
      expect(c.read(downloadDispatcherProvider), isEmpty);
      // Saw at least: {}, {uri}, {} — order matters but we don't assert
      // exact length to keep the test robust to fireImmediately quirks.
      expect(seen.first, isEmpty);
      expect(seen.any((Set<String> s) => s.contains('spotify:track:abc')), isTrue);
      expect(seen.last, isEmpty);
    });
  });

  group('dispatch — error paths', () {
    test('throws typed ApiError on 4xx and clears the in-flight URI', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(401, <String, dynamic>{'detail': 'bad token'}),
      );
      final ProviderContainer c = _container(_dioWith(adapter));
      addTearDown(c.dispose);

      await expectLater(
        c.read(downloadDispatcherProvider.notifier).dispatch('spotify:track:x'),
        throwsA(isA<UnauthorizedError>()),
      );
      // finally block must have removed the URI even though the request
      // raised.
      expect(c.read(downloadDispatcherProvider), isEmpty);
    });

    test('two concurrent dispatches for different URIs are both tracked', () async {
      final Completer<ResponseBody> gate1 = Completer<ResponseBody>();
      final Completer<ResponseBody> gate2 = Completer<ResponseBody>();
      final _FakeAdapter adapter = _FakeAdapter((RequestOptions o) {
        final String uri =
            (o.data as Map<String, dynamic>)['spotify_uri'] as String;
        return uri.endsWith(':1') ? gate1.future : gate2.future;
      });
      final ProviderContainer c = _container(_dioWith(adapter));
      addTearDown(c.dispose);

      final Future<DownloadResponse> a = c
          .read(downloadDispatcherProvider.notifier)
          .dispatch('spotify:track:1');
      final Future<DownloadResponse> b = c
          .read(downloadDispatcherProvider.notifier)
          .dispatch('spotify:track:2');

      expect(
        c.read(downloadDispatcherProvider),
        <String>{'spotify:track:1', 'spotify:track:2'},
      );

      gate1.complete(_json(202, _payload(jobId: 'j1')));
      await a;
      expect(c.read(downloadDispatcherProvider), <String>{'spotify:track:2'});

      gate2.complete(_json(202, _payload(jobId: 'j2')));
      await b;
      expect(c.read(downloadDispatcherProvider), isEmpty);
    });
  });
}
