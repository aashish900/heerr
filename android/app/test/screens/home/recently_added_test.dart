import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/providers/home/home_providers.dart';
import 'package:heerr/screens/home/recently_added_section.dart';
import 'package:heerr/screens/library/recently_added_screen.dart';
import 'package:heerr/theme.dart';

Album _album(int i) =>
    Album(id: 'al-$i', name: 'Album $i', artist: 'Artist $i');

GoRouter _router({required Widget home}) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
      GoRoute(
        path: '/library/recently-added',
        builder: (_, _) => const RecentlyAddedScreen(),
      ),
      GoRoute(
        path: '/library/album/:id',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('album-${s.pathParameters['id']}')),
      ),
    ],
  );
}

Widget _wrap({required Widget home, required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: heerrDarkTheme(),
      routerConfig: _router(home: home),
    ),
  );
}

void main() {
  group('RecentlyAddedSection', () {
    testWidgets('renders header + at most 5 rows from homeNewest',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        home: const SingleChildScrollView(child: RecentlyAddedSection()),
        overrides: <Override>[
          homeNewestProvider.overrideWith(
              (_) async => List<Album>.generate(8, _album)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recently Added'), findsOneWidget);
      expect(find.byType(RecentlyAddedRow), findsNWidgets(5));
      expect(find.text('Album 0'), findsOneWidget);
      expect(find.text('Artist 0'), findsOneWidget);
      expect(find.text('Album 5'), findsNothing);
    });

    testWidgets('hidden when the list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        home: const SingleChildScrollView(child: RecentlyAddedSection()),
        overrides: <Override>[
          homeNewestProvider.overrideWith((_) async => <Album>[]),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Recently Added'), findsNothing);
    });

    testWidgets('hidden on error', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        home: const SingleChildScrollView(child: RecentlyAddedSection()),
        overrides: <Override>[
          homeNewestProvider
              .overrideWith((_) async => throw Exception('net')),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Recently Added'), findsNothing);
    });

    testWidgets('row tap routes to the album detail',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        home: const SingleChildScrollView(child: RecentlyAddedSection()),
        overrides: <Override>[
          homeNewestProvider.overrideWith((_) async => <Album>[_album(7)]),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Album 7'));
      await tester.pumpAndSettle();
      expect(find.text('album-al-7'), findsOneWidget);
    });

    testWidgets('"See all" pushes the full screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        home: const SingleChildScrollView(child: RecentlyAddedSection()),
        overrides: <Override>[
          homeNewestProvider.overrideWith((_) async => <Album>[_album(1)]),
          recentlyAddedFullProvider.overrideWith(
              (_) async => List<Album>.generate(3, _album)),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recently-added-see-all')));
      await tester.pumpAndSettle();

      expect(find.byType(RecentlyAddedScreen), findsOneWidget);
      expect(find.byType(RecentlyAddedRow), findsNWidgets(3));
    });
  });

  group('RecentlyAddedScreen', () {
    testWidgets('lists all albums from recentlyAddedFull',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        home: const RecentlyAddedScreen(),
        overrides: <Override>[
          recentlyAddedFullProvider.overrideWith(
              (_) async => List<Album>.generate(10, _album)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recently Added'), findsOneWidget); // AppBar
      expect(find.text('Album 0'), findsOneWidget);
    });

    testWidgets('error state shows Retry which re-fetches',
        (WidgetTester tester) async {
      int fetches = 0;
      await tester.pumpWidget(_wrap(
        home: const RecentlyAddedScreen(),
        overrides: <Override>[
          recentlyAddedFullProvider.overrideWith((_) async {
            fetches++;
            throw Exception('net');
          }),
        ],
      ));
      await tester.pumpAndSettle();
      expect(fetches, 1);
      expect(find.byKey(const Key('recently-added-retry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('recently-added-retry')));
      await tester.pumpAndSettle();
      expect(fetches, greaterThanOrEqualTo(2));
    });

    testWidgets('pull-to-refresh invalidates the provider',
        (WidgetTester tester) async {
      int fetches = 0;
      await tester.pumpWidget(_wrap(
        home: const RecentlyAddedScreen(),
        overrides: <Override>[
          recentlyAddedFullProvider.overrideWith((_) async {
            fetches++;
            return <Album>[_album(1)];
          }),
        ],
      ));
      await tester.pumpAndSettle();
      expect(fetches, 1);

      final RefreshIndicator indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await indicator.onRefresh();
      await tester.pumpAndSettle();
      expect(fetches, greaterThanOrEqualTo(2));
    });
  });
}
