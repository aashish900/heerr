import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/screens/home/quick_access_row.dart';
import 'package:heerr/theme.dart';

Widget _wrap({required List<Override> overrides}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SingleChildScrollView(child: QuickAccessRow())),
      ),
      GoRoute(
        path: '/library/recommendations',
        builder: (_, _) => const Scaffold(body: Text('RECS_SCREEN')),
      ),
      GoRoute(
        path: '/library/favorites',
        builder: (_, _) => const Scaffold(body: Text('FAVORITES_SCREEN')),
      ),
      GoRoute(
        path: '/library/recently-added',
        builder: (_, _) => const Scaffold(body: Text('RECENTLY_ADDED_SCREEN')),
      ),
      GoRoute(
        path: '/downloads',
        builder: (_, _) => const Scaffold(body: Text('DOWNLOADS_SCREEN')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      theme: heerrDarkTheme(),
      routerConfig: router,
    ),
  );
}

List<Override> _withDownloads(List<Song> songs) => <Override>[
      downloadedSongsProvider.overrideWith((_) async => songs),
    ];

Song _song(String id) => Song(id: id, title: 'Song $id');

void main() {
  testWidgets('renders the section header and all four cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _withDownloads(<Song>[])));
    await tester.pumpAndSettle();

    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Made for you'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Loved songs'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('New music'), findsOneWidget);
    // Edit affordance is deferred — must not render.
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('Offline subtitle shows the downloaded-song count',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      overrides:
          _withDownloads(<Song>[_song('a'), _song('b'), _song('c')]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('3 songs'), findsOneWidget);
  });

  testWidgets('Offline subtitle singular for one song',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _withDownloads(<Song>[_song('a')])));
    await tester.pumpAndSettle();
    expect(find.text('1 song'), findsOneWidget);
  });

  testWidgets('Offline subtitle falls back to "Downloads" on error',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: <Override>[
      downloadedSongsProvider
          .overrideWith((_) async => throw Exception('disk')),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Downloads'), findsOneWidget);
  });

  testWidgets('For You card navigates to recommendations',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _withDownloads(<Song>[])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-access-for-you')));
    await tester.pumpAndSettle();
    expect(find.text('RECS_SCREEN'), findsOneWidget);
  });

  testWidgets('Favorites card navigates to /library/favorites',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _withDownloads(<Song>[])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-access-favorites')));
    await tester.pumpAndSettle();
    expect(find.text('FAVORITES_SCREEN'), findsOneWidget);
  });

  testWidgets('Offline card navigates to /downloads',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _withDownloads(<Song>[])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-access-offline')));
    await tester.pumpAndSettle();
    expect(find.text('DOWNLOADS_SCREEN'), findsOneWidget);
  });

  testWidgets('Recently Added card navigates to /library/recently-added',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: _withDownloads(<Song>[])));
    await tester.pumpAndSettle();
    // The 4th card can sit past the right edge — bring it into view first.
    await tester.ensureVisible(
        find.byKey(const Key('quick-access-recently-added')));
    await tester.tap(find.byKey(const Key('quick-access-recently-added')));
    await tester.pumpAndSettle();
    expect(find.text('RECENTLY_ADDED_SCREEN'), findsOneWidget);
  });
}
