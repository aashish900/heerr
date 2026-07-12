import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/router.dart';
import 'package:heerr/screens/downloads/quick_action_cards.dart';

// DL3 (Downloads "Sync Center" quick actions): Sync Now triggers the manual
// OfflineSync.syncNow() trigger and reports the result; Manage Storage
// routes to Settings, where the offline/storage controls already live.

class _StubSync extends OfflineSync {
  static int syncNowCalls = 0;
  static OfflineSyncResult result = (
    downloadedCount: 2,
    failedCount: 0,
    sweptCount: 0,
    error: null,
  );

  static void reset() {
    syncNowCalls = 0;
    result = (downloadedCount: 2, failedCount: 0, sweptCount: 0, error: null);
  }

  @override
  Future<OfflineSyncStatus> build() async => (
        running: false,
        targetCount: 0,
        readyCount: 0,
        failedCount: 0,
        lastError: null,
        lastTickAt: null,
      );

  @override
  Future<OfflineSyncResult> syncNow() async {
    syncNowCalls++;
    return result;
  }
}

void main() {
  setUp(_StubSync.reset);

  testWidgets('Sync Now taps trigger syncNow and show a result snackbar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          offlineSyncProvider.overrideWith(_StubSync.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QuickActionCards()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync Now'));
    await tester.pumpAndSettle();

    expect(_StubSync.syncNowCalls, 1);
    expect(find.textContaining('Synced: 2 downloaded'), findsOneWidget);
  });

  testWidgets('Manage Storage tap navigates to Settings',
      (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) =>
              const Scaffold(body: QuickActionCards()),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (BuildContext c, GoRouterState s) =>
              const Scaffold(body: Text('Settings Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          offlineSyncProvider.overrideWith(_StubSync.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Manage Storage'));
    await tester.pumpAndSettle();

    expect(find.text('Settings Screen'), findsOneWidget);
  });
}
