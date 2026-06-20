import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/router.dart';
import 'package:heerr/screens/auth/login_screen.dart';
import 'package:heerr/screens/home/home_screen.dart';
import 'package:heerr/theme.dart';

import 'support/cred_test_support.dart';

// In-memory fake for `flutter_secure_storage`. Needed because the real
// SettingsScreen (B3) reads the profile registry at build time → which hits
// the platform channel; widget tests don't have one and hang in
// `pumpAndSettle`.
class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Widget _bootApp() {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> _) => _NoopStorage()),
    ],
    child: MaterialApp.router(
      theme: heerrDarkTheme(),
      routerConfig: buildHeerrRouter(),
    ),
  );
}

// Returns the active screen's AppBar title by reading the Scaffold's
// AppBar widget — more robust than `find.text(...)` because the same label
// can appear in body text and tab labels.
String _activeTitle(WidgetTester tester) {
  final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
  final Text title = bar.title! as Text;
  return title.data!;
}

void main() {
  testWidgets('boots on the Home route by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    // Home screen renders a time-of-day greeting in the AppBar title.
    final String title = _activeTitle(tester);
    expect(
      <String>['Good morning', 'Good afternoon', 'Good evening'],
      contains(title),
      reason: 'expected the Home screen greeting in the AppBar title',
    );
  });

  testWidgets('bottom nav has Home, Library, Downloads, Settings tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    final NavigationBar nav = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(nav.destinations, hasLength(4));
    for (final String label in <String>[
      'Home',
      'Library',
      'Downloads',
      'Settings',
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: 'expected "$label" in bottom nav',
      );
    }
  });

  testWidgets('Library tab renders the Artists / Albums / Playlists sub-tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Library'),
      ),
    );
    await tester.pumpAndSettle();

    // The sub-tab labels live inside the AppBar's TabBar — distinct from
    // the bottom NavigationBar's labels.
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Artists')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Albums')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.text('Playlists')),
      findsOneWidget,
    );
  });

  testWidgets('tapping the Queue icon in the Home AppBar navigates to Queue', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Queue'));
    await tester.pumpAndSettle();

    expect(_activeTitle(tester), 'Queue');
  });

  testWidgets('tapping the Settings tab navigates to the Settings screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_activeTitle(tester), 'Settings');
  });

  testWidgets('navigation round-trip: Settings → Home returns to Home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_activeTitle(tester), 'Settings');

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      <String>['Good morning', 'Good afternoon', 'Good evening'],
      contains(_activeTitle(tester)),
    );
  });

  testWidgets('uses Material 3 dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).useMaterial3, isTrue);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  test('Routes helpers produce expected URL shapes for library detail', () {
    expect(Routes.libraryArtist('ar-1'), '/library/artist/ar-1');
    expect(Routes.libraryAlbum('al-2'), '/library/album/al-2');
    expect(Routes.libraryPlaylist('pl-3'), '/library/playlist/pl-3');
  });

  group('greetingForHour', () {
    test('5..11 → Good morning', () {
      for (final int h in <int>[5, 6, 9, 11]) {
        expect(greetingForHour(h), 'Good morning', reason: 'hour=$h');
      }
    });
    test('12..17 → Good afternoon', () {
      for (final int h in <int>[12, 13, 15, 17]) {
        expect(greetingForHour(h), 'Good afternoon', reason: 'hour=$h');
      }
    });
    test('18..23 → Good evening', () {
      for (final int h in <int>[18, 21, 23]) {
        expect(greetingForHour(h), 'Good evening', reason: 'hour=$h');
      }
    });
    test('0..4 → Good evening', () {
      for (final int h in <int>[0, 2, 4]) {
        expect(greetingForHour(h), 'Good evening', reason: 'hour=$h');
      }
    });
  });

  group('_ShellScaffold lifecycle wiring', () {
    Future<void> sendLifecycle(WidgetTester tester, String state) async {
      final ByteData? msg = const StringCodec().encodeMessage(state);
      await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage('flutter/lifecycle', msg, (_) {});
    }

    testWidgets('paused → calls pause() on OfflineSync', (
      WidgetTester tester,
    ) async {
      final _StubSync stub = _StubSync();
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          secureStorageProvider
              .overrideWith((Ref<SecureStorage> _) => _NoopStorage()),
          offlineSyncProvider.overrideWith(() => stub),
        ],
        child: MaterialApp.router(
          theme: heerrDarkTheme(),
          routerConfig: buildHeerrRouter(),
        ),
      ));
      await tester.pumpAndSettle();
      // The microtask in _ShellScaffoldState may pre-touch the provider —
      // we only care about counts AFTER the lifecycle event.
      stub.resetCounts();

      await sendLifecycle(tester,'AppLifecycleState.paused');
      await tester.pumpAndSettle();

      expect(stub.pauseCalls, greaterThanOrEqualTo(1));
      expect(stub.resumeCalls, 0);
    });

    testWidgets('resumed → calls resume() on OfflineSync', (
      WidgetTester tester,
    ) async {
      final _StubSync stub = _StubSync();
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          secureStorageProvider
              .overrideWith((Ref<SecureStorage> _) => _NoopStorage()),
          offlineSyncProvider.overrideWith(() => stub),
        ],
        child: MaterialApp.router(
          theme: heerrDarkTheme(),
          routerConfig: buildHeerrRouter(),
        ),
      ));
      await tester.pumpAndSettle();
      stub.resetCounts();

      await sendLifecycle(tester,'AppLifecycleState.resumed');
      await tester.pumpAndSettle();

      expect(stub.resumeCalls, greaterThanOrEqualTo(1));
    });
  });

  group('A2 — redirect reacts to registry changes via refreshListenable', () {
    testWidgets('removing the active profile redirects to /login with no '
        'manual navigation', (WidgetTester tester) async {
      initPrefsMock();
      final _MapStorage store = _MapStorage();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
          // Neutralize offline sync so the shell's init microtask is inert.
          offlineSyncProvider.overrideWith(() => _StubSync()),
        ],
      );
      addTearDown(container.dispose);

      // Seed one active profile. Empty URLs keep Home network-free (the
      // dio clients short-circuit on an empty base, same as the signed-out
      // path) so `pumpAndSettle` doesn't wait on real HTTP.
      final ProfileRegistry reg =
          container.read(profileRegistryProvider.notifier);
      await reg.addProfile(
        testProfile(id: 'p1', heerrBaseUrl: '', navidromeBaseUrl: ''),
      );
      await reg.setActive('p1');
      await container.read(profileRegistryProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: heerrDarkTheme(),
            routerConfig: buildHeerrRouter(container: container),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Logged in → Home is shown, not Login.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Remove the active profile WITHOUT navigating. The refreshListenable
      // must drive the redirect to /login on its own (pre-A2 this only
      // happened on the next navigation event).
      await reg.removeProfile('p1');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}

// Persisting in-memory secure storage — unlike `_NoopStorage` it remembers
// writes, so the profile registry round-trips (needed by the A2 redirect test).
class _MapStorage implements SecureStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _StubSync extends OfflineSync {
  int pauseCalls = 0;
  int resumeCalls = 0;

  void resetCounts() {
    pauseCalls = 0;
    resumeCalls = 0;
  }

  @override
  Future<OfflineSyncStatus> build() async {
    return (
      running: false,
      targetCount: 0,
      readyCount: 0,
      failedCount: 0,
      lastError: null,
      lastTickAt: null,
    );
  }

  @override
  void pause() {
    pauseCalls += 1;
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
  }

  @override
  Future<OfflineSyncResult> syncNow() async {
    return (
      downloadedCount: 0,
      failedCount: 0,
      sweptCount: 0,
      error: null,
    );
  }
}
