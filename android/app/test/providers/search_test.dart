import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/models/enums.dart';
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
        'spotify_uri': 'spotify:track:abc',
        'spotify_url': 'https://open.spotify.com/track/abc',
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
  group('SearchQuery state', () {
    test('initial state: empty query + track type', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      final SearchQueryState v = c.read(searchQueryProvider);
      expect(v.query, '');
      expect(v.type, SpotifyType.track);
    });

    test('setQuery updates query and preserves type', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      c.read(searchQueryProvider.notifier).setQuery('tame impala');
      final SearchQueryState v = c.read(searchQueryProvider);
      expect(v.query, 'tame impala');
      expect(v.type, SpotifyType.track);
    });

    test('setType updates type and preserves query', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      c.read(searchQueryProvider.notifier).setQuery('q');
      c.read(searchQueryProvider.notifier).setType(SpotifyType.album);
      final SearchQueryState v = c.read(searchQueryProvider);
      expect(v.query, 'q');
      expect(v.type, SpotifyType.album);
    });
  });

  group('searchResults', () {
    test('empty query → returns empty results without hitting the network', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(500, <String, dynamic>{}), // would fail if called
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      final SearchResponse r = await c.read(searchResultsProvider.future);
      expect(r.results, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('whitespace-only query also short-circuits', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(500, <String, dynamic>{}),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      c.read(searchQueryProvider.notifier).setQuery('   ');
      final SearchResponse r = await c.read(searchResultsProvider.future);
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
      c.listen<AsyncValue<SearchResponse>>(searchResultsProvider, (_, _) {});

      c.read(searchQueryProvider.notifier).setQuery('tame impala');
      final SearchResponse r = await c.read(searchResultsProvider.future);

      expect(r.results, hasLength(1));
      expect(r.results.first.title, 'Found');
      expect(adapter.requests, hasLength(1));
      final RequestOptions req = adapter.requests.single;
      expect(req.path, '/search');
      expect(req.method, 'POST');
      expect(req.data, <String, dynamic>{
        'query': 'tame impala',
        'type': 'track',
        'limit': 20,
      });
    });

    test('type toggle re-issues the search with the new type', () async {
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _stubSearchPayload()),
      );
      final ProviderContainer c = _container(dio: _dioWith(adapter));
      addTearDown(c.dispose);

      c.listen<AsyncValue<SearchResponse>>(searchResultsProvider, (_, _) {});

      c.read(searchQueryProvider.notifier).setQuery('q');
      await c.read(searchResultsProvider.future);
      expect(adapter.requests.last.data, containsPair('type', 'track'));

      c.read(searchQueryProvider.notifier).setType(SpotifyType.album);
      await c.read(searchResultsProvider.future);
      expect(adapter.requests.last.data, containsPair('type', 'album'));
      expect(adapter.requests, hasLength(2));
    });

    test('rapid retype cancels intermediate requests', () async {
      // Use a real 100ms debounce so the cancellation has a chance to land
      // between retypes.
      final _CountingAdapter adapter = _CountingAdapter(
        (_) => _json(200, _stubSearchPayload()),
      );
      final ProviderContainer c = _container(
        dio: _dioWith(adapter),
        debounce: const Duration(milliseconds: 100),
      );
      addTearDown(c.dispose);

      // Fire three rapid changes inside the debounce window — only the
      // last query's request should reach the adapter.
      c.read(searchQueryProvider.notifier).setQuery('a');
      // Subscribe so the provider actually starts executing.
      c.listen<AsyncValue<SearchResponse>>(searchResultsProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).setQuery('ab');
      c.read(searchQueryProvider.notifier).setQuery('abc');

      // Await the final result.
      final SearchResponse r = await c.read(searchResultsProvider.future);
      expect(r.results, hasLength(1));

      // Only the last query's request actually hit the adapter (the others
      // were cancelled during the debounce or via CancelToken).
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.data, containsPair('query', 'abc'));
    });
  });
}
