import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/providers/search.dart';
import 'package:heerr/screens/podcasts/discover_screen.dart';
import 'package:heerr/services/backend_service.dart';

// PC2 (#53): widget coverage for query -> results and the
// preview-sheet Subscribe/Unsubscribe toggle.

class _StubBackend extends BackendService {
  _StubBackend({
    this._searchResults = const <PodcastChannel>[],
    this._searchError,
    List<PodcastChannel> subscriptions = const <PodcastChannel>[],
  })  : _subscriptions = List<PodcastChannel>.of(subscriptions),
        super(Dio());

  final List<PodcastChannel> _searchResults;
  final Object? _searchError;
  final List<PodcastChannel> _subscriptions;
  final List<String> subscribeCalls = <String>[];
  final List<String> unsubscribeCalls = <String>[];

  @override
  Future<List<PodcastChannel>> searchPodcasts(
    String query, {
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final Object? err = _searchError;
    if (err != null) throw err;
    return _searchResults;
  }

  @override
  Future<List<PodcastChannel>> podcastSubscriptions() async =>
      List<PodcastChannel>.of(_subscriptions);

  @override
  Future<PodcastChannel> subscribePodcast(String feedUrl) async {
    subscribeCalls.add(feedUrl);
    final PodcastChannel channel =
        PodcastChannel(id: 'new-id', feedUrl: feedUrl, title: 'Subscribed');
    _subscriptions.add(channel);
    return channel;
  }

  @override
  Future<void> unsubscribePodcast(String channelId) async {
    unsubscribeCalls.add(channelId);
    _subscriptions.removeWhere((PodcastChannel c) => c.id == channelId);
  }
}

Widget _wrap({required BackendService backend}) {
  return ProviderScope(
    overrides: <Override>[
      searchDebounceProvider.overrideWithValue(Duration.zero),
      backendServiceProvider.overrideWith((_) async => backend),
    ],
    child: const MaterialApp(home: DiscoverScreen()),
  );
}

void main() {
  const PodcastChannel showA = PodcastChannel(
    feedUrl: 'https://a.com/f.xml',
    title: 'Show A',
    author: 'Host A',
  );

  testWidgets('shows the empty prompt before any query is entered',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(backend: _StubBackend()));
    await tester.pumpAndSettle();
    expect(find.text('Find a podcast'), findsOneWidget);
  });

  testWidgets('typing a query renders search results',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(backend: _StubBackend(searchResults: <PodcastChannel>[showA])),
    );

    await tester.enterText(
      find.byKey(const Key('podcast-discover-search-field')),
      'test',
    );
    await tester.pumpAndSettle();

    expect(find.text('Show A'), findsOneWidget);
    expect(find.text('Host A'), findsOneWidget);
  });

  testWidgets('empty results render the no-matches state',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(backend: _StubBackend()));

    await tester.enterText(
      find.byKey(const Key('podcast-discover-search-field')),
      'nothing',
    );
    await tester.pumpAndSettle();

    expect(find.text('No podcasts found'), findsOneWidget);
  });

  testWidgets('search error renders the backend detail message',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        backend: _StubBackend(
          searchError: const HttpStatusError(
            statusCode: 502,
            detail: 'Podcast Index error: boom',
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('podcast-discover-search-field')),
      'test',
    );
    await tester.pumpAndSettle();

    // Both the inline error view and the reactToApiError snackbar render
    // the same message — assert at least one, not an exact count.
    expect(find.textContaining('Podcast Index error'), findsWidgets);
  });

  testWidgets('already-subscribed result shows a check icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        backend: _StubBackend(
          searchResults: <PodcastChannel>[showA],
          subscriptions: <PodcastChannel>[
            showA.copyWith(id: 'c1'),
          ],
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('podcast-discover-search-field')),
      'test',
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets(
      'tapping a result then Subscribe calls subscribePodcast and flips '
      'the button to Unsubscribe', (WidgetTester tester) async {
    final _StubBackend backend =
        _StubBackend(searchResults: <PodcastChannel>[showA]);
    await tester.pumpWidget(_wrap(backend: backend));

    await tester.enterText(
      find.byKey(const Key('podcast-discover-search-field')),
      'test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcast-search-result-https://a.com/f.xml')));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('podcast-subscribe-toggle')));
    await tester.pumpAndSettle();

    expect(backend.subscribeCalls, <String>['https://a.com/f.xml']);
    expect(find.text('Unsubscribe'), findsOneWidget);
  });

  testWidgets('tapping Unsubscribe on an already-subscribed channel calls '
      'unsubscribePodcast', (WidgetTester tester) async {
    final _StubBackend backend = _StubBackend(
      searchResults: <PodcastChannel>[showA],
      subscriptions: <PodcastChannel>[showA.copyWith(id: 'c1')],
    );
    await tester.pumpWidget(_wrap(backend: backend));

    await tester.enterText(
      find.byKey(const Key('podcast-discover-search-field')),
      'test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcast-search-result-https://a.com/f.xml')));
    await tester.pumpAndSettle();

    expect(find.text('Unsubscribe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('podcast-subscribe-toggle')));
    await tester.pumpAndSettle();

    expect(backend.unsubscribeCalls, <String>['c1']);
    expect(find.text('Subscribe'), findsOneWidget);
  });
}
