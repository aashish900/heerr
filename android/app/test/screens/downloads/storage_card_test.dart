import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/storage_breakdown.dart';
import 'package:heerr/screens/downloads/storage_card.dart';

// DL7: stacked storage bar + legend. Renders nothing while loading/zero.

Future<void> _pump(WidgetTester tester, StorageBreakdown b) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        storageBreakdownProvider.overrideWith((_) async => b),
      ],
      child: const MaterialApp(home: Scaffold(body: StorageCard())),
    ),
  );
}

void main() {
  testWidgets('renders nothing while total is zero', (WidgetTester tester) async {
    await _pump(tester, (music: 0, artwork: 0, lyrics: 0, cache: 0));
    await tester.pump();

    expect(find.text('Storage'), findsNothing);
  });

  testWidgets('shows the legend for non-zero categories only', (WidgetTester tester) async {
    await _pump(tester, (music: 1024 * 1024, artwork: 1024, lyrics: 0, cache: 512));
    await tester.pump();

    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Artwork'), findsOneWidget);
    expect(find.text('Lyrics'), findsNothing);
    expect(find.text('Cache'), findsOneWidget);
  });
}
