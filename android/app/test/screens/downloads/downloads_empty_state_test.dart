import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/server_status.dart';
import 'package:heerr/router.dart';
import 'package:heerr/screens/downloads/downloads_screen.dart';

import '../../support/cred_test_support.dart';

// DL8 (DOWNLOADSSCREEN.md §6): the unified empty state replaces
// sync-activity/tabs/chips/content when nothing is downloaded or marked;
// the hero + quick actions above it still render.

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StaticServerStatus extends ServerStatusNotifier {
  @override
  Future<ServerStatus> build() async =>
      (online: false, errorMessage: null, checkedAt: DateTime.now());
}

class _StaticOfflineSync extends OfflineSync {
  @override
  Future<OfflineSyncStatus> build() async => (
        running: false,
        targetCount: 0,
        readyCount: 0,
        failedCount: 0,
        lastError: null,
        lastTickAt: null,
      );
}

List<Override> _baseOverrides(OfflineManifest manifest) => <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
      activeProfileOverride(),
      offlineManifestProvider.overrideWith((_) async => manifest),
      serverStatusNotifierProvider.overrideWith(_StaticServerStatus.new),
      offlineSyncProvider.overrideWith(_StaticOfflineSync.new),
    ];

void main() {
  testWidgets('empty manifest shows the unified empty state, not tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(const OfflineManifest()),
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing available offline yet.'), findsOneWidget);
    expect(find.text('Browse Library'), findsOneWidget);
    expect(find.text('Songs'), findsNothing);
    expect(find.text('Albums'), findsNothing);
  });

  testWidgets('hero + quick actions still render on the empty path',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(const OfflineManifest()),
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home Server'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.text('Manage Storage'), findsOneWidget);
  });

  testWidgets('Browse Library navigates to the Library route',
      (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) => const DownloadsScreen(),
        ),
        GoRoute(
          path: Routes.library,
          builder: (BuildContext c, GoRouterState s) =>
              const Scaffold(body: Text('Library Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(const OfflineManifest()),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Browse Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse Library'));
    await tester.pumpAndSettle();

    expect(find.text('Library Screen'), findsOneWidget);
  });

  testWidgets('non-empty manifest shows the tabs, not the empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(
          const OfflineManifest(markedAlbums: <String>{'a1'}),
        ),
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing available offline yet.'), findsNothing);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
  });
}
