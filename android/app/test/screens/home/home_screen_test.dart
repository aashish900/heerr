import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/profile_meta.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/home/home_providers.dart';
import 'package:heerr/providers/profiles/profile_meta.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/screens/home/home_screen.dart';
import 'package:heerr/widgets/home_grid_tile.dart';
import 'package:heerr/widgets/home_section.dart';

/// Recording double for [Recommendations] — Home reads the notifier for the
/// section refresh button and the mount-time [Recommendations.refreshIfStale].
class _StubRecs extends Recommendations {
  _StubRecs([this._tracks = const <RecommendedTrack>[]]);
  final List<RecommendedTrack> _tracks;
  int refreshCalls = 0;
  int refreshIfStaleCalls = 0;

  @override
  Future<List<RecommendedTrack>> build() async => _tracks;

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  void refreshIfStale({Duration maxAge = const Duration(minutes: 30)}) {
    refreshIfStaleCalls++;
  }
}

// Minimal router with a Home root + a dummy /library/album/:id sink so
// `context.push(Routes.libraryAlbum(...))` doesn't blow up on tap.
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _testRouter(),
    ),
  );
}

Album _album(String id, String name, {String? artist}) {
  return Album(id: id, name: name, artist: artist);
}

class _StubMeta extends ProfileMetaNotifier {
  _StubMeta(this._nickname);
  final String? _nickname;

  @override
  Future<ProfileMeta> build() async => ProfileMeta(nickname: _nickname);
}

void main() {
  testWidgets('renders greeting in AppBar', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: <Override>[
      homeRecentProvider.overrideWith((_) async => <Album>[]),
      homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
      homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
      homeRecommendationsProvider.overrideWith(
        (_) async => (
          tracks: <RecommendedTrack>[],
          isFallback: true,
        ),
      ),
    ]));
    await tester.pumpAndSettle();

    final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
    final Text title = bar.title! as Text;
    expect(
      <String>['Good morning', 'Good afternoon', 'Good evening'],
      contains(title.data!),
    );
    expect(find.byTooltip('Queue'), findsOneWidget);
  });

  testWidgets(
    'recent albums render as a 2-col quick-access grid (max 6)',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith(
          (_) async => List<Album>.generate(
              8, (int i) => _album('al-$i', 'Album $i', artist: 'Artist $i')),
        ),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async =>
              (tracks: <RecommendedTrack>[], isFallback: false),
        ),
      ]));
      await tester.pumpAndSettle();

      // QuickAccessGrid caps at 6 items.
      final Iterable<HomeGridTile> tiles =
          tester.widgetList<HomeGridTile>(find.byType(HomeGridTile));
      expect(tiles, hasLength(6));
      // Tiles render album names — "Album 0"..."Album 5" are present.
      expect(find.text('Album 0'), findsWidgets);
      expect(find.text('Album 5'), findsWidgets);
    },
  );

  testWidgets(
    'recent + frequent populate "Jump back in" and "Most played" sections',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[
              _album('r-1', 'Recent Album', artist: 'R Artist'),
            ]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[
              _album('f-1', 'Top Album', artist: 'F Artist'),
            ]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async =>
              (tracks: <RecommendedTrack>[], isFallback: false),
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Jump back in'), findsOneWidget);
      expect(find.text('Most played'), findsOneWidget);
      // Two HomeSections rendered (one per non-empty section).
      expect(find.byType(HomeSection), findsNWidgets(2));
    },
  );

  testWidgets(
    'empty recent → grid falls back to recommendations '
    '(or the empty-state when both are empty)',
    (WidgetTester tester) async {
      // Both recent and recs empty → empty-state title visible.
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async =>
              (tracks: <RecommendedTrack>[], isFallback: true),
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
    },
  );

  testWidgets(
    'empty recent + non-empty recs → grid is populated from recs',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (
            tracks: List<RecommendedTrack>.generate(
                4,
                (int i) => RecommendedTrack(
                      title: 'Rec $i',
                      artist: 'A $i',
                      sourceUrl: '',
                    )),
            isFallback: false,
          ),
        ),
      ]));
      await tester.pumpAndSettle();

      final Iterable<HomeGridTile> tiles =
          tester.widgetList<HomeGridTile>(find.byType(HomeGridTile));
      expect(tiles, hasLength(4));
      expect(find.text('Rec 0'), findsWidgets);
      expect(find.text('Rec 3'), findsWidgets);
    },
  );

  testWidgets(
    'recommendations section header is "Picked for you" when not fallback',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[
              _album('r-1', 'Recent', artist: 'Ra'),
            ]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (
            tracks: <RecommendedTrack>[
              const RecommendedTrack(
                title: 'Rec',
                artist: 'RA',
                sourceUrl: 'https://music.youtube.com/watch?v=xxx',
              ),
            ],
            isFallback: false,
          ),
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Picked for you'), findsOneWidget);
      expect(find.text('Discover'), findsNothing);
    },
  );

  testWidgets(
    'recommendations section header is "Discover" when fallback',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[
              _album('r-1', 'Recent', artist: 'Ra'),
            ]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (
            tracks: <RecommendedTrack>[
              const RecommendedTrack(
                title: 'Random Song',
                artist: 'Random Artist',
                sourceUrl: '',
                inLibrary: true,
                subsonicSongId: 'rs-1',
              ),
            ],
            isFallback: true,
          ),
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Picked for you'), findsNothing);
    },
  );

  testWidgets(
    'tapping an album in "Jump back in" routes to /library/album/:id',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[
              _album('r-7', 'Recent', artist: 'Ra'),
            ]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (tracks: <RecommendedTrack>[], isFallback: false),
        ),
      ]));
      await tester.pumpAndSettle();

      // Tap the album card title inside the Jump back in section. There
      // are two text instances ("Recent" appears in the quick-access grid
      // and the section); tap the first to drive a tap on either.
      await tester.tap(find.text('Recent').first);
      await tester.pumpAndSettle();

      expect(find.text('album-r-7'), findsOneWidget);
    },
  );

  testWidgets(
    'pull-to-refresh invalidates Home providers',
    (WidgetTester tester) async {
      int recentFetchCount = 0;
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async {
          recentFetchCount += 1;
          return <Album>[_album('al-1', 'A', artist: 'B')];
        }),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (tracks: <RecommendedTrack>[], isFallback: false),
        ),
      ]));
      await tester.pumpAndSettle();
      expect(recentFetchCount, 1);

      // Call the RefreshIndicator's onRefresh directly — robust against
      // there being multiple ListViews (the horizontal sections each have
      // one) and matches what a pull-down gesture triggers.
      final RefreshIndicator indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await indicator.onRefresh();
      await tester.pumpAndSettle();

      expect(recentFetchCount, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'tapping the Queue icon in the AppBar routes to /queue',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async =>
              (tracks: <RecommendedTrack>[], isFallback: true),
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Queue'));
      await tester.pumpAndSettle();

      expect(find.text('Queue page'), findsOneWidget);
    },
  );

  group('Profile entry point + nickname greeting (#37)', () {
    List<Override> emptyHome() => <Override>[
          homeRecentProvider.overrideWith((_) async => <Album>[]),
          homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
          homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
          homeRecommendationsProvider.overrideWith(
            (_) async => (tracks: <RecommendedTrack>[], isFallback: true),
          ),
          recommendationsProvider.overrideWith(_StubRecs.new),
        ];

    testWidgets('AppBar shows a profile avatar that routes to /profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: emptyHome()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-profile-avatar')));
      await tester.pumpAndSettle();

      expect(find.text('Profile page'), findsOneWidget);
    });

    testWidgets('greeting appends the nickname when one is set',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        ...emptyHome(),
        profileMetaNotifierProvider.overrideWith(() => _StubMeta('Al')),
      ]));
      await tester.pumpAndSettle();

      final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
      final String title = (bar.title! as Text).data!;
      expect(title, endsWith(', Al'));
    });

    testWidgets('greeting stays plain without a nickname',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        ...emptyHome(),
        profileMetaNotifierProvider.overrideWith(() => _StubMeta(null)),
      ]));
      await tester.pumpAndSettle();

      final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
      final String title = (bar.title! as Text).data!;
      expect(
        <String>['Good morning', 'Good afternoon', 'Good evening'],
        contains(title),
      );
    });
  });

  group('Network error state (#45)', () {
    List<Override> allFailing() => <Override>[
          homeRecentProvider.overrideWith(
              (_) async => throw const SocketException('no network')),
          homeMostPlayedProvider.overrideWith(
              (_) async => throw const SocketException('no network')),
          homeRandomSongsProvider.overrideWith(
              (_) async => throw const SocketException('no network')),
          homeRecommendationsProvider.overrideWith(
              (_) async => throw const SocketException('no network')),
          recommendationsProvider.overrideWith(_StubRecs.new),
        ];

    testWidgets("all providers fail → 'Can't reach server' shown",
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: allFailing()));
      await tester.pumpAndSettle();

      expect(find.text("Can't reach server"), findsOneWidget);
      expect(find.text('Check that Tailscale is connected.'), findsOneWidget);
    });

    testWidgets('all providers fail → Retry button present',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: allFailing()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-retry-button')), findsOneWidget);
    });

    testWidgets('tapping Retry re-fetches providers',
        (WidgetTester tester) async {
      int recentFetchCount = 0;
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async {
          recentFetchCount++;
          throw const SocketException('no network');
        }),
        homeMostPlayedProvider.overrideWith(
            (_) async => throw const SocketException('no network')),
        homeRandomSongsProvider.overrideWith(
            (_) async => throw const SocketException('no network')),
        homeRecommendationsProvider.overrideWith(
            (_) async => throw const SocketException('no network')),
        recommendationsProvider.overrideWith(_StubRecs.new),
      ]));
      await tester.pumpAndSettle();
      expect(recentFetchCount, 1);

      await tester.tap(find.byKey(const Key('home-retry-button')));
      await tester.pumpAndSettle();

      expect(recentFetchCount, greaterThanOrEqualTo(2));
    });

    testWidgets('error state is scrollable (RefreshIndicator still works)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: allFailing()));
      await tester.pumpAndSettle();

      // The RefreshIndicator wraps _HomeBody; even in the error state the
      // body must expose a scrollable so pull-to-refresh is reachable.
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
    });
  });

  group('For You refresh (#38)', () {
    testWidgets('Picked for you header shows a refresh icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (
            tracks: <RecommendedTrack>[
              const RecommendedTrack(
                title: 'Rec',
                artist: 'RA',
                sourceUrl: 'https://music.youtube.com/watch?v=xxx',
              ),
            ],
            isFallback: false,
          ),
        ),
        recommendationsProvider.overrideWith(_StubRecs.new),
      ]));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-recs-refresh')), findsOneWidget);
    });

    testWidgets('tapping the section refresh triggers recommendations refresh',
        (WidgetTester tester) async {
      final _StubRecs stub = _StubRecs();
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (
            tracks: <RecommendedTrack>[
              const RecommendedTrack(
                title: 'Rec',
                artist: 'RA',
                sourceUrl: 'https://music.youtube.com/watch?v=xxx',
              ),
            ],
            isFallback: false,
          ),
        ),
        recommendationsProvider.overrideWith(() => stub),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-recs-refresh')));
      await tester.pump();

      expect(stub.refreshCalls, 1);
    });

    testWidgets('Discover (fallback) refresh also re-fetches random songs',
        (WidgetTester tester) async {
      int randomFetches = 0;
      final _StubRecs stub = _StubRecs(); // empty → fallback path
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async {
          randomFetches++;
          return <Song>[
            const Song(id: 's-1', title: 'Random Song', artist: 'Random A'),
          ];
        }),
        // Real homeRecommendationsProvider: empty recs → fallback branch
        // watches homeRandomSongsProvider, so invalidating it re-fetches.
        recommendationsProvider.overrideWith(() => stub),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Discover'), findsOneWidget);
      expect(randomFetches, 1);

      await tester.tap(find.byKey(const Key('home-recs-refresh')));
      await tester.pumpAndSettle();

      expect(stub.refreshCalls, 1);
      // The invalidation cascades through homeRecommendationsProvider's own
      // rebuild, so the exact count varies — the contract is "re-fetched".
      expect(randomFetches, greaterThanOrEqualTo(2));
    });

    testWidgets('Home mount fires refreshIfStale',
        (WidgetTester tester) async {
      final _StubRecs stub = _StubRecs();
      await tester.pumpWidget(_wrap(overrides: <Override>[
        homeRecentProvider.overrideWith((_) async => <Album>[]),
        homeMostPlayedProvider.overrideWith((_) async => <Album>[]),
        homeRandomSongsProvider.overrideWith((_) async => const <Never>[]),
        homeRecommendationsProvider.overrideWith(
          (_) async => (tracks: <RecommendedTrack>[], isFallback: true),
        ),
        recommendationsProvider.overrideWith(() => stub),
      ]));
      await tester.pumpAndSettle();

      expect(stub.refreshIfStaleCalls, 1);
    });
  });
}
