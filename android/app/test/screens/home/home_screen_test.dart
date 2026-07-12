import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/profile_meta.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/home/home_providers.dart';
import 'package:heerr/providers/profiles/profile_meta.dart';
import 'package:heerr/screens/home/home_screen.dart';
import 'package:heerr/screens/home/quick_access_row.dart';
import 'package:heerr/screens/home/recently_added_section.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/widgets/heerr_logo.dart';

// Minimal router with a Home root + sinks for every Home navigation target.
GoRouter _testRouter() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/library/album/:id',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('album-${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/library/recently-added',
        builder: (_, _) => const Scaffold(body: Text('RECENTLY_ADDED_SCREEN')),
      ),
      GoRoute(
        path: '/queue',
        builder: (_, _) => const Scaffold(body: Text('Queue page')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile page')),
      ),
    ],
  );
}

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: heerrDarkTheme(),
      routerConfig: _testRouter(),
    ),
  );
}

Album _album(String id, String name, {String? artist}) {
  return Album(id: id, name: name, artist: artist);
}

/// Baseline overrides: newest albums + a quiet downloads count. The player
/// providers are deliberately NOT overridden — audioHandlerProvider throws
/// by default, which exercises the hero card's hidden-when-unavailable path.
List<Override> _homeOverrides({List<Album>? newest}) => <Override>[
      homeNewestProvider.overrideWith(
          (_) async => newest ?? <Album>[_album('al-1', 'A', artist: 'B')]),
      downloadedSongsProvider.overrideWith((_) async => <Song>[]),
    ];

class _StubMeta extends ProfileMetaNotifier {
  _StubMeta(this._nickname);
  final String? _nickname;

  @override
  Future<ProfileMeta> build() async => ProfileMeta(nickname: _nickname);
}

void main() {
  testWidgets('AppBar shows the brand logo; greeting renders in the body',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _homeOverrides()));
    await tester.pumpAndSettle();

    // AppBar title is the logo row (mark + wordmark), not a greeting.
    final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.title, isA<HeerrLogo>());
    expect(find.text('heerr'), findsOneWidget);
    expect(find.byTooltip('Queue'), findsOneWidget);

    // Greeting moved into the body.
    final Finder greeting = find.byWidgetPredicate((Widget w) =>
        w is Text &&
        w.data != null &&
        w.data!.startsWith('Good ') &&
        !w.data!.contains('heerr'));
    expect(greeting, findsOneWidget);
  });

  testWidgets('body renders search bar, Quick Access and Recently Added',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _homeOverrides(newest: <Album>[
      _album('al-1', 'Fresh Album', artist: 'Fresh Artist'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Search your library + online'), findsOneWidget);
    expect(find.byType(QuickAccessRow), findsOneWidget);
    expect(find.byType(RecentlyAddedSection), findsOneWidget);
    expect(find.text('Fresh Album'), findsOneWidget);
    // Legacy sections are gone.
    expect(find.text('Jump back in'), findsNothing);
    expect(find.text('Most played'), findsNothing);
    expect(find.text('Picked for you'), findsNothing);
  });

  testWidgets(
    'regression: with a live track, hero card AND all sections render '
    '(the unbounded-height card used to kill everything below it)',
    (WidgetTester tester) async {
      const MediaItem item = MediaItem(
        id: 'http://stream/1',
        title: 'Live Track',
        artist: 'Artist',
        duration: Duration(minutes: 3),
      );
      await tester.pumpWidget(_wrap(overrides: <Override>[
        ..._homeOverrides(newest: <Album>[
          _album('al-1', 'Fresh Album', artist: 'Fresh Artist'),
        ]),
        playerSnapshotProvider.overrideWith(
          (Ref<AsyncValue<PlayerSnapshot>> ref) =>
              Stream<PlayerSnapshot>.value(PlayerSnapshot(
            item: item,
            state: PlaybackState(), // paused — restored-queue cold start
          )),
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE LISTENING'), findsOneWidget);
      expect(find.text('Live Track'), findsOneWidget);
      expect(find.byType(QuickAccessRow), findsOneWidget);
      expect(find.byType(RecentlyAddedSection), findsOneWidget);
      expect(find.text('Fresh Album'), findsOneWidget);
    },
  );

  testWidgets(
    'empty newest + idle player → empty-state replaces Recently Added',
    (WidgetTester tester) async {
      await tester.pumpWidget(
          _wrap(overrides: _homeOverrides(newest: <Album>[])));
      await tester.pumpAndSettle();

      expect(find.text('Nothing here yet'), findsOneWidget);
      // The section widget is swapped out entirely. (Plain-text matching
      // would false-positive on the Quick Access card's own "Recently
      // Added" title.)
      expect(find.byType(RecentlyAddedSection), findsNothing);
    },
  );

  testWidgets(
    'tapping a Recently Added row routes to /library/album/:id',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: _homeOverrides(newest: <Album>[
        _album('r-7', 'Recent', artist: 'Ra'),
      ])));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(find.text('album-r-7'), findsOneWidget);
    },
  );

  testWidgets(
    'pull-to-refresh re-fetches the newest provider',
    (WidgetTester tester) async {
      int fetchCount = 0;
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeNewestProvider.overrideWith((_) async {
          fetchCount += 1;
          return <Album>[_album('al-1', 'A', artist: 'B')];
        }),
        downloadedSongsProvider.overrideWith((_) async => <Song>[]),
      ]));
      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      final RefreshIndicator indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await indicator.onRefresh();
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'tapping the Queue icon in the AppBar routes to /queue',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: _homeOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Queue'));
      await tester.pumpAndSettle();

      expect(find.text('Queue page'), findsOneWidget);
    },
  );

  group('Profile entry point + nickname greeting (#37)', () {
    testWidgets('AppBar shows a profile avatar that routes to /profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: _homeOverrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-profile-avatar')));
      await tester.pumpAndSettle();

      expect(find.text('Profile page'), findsOneWidget);
    });

    testWidgets('greeting block shows two lines with the nickname',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        ..._homeOverrides(),
        profileMetaNotifierProvider.overrideWith(() => _StubMeta('Al')),
      ]));
      await tester.pumpAndSettle();

      // Line 1: "<greeting>," — line 2: "<nickname> <wave>".
      final Finder line1 = find.byWidgetPredicate((Widget w) =>
          w is Text &&
          w.data != null &&
          w.data!.startsWith('Good ') &&
          w.data!.endsWith(','));
      expect(line1, findsOneWidget);
      expect(find.text('Al \u{1F44B}'), findsOneWidget);
    });

    testWidgets('greeting block is a single plain line without a nickname',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        ..._homeOverrides(),
        profileMetaNotifierProvider.overrideWith(() => _StubMeta(null)),
      ]));
      await tester.pumpAndSettle();

      final Finder greeting = find.byWidgetPredicate((Widget w) =>
          w is Text &&
          w.data != null &&
          <String>['Good morning', 'Good afternoon', 'Good evening']
              .contains(w.data));
      expect(greeting, findsOneWidget);
      expect(find.textContaining('\u{1F44B}'), findsNothing);
    });
  });

  group('Network error state (#45)', () {
    List<Override> failing({void Function()? onFetch}) => <Override>[
          homeNewestProvider.overrideWith((_) async {
            onFetch?.call();
            throw const SocketException('no network');
          }),
          downloadedSongsProvider.overrideWith((_) async => <Song>[]),
        ];

    testWidgets("newest fails → 'Can't reach server' shown",
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: failing()));
      await tester.pumpAndSettle();

      expect(find.text("Can't reach server"), findsOneWidget);
      expect(find.text('Check that Tailscale is connected.'), findsOneWidget);
      expect(find.byKey(const Key('home-retry-button')), findsOneWidget);
    });

    testWidgets('tapping Retry re-fetches the provider',
        (WidgetTester tester) async {
      int fetchCount = 0;
      await tester.pumpWidget(
          _wrap(overrides: failing(onFetch: () => fetchCount++)));
      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      await tester.tap(find.byKey(const Key('home-retry-button')));
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThanOrEqualTo(2));
    });

    testWidgets('error state is scrollable (RefreshIndicator still works)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: failing()));
      await tester.pumpAndSettle();

      // The RefreshIndicator wraps _HomeBody; even in the error state the
      // body must expose a scrollable so pull-to-refresh is reachable.
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
    });
  });
}
