import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/models/recommend_health.dart';
import 'package:heerr/providers/recommendations.dart';

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  int calls = 0;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls += 1;
    lastRequest = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ProviderContainer _container(_CountingAdapter adapter) {
  return ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://heerr.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
    ],
  );
}

void main() {
  test('GETs /recommend/health and parses the typed response', () async {
    final _CountingAdapter adapter = _CountingAdapter(
      (_) => _json(<String, dynamic>{
        'engine': 'lastfm',
        'status': 'ok',
        'fallback_active': false,
      }),
    );
    final ProviderContainer c = _container(adapter);
    addTearDown(c.dispose);

    final RecommendHealth h =
        await c.read(recommendHealthNotifierProvider.future);

    expect(adapter.calls, 1);
    expect(adapter.lastRequest!.path, '/recommend/health');
    expect(h.engine, 'lastfm');
    expect(h.status, 'ok');
    expect(h.fallbackActive, isFalse);
  });

  test('parses degraded + fallback_active', () async {
    final _CountingAdapter adapter = _CountingAdapter(
      (_) => _json(<String, dynamic>{
        'engine': 'lastfm',
        'status': 'degraded',
        'fallback_active': true,
      }),
    );
    final ProviderContainer c = _container(adapter);
    addTearDown(c.dispose);

    final RecommendHealth h =
        await c.read(recommendHealthNotifierProvider.future);
    expect(h.status, 'degraded');
    expect(h.fallbackActive, isTrue);
  });

  test('refreshIfStale: skips when cached payload is fresh', () async {
    final _CountingAdapter adapter = _CountingAdapter(
      (_) => _json(<String, dynamic>{
        'engine': 'ytmusic',
        'status': 'ok',
        'fallback_active': false,
      }),
    );
    final ProviderContainer c = _container(adapter);
    addTearDown(c.dispose);

    await c.read(recommendHealthNotifierProvider.future);
    expect(adapter.calls, 1);

    c.read(recommendHealthNotifierProvider.notifier).refreshIfStale();
    // No re-fetch should have fired — the value is < 60 s old.
    expect(adapter.calls, 1);
  });

  test('refreshIfStale: re-fetches when payload is older than maxAge',
      () async {
    final _CountingAdapter adapter = _CountingAdapter(
      (_) => _json(<String, dynamic>{
        'engine': 'ytmusic',
        'status': 'ok',
        'fallback_active': false,
      }),
    );
    final ProviderContainer c = _container(adapter);
    addTearDown(c.dispose);

    await c.read(recommendHealthNotifierProvider.future);
    expect(adapter.calls, 1);

    // A 0-duration maxAge always treats the cache as stale → forces
    // invalidation + re-fetch on the next read.
    c.read(recommendHealthNotifierProvider.notifier)
        .refreshIfStale(maxAge: Duration.zero);
    await c.read(recommendHealthNotifierProvider.future);
    expect(adapter.calls, 2);
  });
}
