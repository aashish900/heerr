import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';
import 'package:heerr/screens/servers_screen.dart';
import 'package:heerr/screens/settings_screen.dart';

class _InMemoryStorage implements SecureStorage {
  _InMemoryStorage([Map<String, String>? seed])
    : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  Map<String, String> get snapshot =>
      Map<String, String>.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

Widget _wrap(List<Override> overrides) {
  final GoRouter router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (BuildContext c, GoRouterState s) => const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'servers',
            builder: (BuildContext c, GoRouterState s) => const ServersScreen(),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Pumps a short fixed budget instead of pumpAndSettle — the offline
/// section watches multiple AsyncProviders whose initial loads chain
/// through path_provider; pumpAndSettle's "no frames scheduled" idle
/// check never trips because there are platform-channel-backed
/// futures pending in the test runner.
Future<void> _pumpForBuild(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Settings screen lists a "Servers" entry', (
    WidgetTester tester,
  ) async {
    final SecureStorage store = _InMemoryStorage();
    await tester.pumpWidget(_wrap(<Override>[
      secureStorageProvider.overrideWithValue(store),
    ]));
    await _pumpForBuild(tester);
    expect(find.text('Servers'), findsOneWidget);
  });

  group('Offline downloads section', () {
    testWidgets('renders master switch + sub-controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(<Override>[
        secureStorageProvider.overrideWithValue(_InMemoryStorage()),
      ]));
      await _pumpForBuild(tester);
      expect(find.text('Offline downloads'), findsAtLeast(1));
      expect(find.text('WiFi only'), findsOneWidget);
      expect(find.text('Sync interval'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Clear all downloads'), findsOneWidget);
    });

    testWidgets('master switch toggle persists to settings', (
      WidgetTester tester,
    ) async {
      final _InMemoryStorage store = _InMemoryStorage();
      await tester.pumpWidget(_wrap(<Override>[
        secureStorageProvider.overrideWithValue(store),
      ]));
      await _pumpForBuild(tester);

      // First SwitchListTile is the master.
      await tester.tap(find.byType(SwitchListTile).first);
      await _pumpForBuild(tester);

      expect(store.snapshot['offline_enabled'], 'true');
    });

    testWidgets('Clear all opens confirmation dialog with Cancel/Clear', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(<Override>[
        secureStorageProvider.overrideWithValue(_InMemoryStorage(
          <String, String>{'offline_enabled': 'true'},
        )),
      ]));
      await _pumpForBuild(tester);

      await tester.tap(find.text('Clear all downloads'));
      await _pumpForBuild(tester);

      expect(find.text('Clear all downloads?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });
  });

  group('OfflineSettings defaults', () {
    test('reads default off+wifi-on+15min from fresh storage', () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWithValue(_InMemoryStorage()),
        ],
      );
      addTearDown(c.dispose);
      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);
      expect(v.enabled, isFalse);
      expect(v.wifiOnly, isTrue);
      expect(v.pollIntervalMinutes, 15);
    });

    test('round-trip via setEnabled persists then re-reads', () async {
      final _InMemoryStorage store = _InMemoryStorage();
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      await c.read(offlineSettingsProvider.future);
      await c.read(offlineSettingsProvider.notifier).setEnabled(true);
      final SettingsValue settings =
          await c.read(settingsProvider.future);
      expect(settings.offlineEnabled, isTrue);
      expect(store.snapshot['offline_enabled'], 'true');
    });
  });
}
