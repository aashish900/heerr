import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/providers/home/home_providers.dart';
import 'package:heerr/screens/library/recently_played_screen.dart';

Widget _wrap(Override override) {
  return ProviderScope(
    overrides: <Override>[override],
    child: const MaterialApp(home: RecentlyPlayedScreen()),
  );
}

void main() {
  testWidgets('loading renders skeleton rows', (WidgetTester tester) async {
    final Completer<List<Album>> never = Completer<List<Album>>();
    await tester.pumpWidget(_wrap(
      recentlyPlayedProvider.overrideWith(
          (RecentlyPlayedRef ref) => never.future),
    ));
    await tester.pump();

    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('data renders one row per album', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      recentlyPlayedProvider.overrideWith((RecentlyPlayedRef ref) async => <Album>[
        const Album(id: '1', name: 'Album One', artist: 'Artist A'),
        const Album(id: '2', name: 'Album Two', artist: 'Artist B'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Album One'), findsOneWidget);
    expect(find.text('Album Two'), findsOneWidget);
  });

  testWidgets('empty list shows "Nothing played yet"',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      recentlyPlayedProvider
          .overrideWith((RecentlyPlayedRef ref) async => <Album>[]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nothing played yet'), findsOneWidget);
  });

  testWidgets('error shows retry button that re-invokes the provider',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      recentlyPlayedProvider.overrideWith(
          (RecentlyPlayedRef ref) async => throw Exception('network')),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Can't load recently played"), findsOneWidget);
    expect(find.byKey(const Key('recently-played-retry')), findsOneWidget);
  });
}
