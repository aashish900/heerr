import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/library/library_filters.dart';
import 'package:heerr/widgets/library_filter_chips.dart';

Widget _wrap(LibraryTab tab, {ProviderContainer? container}) {
  final Widget app = MaterialApp(
    home: Scaffold(body: LibraryFilterChips(tab: tab)),
  );
  if (container == null) return ProviderScope(child: app);
  return UncontrolledProviderScope(container: container, child: app);
}

void main() {
  testWidgets('albums tab renders default sort label + Downloaded chip',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(LibraryTab.albums));
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.byKey(const Key('library-filter-icon')), findsOneWidget);
  });

  testWidgets('sort chip opens the sheet; picking an option updates state',
      (WidgetTester tester) async {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(LibraryTab.albums, container: c));

    await tester.tap(find.byKey(const Key('library-sort-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsOneWidget);
    // All album options listed.
    expect(find.text('A–Z'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(c.read(albumSortNotifierProvider), AlbumSort.year);
    // Chip label follows the selection.
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Recently Added'), findsNothing);
  });

  testWidgets('artists tab lists artist sort options',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(LibraryTab.artists));
    await tester.tap(find.byKey(const Key('library-sort-chip')));
    await tester.pumpAndSettle();
    expect(find.text('Z–A'), findsOneWidget);
  });

  testWidgets('Downloaded chip toggles the per-tab provider',
      (WidgetTester tester) async {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(LibraryTab.playlists, container: c));

    await tester.tap(find.byKey(const Key('library-downloaded-chip')));
    await tester.pump();
    expect(c.read(downloadedOnlyNotifierProvider(LibraryTab.playlists)),
        isTrue);
    // Other tabs unaffected.
    expect(
        c.read(downloadedOnlyNotifierProvider(LibraryTab.albums)), isFalse);

    await tester.tap(find.byKey(const Key('library-downloaded-chip')));
    await tester.pump();
    expect(c.read(downloadedOnlyNotifierProvider(LibraryTab.playlists)),
        isFalse);
  });
}
