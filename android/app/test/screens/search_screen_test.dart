import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/client.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/search_response.dart';
import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/providers/search.dart';
import 'package:heerr/screens/search_screen.dart';
import 'package:heerr/widgets/empty_state.dart';
import 'package:heerr/widgets/result_tile.dart';
import 'package:heerr/widgets/skeleton.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: SearchScreen()),
  );
}

// Builds a results-provider override that synchronously yields the given
// AsyncValue. Using `overrideWith` with a function lets riverpod manage the
// internal state correctly.
Override _resultsValue(AsyncValue<SearchResponse> value) {
  return searchResultsProvider.overrideWith((Ref<AsyncValue<SearchResponse>> ref) {
    return value.when(
      data: (SearchResponse r) => Future<SearchResponse>.value(r),
      loading: () => Completer<SearchResponse>().future, // never completes
      error: (Object e, StackTrace st) => Future<SearchResponse>.error(e, st),
    );
  });
}

// Common results fixture: cover_url null so widget tests don't try to fetch
// over the real network.
const SearchResponse _twoResults = SearchResponse(
  results: <SearchResultItem>[
    SearchResultItem(
      spotifyUri: 'spotify:track:1',
      spotifyUrl: 'https://open.spotify.com/track/1',
      title: 'First',
      artist: 'Artist A',
      alreadyDownloaded: false,
    ),
    SearchResultItem(
      spotifyUri: 'spotify:track:2',
      spotifyUrl: 'https://open.spotify.com/track/2',
      title: 'Second',
      artist: 'Artist B',
      album: 'Album X',
      alreadyDownloaded: true,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('initial state: empty query → EmptyState "Search Spotify"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          _resultsValue(const AsyncData<SearchResponse>(
            SearchResponse(results: <SearchResultItem>[]),
          )),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('Search Spotify'),
      ),
      findsOneWidget,
    );
    expect(find.byType(ResultTile), findsNothing);
  });

  testWidgets('loading state renders a SkeletonList', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          _resultsValue(const AsyncLoading<SearchResponse>()),
        ],
      ),
    );
    // Don't pumpAndSettle — the loading provider never completes.
    await tester.pump();

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(SkeletonTile), findsWidgets);
  });

  testWidgets('non-empty query with results renders ResultTile per item', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[_resultsValue(const AsyncData<SearchResponse>(_twoResults))],
    );
    addTearDown(container.dispose);
    // Seed the query so the Body isn't in its empty-query branch.
    container.read(searchQueryProvider.notifier).setQuery('q');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResultTile), findsNWidgets(2));
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    // Subtitle has artist • album for the second row.
    expect(find.text('Artist B • Album X'), findsOneWidget);
    // alreadyDownloaded=true row shows the badge.
    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });

  testWidgets('non-empty query with empty results → EmptyState "No results"', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        _resultsValue(const AsyncData<SearchResponse>(
          SearchResponse(results: <SearchResultItem>[]),
        )),
      ],
    );
    addTearDown(container.dispose);
    container.read(searchQueryProvider.notifier).setQuery('rare-thing');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('error state renders the ApiError.message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          _resultsValue(
            AsyncError<SearchResponse>(
              const RateLimitedError(
                retryAfter: Duration(seconds: 5),
                detail: 'upstream rate limited',
              ),
              StackTrace.current,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('upstream rate limited'), findsOneWidget);
  });

  testWidgets('tapping a type segment updates searchQueryProvider.type', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        _resultsValue(const AsyncData<SearchResponse>(
          SearchResponse(results: <SearchResultItem>[]),
        )),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Default: track. Tap Albums.
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    expect(container.read(searchQueryProvider).type, SpotifyType.album);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(container.read(searchQueryProvider).type, SpotifyType.playlist);
  });

  testWidgets('typing in the text field updates searchQueryProvider.query', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        _resultsValue(const AsyncData<SearchResponse>(
          SearchResponse(results: <SearchResultItem>[]),
        )),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'tame impala');
    await tester.pump();

    expect(container.read(searchQueryProvider).query, 'tame impala');
  });

  testWidgets('seeds the text field from existing provider state', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        _resultsValue(const AsyncData<SearchResponse>(_twoResults)),
      ],
    );
    addTearDown(container.dispose);

    // Pre-populate the query before the widget mounts — simulates a
    // tab-switch round-trip.
    container.read(searchQueryProvider.notifier).setQuery('pre-existing');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'pre-existing');
  });

  group('ResultTile widget unit', () {
    testWidgets('renders title, artist, no badge when not downloaded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ResultTile(
                item: SearchResultItem(
                  spotifyUri: 'spotify:track:1',
                  spotifyUrl: 'https://open.spotify.com/track/1',
                  title: 'Hello',
                  artist: 'World',
                  alreadyDownloaded: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('World'), findsOneWidget);
      expect(find.byIcon(Icons.download_done), findsNothing);
      // No cover_url → placeholder icon visible.
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('dims and shows badge when alreadyDownloaded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ResultTile(
                item: SearchResultItem(
                  spotifyUri: 'spotify:track:2',
                  spotifyUrl: 'https://open.spotify.com/track/2',
                  title: 'Owned',
                  artist: 'X',
                  alreadyDownloaded: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download_done), findsOneWidget);
      final Opacity opacity =
          tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.5);
    });
  });

  // -------------------------------------------------------------------------
  // D1 — tap fires the download dispatcher; snackbar copy depends on
  // `deduped`. We override dioClientProvider with a fake adapter so dispatch
  // hits a canned response.
  // -------------------------------------------------------------------------
  group('D1 — tap dispatches /download', () {
    Widget wrap(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchScreen()),
      );
    }

    ProviderContainer makeContainer({
      required _FakeAdapter adapter,
    }) {
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = adapter;
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          _resultsValue(const AsyncData<SearchResponse>(_twoResults)),
          dioClientProvider.overrideWith((_) => dio),
        ],
      );
      // Seed the query so the body isn't in its empty-query branch.
      c.read(searchQueryProvider.notifier).setQuery('q');
      return c;
    }

    testWidgets('non-deduped response → "Queued" snackbar', (
      WidgetTester tester,
    ) async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json202(<String, dynamic>{
          'job_id': 'j1',
          'state': 'queued',
          'deduped': false,
        }),
      );
      final ProviderContainer c = makeContainer(adapter: adapter);
      addTearDown(c.dispose);

      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // runAsync escapes the fake-async zone so dio's internal stream-based
      // body decoding actually resolves to wall-clock completion.
      await tester.runAsync<void>(() async {
        await tester.tap(find.text('First'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(); // render the snackbar

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/download');
      expect(adapter.requests.single.data, <String, dynamic>{
        'spotify_uri': 'spotify:track:1',
      });
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('deduped=true response → "Already downloaded" snackbar', (
      WidgetTester tester,
    ) async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json202(<String, dynamic>{
          'job_id': 'existing-1',
          'state': 'done',
          'deduped': true,
        }),
      );
      // We need an item that's NOT alreadyDownloaded (the tile disables onTap
      // for downloaded items), but whose backend response says deduped.
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          _resultsValue(const AsyncData<SearchResponse>(
            SearchResponse(results: <SearchResultItem>[
              SearchResultItem(
                spotifyUri: 'spotify:track:dup',
                spotifyUrl: 'https://open.spotify.com/track/dup',
                title: 'Dup',
                artist: 'Artist',
                alreadyDownloaded: false,
              ),
            ]),
          )),
          dioClientProvider.overrideWith((_) {
            final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
            dio.httpClientAdapter = adapter;
            return dio;
          }),
        ],
      );
      addTearDown(c.dispose);
      c.read(searchQueryProvider.notifier).setQuery('q');

      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      await tester.runAsync<void>(() async {
        await tester.tap(find.text('Dup'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Already downloaded'), findsOneWidget);
    });

    testWidgets('ApiError on download → showApiError snackbar (E1 copy)', (
      WidgetTester tester,
    ) async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonStatus(
          401,
          <String, dynamic>{'detail': 'token revoked'},
        ),
      );
      final ProviderContainer c = makeContainer(adapter: adapter);
      addTearDown(c.dispose);

      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      await tester.runAsync<void>(() async {
        await tester.tap(find.text('First'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // PLAN §9 row 1: 401 → "auth failed — re-paste your token".
      expect(find.text('auth failed — re-paste your token'), findsOneWidget);
    });

    testWidgets('mid-flight: tile shows a spinner; clears on completion', (
      WidgetTester tester,
    ) async {
      final Completer<ResponseBody> gate = Completer<ResponseBody>();
      final _FakeAdapter adapter = _FakeAdapter((_) => gate.future);
      final ProviderContainer c = makeContainer(adapter: adapter);
      addTearDown(c.dispose);

      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      await tester.tap(find.text('First'));
      await tester.pump(); // dispatch starts, state set → tile rebuilds

      // Spinner appears on the row that was tapped.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(_json202(<String, dynamic>{
        'job_id': 'j1',
        'state': 'queued',
        'deduped': false,
      }));
      await tester.pumpAndSettle();

      // Spinner gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('alreadyDownloaded tile is not tappable → no request fires', (
      WidgetTester tester,
    ) async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json202(<String, dynamic>{
          'job_id': 'j1',
          'state': 'queued',
          'deduped': false,
        }),
      );
      final ProviderContainer c = makeContainer(adapter: adapter);
      addTearDown(c.dispose);

      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // Second row is `alreadyDownloaded: true`.
      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pump();

      expect(adapter.requests, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Local D1 helpers — hand-rolled HTTP adapter, same shape as
// test/api/client_test.dart and test/providers/download_test.dart.
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

ResponseBody _json202(Map<String, dynamic> body) => _jsonStatus(202, body);

ResponseBody _jsonStatus(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}
