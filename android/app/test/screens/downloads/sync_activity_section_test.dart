import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/sync_activity.dart';
import 'package:heerr/screens/downloads/sync_activity_section.dart';

// DL4: card visibility matrix per DOWNLOADSSCREEN.md §3 — Downloading /
// Queued always show when non-zero; the third slot is Waiting-for-Wi-Fi
// when the gate is holding work back, else Failed, else hidden.

Future<void> _pump(WidgetTester tester, SyncActivity activity) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        syncActivityProvider.overrideWith((_) async => activity),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SyncActivitySection()),
      ),
    ),
  );
}

void main() {
  testWidgets('nothing to report → renders nothing', (WidgetTester tester) async {
    await _pump(tester, (
      downloadingCount: 0,
      queuedCount: 0,
      failedCount: 0,
      waitingForWifi: false,
    ));
    await tester.pump();

    expect(find.text('Downloading'), findsNothing);
    expect(find.text('Queued'), findsNothing);
    expect(find.text('Waiting'), findsNothing);
    expect(find.text('Failed'), findsNothing);
  });

  testWidgets('downloading + queued + failed all shown', (WidgetTester tester) async {
    await _pump(tester, (
      downloadingCount: 2,
      queuedCount: 3,
      failedCount: 1,
      waitingForWifi: false,
    ));
    await tester.pump();

    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('2 songs'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
  });

  testWidgets('waitingForWifi takes the third slot over failed', (WidgetTester tester) async {
    await _pump(tester, (
      downloadingCount: 0,
      queuedCount: 1,
      failedCount: 2,
      waitingForWifi: true,
    ));
    await tester.pump();

    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('for Wi-Fi'), findsOneWidget);
    expect(find.text('Failed'), findsNothing);
  });
}
