import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:heerr/models/recommend_health.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/offline/offline_size_estimator.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/settings/settings_screen.dart';

/// Stub estimator that returns a fixed byte count without walking the
/// library — keeps the offline-section widget tree synchronous and avoids
/// the real provider's Subsonic / HTTP dependencies.
class _StubEstimate extends OfflineSizeEstimate {
  _StubEstimate(this._bytes);
  final int? _bytes;

  @override
  Future<int?> build() async => _bytes;

  @override
  Future<int?> refresh() async => _bytes;
}

// A1/A5: settings state is split across two stores — credentials in secure
// storage (via the profile registry), offline prefs in plain prefs. This
// fake implements both interfaces so one instance backs both providers and
// `snapshot` stays store-agnostic. See [_storage].
class _InMemoryStorage implements SecureStorage, PrefsStorage {
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

/// Overrides both storage providers with one fake — secure storage (creds)
/// and plain prefs (offline) share the same in-memory map in tests.
List<Override> _storage(_InMemoryStorage store) => <Override>[
      secureStorageProvider.overrideWithValue(store),
      prefsStorageProvider.overrideWithValue(store),
    ];

Widget _wrap(
  List<Override> overrides, {
  int? estimateBytes = 0,
  Directory? appDocsDir,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (BuildContext c, GoRouterState s) => const SettingsScreen(),
      ),
    ],
  );
  // path_provider isn't available in widget tests — every place the offline
  // module touches `getApplicationDocumentsDirectory()` would hang without
  // this override. Default to the test's systemTemp if the caller didn't
  // provide one.
  final Directory docs = appDocsDir ??
      Directory.systemTemp.createTempSync('heerr-settings-test-');
  return ProviderScope(
    overrides: <Override>[
      ...overrides,
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => docs),
      offlineSizeEstimateProvider
          .overrideWith(() => _StubEstimate(estimateBytes)),
    ],
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

/// Settings is a ListView with several rows; on the default test surface
/// (~800px tall) lazy rendering hides the tail of the list. Bumping the
/// surface ensures every section is in the tree and findable in one shot.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

/// #17: each settings section is now a collapsible [ExpansionTile] keyed
/// `settings-section-<title>` and collapsed by default (except Profiles).
/// Tap the section header to reveal its body, then let the expand animation
/// + async child builds settle.
Future<void> _expandSection(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(Key('settings-section-$title')));
  await _pumpForBuild(tester);
}

void main() {
  group('Collapsible sections (#17)', () {
    testWidgets('remaining section headers render (Downloads & Storage is flat, SE5)',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[..._storage(_InMemoryStorage())]));
      await _pumpForBuild(tester);
      expect(find.byKey(const Key('settings-section-Profiles')), findsOneWidget);
      expect(find.byKey(const Key('settings-section-Recommendations')),
          findsOneWidget);
      // Downloads & Storage was flattened in SE5 — a plain section header +
      // always-visible SettingsGroupCard, no ExpansionTile.
      expect(find.text('Downloads & Storage'), findsOneWidget);
    });

    testWidgets('Profiles expanded by default; Recommendations collapsed',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[..._storage(_InMemoryStorage())]));
      await _pumpForBuild(tester);
      // Profiles body is visible without tapping (empty registry → Add row).
      expect(find.text('Add profile'), findsOneWidget);
      // Downloads & Storage is flat (SE5) — always visible now.
      expect(find.text('WiFi only'), findsOneWidget);
      // Recommendations is still collapsible and hidden until expanded.
      expect(find.text('Engine health'), findsNothing);
    });
  });

  group('App version footer (#36)', () {
    testWidgets('renders the APK version below the sections',
        (WidgetTester tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'heerr',
        packageName: 'com.aashish.heerr',
        version: '4.1.0',
        buildNumber: '9',
        buildSignature: '',
      );
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[..._storage(_InMemoryStorage())]));
      await _pumpForBuild(tester);
      expect(find.byKey(const Key('settings-app-version')), findsOneWidget);
      expect(find.text('v4.1.0+9'), findsOneWidget);
    });
  });

  group('Offline downloads section', () {
    testWidgets('renders master switch + sub-controls', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[
        ..._storage(_InMemoryStorage()),
      ]));
      await _pumpForBuild(tester);
      // SE5: Downloads & Storage is a flat, always-visible SettingsGroupCard
      // — no expand step needed.
      expect(find.text('Offline downloads'), findsAtLeast(1));
      expect(find.text('WiFi only'), findsOneWidget);
      expect(find.text('Sync interval'), findsOneWidget);
      // Sync Now lives on the promoted Server & Sync card (SE4), not inline
      // in the Offline downloads section.
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Clear all downloads'), findsOneWidget);
      expect(find.text('Sync entire library'), findsOneWidget);
    });

    testWidgets('master switch toggle persists to settings', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      final _InMemoryStorage store = _InMemoryStorage();
      await tester.pumpWidget(_wrap(_storage(store)));
      await _pumpForBuild(tester);

      await tester.tap(find.byKey(const Key('settings-tile-offline-downloads')));
      await _pumpForBuild(tester);

      expect(store.snapshot['offline_enabled'], 'true');
    });

    testWidgets('sync-all OFF→ON opens confirmation dialog with size', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _storage(_InMemoryStorage(<String, String>{'offline_enabled': 'true'})),
        // 2 MB so the human-readable formatting hits the MB branch.
        estimateBytes: 2 * 1024 * 1024,
      ));
      await _pumpForBuild(tester);

      await tester.tap(find.byKey(const Key('settings-tile-sync-entire-library')));
      await _pumpForBuild(tester);

      expect(find.text('Sync entire library?'), findsOneWidget);
      // Dialog content quotes the size in the warning sentence.
      expect(
        find.text('This will download ~2.0 MB and may take a while. Continue?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sync'), findsOneWidget);
    });

    testWidgets('sync-all dialog Cancel keeps the switch off', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      final _InMemoryStorage store = _InMemoryStorage(
        <String, String>{'offline_enabled': 'true'},
      );
      await tester.pumpWidget(_wrap(
        _storage(store),
        estimateBytes: 1024,
      ));
      await _pumpForBuild(tester);

      await tester.tap(find.byKey(const Key('settings-tile-sync-entire-library')));
      await _pumpForBuild(tester);
      await tester.tap(find.text('Cancel'));
      await _pumpForBuild(tester);

      // No write to offline_sync_all means the key is absent (default false).
      expect(store.snapshot['offline_sync_all'], isNot('true'));
    });

    testWidgets('sync-all dialog Confirm flips offline_sync_all true', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      final _InMemoryStorage store = _InMemoryStorage(
        <String, String>{'offline_enabled': 'true'},
      );
      await tester.pumpWidget(_wrap(
        _storage(store),
        estimateBytes: 1024,
      ));
      await _pumpForBuild(tester);

      await tester.tap(find.byKey(const Key('settings-tile-sync-entire-library')));
      await _pumpForBuild(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sync'));
      // The OFF→ON confirm path is longer than other taps: dialog pop +
      // animation + setSyncAll's multi-await chain (settings save → manifest
      // cache clear). Give it extra pump cycles before asserting.
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(store.snapshot['offline_sync_all'], 'true');
    });

    testWidgets('Clear all opens confirmation dialog with Cancel/Clear', (
      WidgetTester tester,
    ) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _storage(_InMemoryStorage(<String, String>{'offline_enabled': 'true'})),
      ));
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
          ..._storage(_InMemoryStorage()),
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
        overrides: _storage(store),
      );
      addTearDown(c.dispose);
      await c.read(offlineSettingsProvider.future);
      await c.read(offlineSettingsProvider.notifier).setEnabled(true);
      final OfflineSettingsValue settings =
          await c.read(offlineSettingsProvider.future);
      expect(settings.enabled, isTrue);
      expect(store.snapshot['offline_enabled'], 'true');
    });
  });

  // -------------------------------------------------------------------------
  // Recommendations section (N5)
  // -------------------------------------------------------------------------

  group('Recommendations section', () {
    testWidgets('ok engine renders OK chip, no fallback badge, no help icon',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[
        ..._storage(_InMemoryStorage()),
        recommendHealthNotifierProvider.overrideWith(
            () => _StubHealth(const RecommendHealth(
                  engine: 'ytmusic',
                  status: 'ok',
                  fallbackActive: false,
                ))),
      ]));
      await _pumpForBuild(tester);
      await _expandSection(tester, 'Recommendations');

      expect(find.text('Engine: ytmusic'), findsOneWidget);
      expect(find.byKey(const Key('engine-chip-ok')), findsOneWidget);
      expect(find.byKey(const Key('engine-chip-degraded')), findsNothing);
      expect(find.byKey(const Key('engine-chip-fallback-active')),
          findsNothing);
      expect(find.byKey(const Key('settings-recommend-help')), findsNothing);
    });

    testWidgets('degraded engine renders Degraded chip + help icon',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[
        ..._storage(_InMemoryStorage()),
        recommendHealthNotifierProvider.overrideWith(
            () => _StubHealth(const RecommendHealth(
                  engine: 'lastfm',
                  status: 'degraded',
                  fallbackActive: false,
                ))),
      ]));
      await _pumpForBuild(tester);
      await _expandSection(tester, 'Recommendations');

      expect(find.text('Engine: lastfm'), findsOneWidget);
      expect(find.byKey(const Key('engine-chip-degraded')), findsOneWidget);
      expect(find.byKey(const Key('engine-chip-fallback-active')),
          findsNothing);
      expect(find.byKey(const Key('settings-recommend-help')), findsOneWidget);
    });

    testWidgets('fallback_active renders the Fallback active badge',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[
        ..._storage(_InMemoryStorage()),
        recommendHealthNotifierProvider.overrideWith(
            () => _StubHealth(const RecommendHealth(
                  engine: 'lastfm',
                  status: 'degraded',
                  fallbackActive: true,
                ))),
      ]));
      await _pumpForBuild(tester);
      await _expandSection(tester, 'Recommendations');

      expect(find.byKey(const Key('engine-chip-fallback-active')),
          findsOneWidget);
      expect(find.byKey(const Key('engine-chip-degraded')), findsOneWidget);
    });

    testWidgets('tapping help icon reveals inline diagnostic copy',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_wrap(<Override>[
        ..._storage(_InMemoryStorage()),
        recommendHealthNotifierProvider.overrideWith(
            () => _StubHealth(const RecommendHealth(
                  engine: 'lastfm',
                  status: 'degraded',
                  fallbackActive: true,
                ))),
      ]));
      await _pumpForBuild(tester);
      await _expandSection(tester, 'Recommendations');

      // Help text not yet visible.
      expect(find.textContaining('Primary engine probe failed'),
          findsNothing);

      await tester.tap(find.byKey(const Key('settings-recommend-help')));
      await tester.pump();
      expect(find.textContaining('Primary engine probe failed'),
          findsOneWidget);
    });
  });
}

/// Stub notifier for [recommendHealthNotifierProvider]. Wraps a fixed
/// [RecommendHealth] payload. `refreshIfStale` is a no-op so the
/// `SettingsScreen`'s post-frame refresh call doesn't trigger a real
/// HTTP fetch through the unmocked `dioClientProvider`.
class _StubHealth extends RecommendHealthNotifier {
  _StubHealth(this._value);
  final RecommendHealth _value;

  @override
  Future<RecommendHealth> build() async => _value;

  @override
  void refreshIfStale({Duration maxAge = const Duration(seconds: 60)}) {
    // No-op in tests.
  }
}
