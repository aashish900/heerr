import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/downloads_filters.dart';
import 'package:heerr/screens/downloads/downloads_filter_chips.dart';

// DL5: sort chip on every tab; Lossless + Today toggles on Songs only.

Future<void> _pump(WidgetTester tester, DownloadsTab tab) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: DownloadsFilterChips(tab: tab)),
      ),
    ),
  );
}

void main() {
  testWidgets('Songs tab shows sort + Lossless + Today chips',
      (WidgetTester tester) async {
    await _pump(tester, DownloadsTab.songs);

    expect(find.byKey(const Key('downloads-sort-chip')), findsOneWidget);
    expect(find.byKey(const Key('downloads-lossless-chip')), findsOneWidget);
    expect(find.byKey(const Key('downloads-today-chip')), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('Albums tab shows only the sort chip', (WidgetTester tester) async {
    await _pump(tester, DownloadsTab.albums);

    expect(find.byKey(const Key('downloads-sort-chip')), findsOneWidget);
    expect(find.byKey(const Key('downloads-lossless-chip')), findsNothing);
    expect(find.byKey(const Key('downloads-today-chip')), findsNothing);
  });

  testWidgets('Playlists tab shows only the sort chip', (WidgetTester tester) async {
    await _pump(tester, DownloadsTab.playlists);

    expect(find.byKey(const Key('downloads-sort-chip')), findsOneWidget);
    expect(find.byKey(const Key('downloads-lossless-chip')), findsNothing);
  });

  testWidgets('tapping the sort chip opens a sheet and picking updates the label',
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DownloadsFilterChips(tab: DownloadsTab.songs)),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('downloads-sort-chip')));
    await tester.pumpAndSettle();

    expect(find.text('Sort by'), findsOneWidget);
    await tester.tap(find.text('Largest'));
    await tester.pumpAndSettle();

    expect(
      container.read(downloadsSongSortNotifierProvider),
      DownloadsSongSort.largest,
    );
    expect(find.text('Largest'), findsOneWidget);
  });

  testWidgets('tapping Lossless toggles the provider', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DownloadsFilterChips(tab: DownloadsTab.songs)),
        ),
      ),
    );

    expect(container.read(downloadsLosslessOnlyNotifierProvider), isFalse);
    await tester.tap(find.byKey(const Key('downloads-lossless-chip')));
    await tester.pump();

    expect(container.read(downloadsLosslessOnlyNotifierProvider), isTrue);
  });
}
