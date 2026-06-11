import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/models/search_response.dart';
import 'package:heerr/providers/search.dart';

// ---------------------------------------------------------------------------
// Helpers
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
  Duration debounce = Duration.zero,
}) {
  return ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith((_) => dio),
      searchDebounceProvider.overrideWith((_) => debounce),
    ],
  );
}

// Backend response shape mirrored from `backend/app/schemas/search.py`.
Map<String, dynamic> _stubSearchPayload({String title = 'Result'}) {
  return <String, dynamic>{
    'results': <Map<String, dynamic>>[
      <String, dynamic>{
        'source_url': 'https://www.youtube.com/watch?v=test',
        'source_type': 'song',
        'title': title,
        'artist': 'Test Artist',
        'already_downloaded': false,
      },
    ],
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ytmSearch(query)', () {
    test('empty query → returns empty results without hitting the network',
        () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(500, <String, dynamic>{}), // would fail if called
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      final SearchResponse r = await c.read(ytmSearchProvider('').future);
      expect(r.results, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('whitespace-only query also short-circuits', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(500, <String, dynamic>{}),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      final SearchResponse r = await c.read(ytmSearchProvider('   ').future);
      expect(r.results, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('non-empty query → POSTs /search with the right body', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _stubSearchPayload(title: 'Found')),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      // Listen to keep the provider alive across the await — autoDispose
      // would otherwise tear down our ref (and cancel the dio request) when
      // .read returns.
      c.listen<AsyncValue<SearchResponse>>(
        ytmSearchProvider('tame impala'),
        (_, _) {},
      );

      final SearchResponse r =
          await c.read(ytmSearchProvider('tame impala').future);

      expect(r.results, hasLength(1));
      expect(r.results.first.title, 'Found');
      expect(adapter.requests, hasLength(1));
      final RequestOptions req = adapter.requests.single;
      expect(req.path, '/search');
      expect(req.method, 'POST');
      expect(req.data, <String, dynamic>{
        'query': 'tame impala',
        'type': 'song',
        'limit': 20,
      });
    });

    test('different queries produce independent family entries', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _stubSearchPayload()),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      c.listen<AsyncValue<SearchResponse>>(
        ytmSearchProvider('a'),
        (_, _) {},
      );
      c.listen<AsyncValue<SearchResponse>>(
        ytmSearchProvider('b'),
        (_, _) {},
      );

      await c.read(ytmSearchProvider('a').future);
      await c.read(ytmSearchProvider('b').future);

      expect(adapter.requests, hasLength(2));
      final Iterable<dynamic> queries =
          adapter.requests.map((RequestOptions r) {
        return (r.data as Map<String, dynamic>)['query'];
      });
      expect(queries, containsAll(<String>['a', 'b']));
    });

    test('disposing the provider mid-debounce cancels the in-flight request',
        () async {
      // Real 100ms debounce so the cancellation has a chance to land before
      // the request fires.
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _stubSearchPayload()),
      );
      final ProviderContainer c = _container(
        dio: _dioWith(adapter),
        debounce: const Duration(milliseconds: 100),
      );
      addTearDown(c.dispose);

      final ProviderSubscription<AsyncValue<SearchResponse>> sub =
          c.listen<AsyncValue<SearchResponse>>(
        ytmSearchProvider('abc'),
        (_, _) {},
      );

      // Tear down before the debounce expires.
      sub.close();

      // Wait past the debounce — no request should have fired.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(adapter.requests, isEmpty);
    });
  });
}
