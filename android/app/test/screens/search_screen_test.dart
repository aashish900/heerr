import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/search_response.dart';
import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/providers/search.dart';
import 'package:heerr/screens/search_screen.dart';
import 'package:heerr/widgets/result_tile.dart';

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
  testWidgets('initial state: empty query → "Type to search Spotify" hint', (
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

    expect(find.text('Type to search Spotify'), findsOneWidget);
    expect(find.byType(ResultTile), findsNothing);
  });

  testWidgets('loading state shows a CircularProgressIndicator', (
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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

  testWidgets('non-empty query with empty results shows "No results"', (
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
        const MaterialApp(
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
        const MaterialApp(
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
      );

      expect(find.byIcon(Icons.download_done), findsOneWidget);
      final Opacity opacity =
          tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.5);
    });
  });
}
