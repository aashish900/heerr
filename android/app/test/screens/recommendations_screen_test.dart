import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/providers/download.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/screens/recommendations_screen.dart';
import 'package:heerr/widgets/home_recommendation_card.dart';

class _RecordingDispatcher extends DownloadDispatcher {
  final List<String> calls = <String>[];

  @override
  Set<String> build() => const <String>{};

  @override
  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    calls.add(sourceUrl);
    state = <String>{...state, sourceUrl};
    return const DownloadResponse(
      jobId: 'job-1',
      state: JobState.queued,
      deduped: false,
    );
  }
}

class _ThrowingDispatcher extends DownloadDispatcher {
  @override
  Set<String> build() => const <String>{};

  @override
  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    throw const ForbiddenError(detail: 'cannot download');
  }
}

Widget _wrap({
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: RecommendationsScreen()),
  );
}

void main() {
  testWidgets('renders loading state initially', (WidgetTester tester) async {
    final Completer<List<RecommendedTrack>> never =
        Completer<List<RecommendedTrack>>();
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider.overrideWith(() => _StubRecs(never.future)),
    ]));
    await tester.pump();
    expect(find.text('For You'), findsOneWidget);
    // Skeleton list visible (CircularProgressIndicator absent — skeleton
    // widget renders shimmery placeholder rows). Tile texts not yet present.
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('renders error state when provider throws',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider.overrideWith(() =>
          _StubRecs(Future<List<RecommendedTrack>>.error(
              const HttpStatusError(statusCode: 503, detail: 'engine down')))),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Could not load recommendations'), findsOneWidget);
  });

  testWidgets('renders empty state when results is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider.overrideWith(
          () => _StubRecs(Future<List<RecommendedTrack>>.value(const <RecommendedTrack>[]))),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to suggest yet'), findsOneWidget);
  });

  testWidgets('renders one tile per recommendation with title + artist',
      (WidgetTester tester) async {
    final tracks = <RecommendedTrack>[
      const RecommendedTrack(
        title: 'A1',
        artist: 'X1',
        sourceUrl: 'https://music.youtube.com/watch?v=a1',
      ),
      const RecommendedTrack(
        title: 'B2',
        artist: 'Y2',
        sourceUrl: 'https://music.youtube.com/watch?v=b2',
      ),
    ];
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider
          .overrideWith(() => _StubRecs(Future<List<RecommendedTrack>>.value(tracks))),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('X1'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('Y2'), findsOneWidget);
    // #21: cards (like Home's "Picked for you") render an overlay download
    // disc per remote track instead of a full-width "Download" button.
    expect(find.byKey(const Key('rec-download')), findsNWidgets(2));
  });

  testWidgets('tapping Download dispatches to the dispatcher provider',
      (WidgetTester tester) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    final tracks = <RecommendedTrack>[
      const RecommendedTrack(
        title: 'A1',
        artist: 'X1',
        sourceUrl: 'https://music.youtube.com/watch?v=a1',
      ),
    ];
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider
          .overrideWith(() => _StubRecs(Future<List<RecommendedTrack>>.value(tracks))),
      downloadDispatcherProvider.overrideWith(() => dispatcher),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rec-download')));
    // Snackbar lingers (kSnackBarDuration) so pumpAndSettle would time out.
    // pump once for the dispatch microtask, then again for the SnackBar
    // entrance animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(dispatcher.calls, <String>['https://music.youtube.com/watch?v=a1']);
    expect(find.text('Queued "A1"'), findsOneWidget);
  });

  testWidgets(
      'inLibrary row renders Play instead of Download (N4 cross-reference)',
      (WidgetTester tester) async {
    final tracks = <RecommendedTrack>[
      const RecommendedTrack(
        title: 'Library Song',
        artist: 'Library Artist',
        sourceUrl: 'https://music.youtube.com/watch?v=lib',
        inLibrary: true,
        subsonicSongId: 'subsonic-1',
      ),
      const RecommendedTrack(
        title: 'Remote Song',
        artist: 'Remote Artist',
        sourceUrl: 'https://music.youtube.com/watch?v=rem',
      ),
    ];
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider
          .overrideWith(() => _StubRecs(Future<List<RecommendedTrack>>.value(tracks))),
    ]));
    await tester.pumpAndSettle();

    // #21: in-library track shows the overlay Play disc, remote track the
    // download disc — same affordances as Home's recommendation cards.
    expect(find.byKey(const Key('rec-play')), findsOneWidget);
    expect(find.byKey(const Key('rec-download')), findsOneWidget);

    // Play disc belongs to the library song's card (shares the same
    // HomeRecommendationCard ancestor as its title).
    final Finder playCard = find.ancestor(
      of: find.byKey(const Key('rec-play')),
      matching: find.byType(HomeRecommendationCard),
    );
    expect(
      find.descendant(of: playCard, matching: find.text('Library Song')),
      findsOneWidget,
    );
  });

  testWidgets('download ApiError surfaces a snackbar',
      (WidgetTester tester) async {
    final tracks = <RecommendedTrack>[
      const RecommendedTrack(
        title: 'A1',
        artist: 'X1',
        sourceUrl: 'https://music.youtube.com/watch?v=a1',
      ),
    ];
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider
          .overrideWith(() => _StubRecs(Future<List<RecommendedTrack>>.value(tracks))),
      downloadDispatcherProvider.overrideWith(() => _ThrowingDispatcher()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rec-download')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Forbidden snackbar copy from error_snackbar.dart "this token cannot
    // download" (action='download').
    expect(find.textContaining('download'), findsWidgets);
  });

  testWidgets('AppBar shows a refresh action (#38)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider.overrideWith(() =>
          _StubRecs(Future<List<RecommendedTrack>>.value(const <RecommendedTrack>[]))),
    ]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('for-you-refresh')), findsOneWidget);
  });

  testWidgets('tapping the refresh action calls the notifier (#38)',
      (WidgetTester tester) async {
    final _StubRecs stub =
        _StubRecs(Future<List<RecommendedTrack>>.value(const <RecommendedTrack>[]));
    await tester.pumpWidget(_wrap(overrides: <Override>[
      recommendationsProvider.overrideWith(() => stub),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('for-you-refresh')));
    await tester.pump();

    expect(stub.refreshCalls, 1);
  });
}

/// Test double for [Recommendations]. The generated `_$Recommendations`
/// supertype handles the AsyncNotifier plumbing; we just return whatever
/// `Future<List<RecommendedTrack>>` the test wants.
class _StubRecs extends Recommendations {
  _StubRecs(this._future);
  final Future<List<RecommendedTrack>> _future;
  int refreshCalls = 0;

  @override
  Future<List<RecommendedTrack>> build() => _future;

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }
}
