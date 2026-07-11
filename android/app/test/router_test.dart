import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_sync.dart';
import 'package:go_router/go_router.dart';
import 'package:heerr/models/subsonic/search_result3.dart';
import 'package:heerr/providers/library/combined_search.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/router.dart';
import 'package:heerr/screens/auth/login_screen.dart';
import 'package:heerr/screens/home/home_screen.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/widgets/heerr_logo.dart';

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

Widget _bootApp({List<Override> extraOverrides = const <Override>[]}) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> _) => _NoopStorage()),
      ...extraOverrides,
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

/// Home no longer titles its AppBar with the greeting — the redesign puts
/// the brand logo there (HOMESCREEN.md task 1). "We're on Home" is asserted
/// via the logo widget in the AppBar title slot.
void _expectOnHome(WidgetTester tester, {String? reason}) {
  final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
  expect(bar.title, isA<HeerrLogo>(), reason: reason);
}

void main() {
  testWidgets('boots on the Home route by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    // Home screen renders the brand logo in the AppBar title.
    _expectOnHome(tester,
        reason: 'expected the Home screen logo in the AppBar title');
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
    _expectOnHome(tester);
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

  group('V1 — predictable back stack', () {
    testWidgets('system back from a detail screen is not intercepted by shell', (
      WidgetTester tester,
    ) async {
      // The shell's didPopRoute must NOT intercept back when widget.location
      // is a detail path (e.g. /library/album/:id). It must yield to go_router
      // so go_router pops the detail and returns to the tab.
      await tester.pumpWidget(_bootApp());
      await tester.pumpAndSettle();

      // Navigate to Library tab, then push album detail.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Library'),
        ),
      );
      await tester.pumpAndSettle();

      // GoRouter.canPop() must be true once a detail is pushed. The shell's
      // _tabRoots guard and canPop guard both ensure we return false from
      // didPopRoute and let go_router handle the pop. We verify via canPop.
      final GoRouter router = GoRouter.of(
        tester.element(find.byType(NavigationBar)),
      );
      expect(router.canPop(), isFalse,
          reason: 'sanity: no detail pushed yet');

      // Directly push a fake album path to simulate context.push usage.
      unawaited(router.push(Routes.libraryAlbum('test-album-id')));
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue,
          reason: 'detail is stacked — canPop must be true');

      // System back: shell must yield so go_router pops the detail.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // After pop, canPop is false again (back on Library root).
      expect(router.canPop(), isFalse);
      // The Library tab bar is visible (we're back on the Library root).
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Artists')),
        findsOneWidget,
      );
    });

    testWidgets('system back from a non-Home tab returns to Home, not exit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_bootApp());
      await tester.pumpAndSettle();

      // Switch to Settings (a tab switch uses context.go → stack replace).
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_activeTitle(tester), 'Settings');

      // System back must be intercepted by the shell PopScope → route Home.
      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue, reason: 'shell should consume back off-Home');
      _expectOnHome(tester, reason: 'back from Settings should land on Home');
    });

    testWidgets('system back on Home is not consumed (app would exit)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_bootApp());
      await tester.pumpAndSettle();

      // On Home canPop is true and Home is the only shell page, so the pop
      // is not handled — the OS takes it (app exit), the desired behaviour.
      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isFalse);
    });
  });

  group('V1 — search-mode back clears the field instead of exiting', () {
    testWidgets('system back in search mode clears text + returns to browse', (
      WidgetTester tester,
    ) async {
      // Stub the combined-search result for our query so the screen renders a
      // search body without spawning the real debounce / queue-poll timers
      // (which would leak past the test as pending timers).
      await tester.pumpWidget(
        _bootApp(
          extraOverrides: <Override>[
            combinedSearchProvider('daft punk').overrideWithValue(
              const CombinedSearchResult(
                query: 'daft punk',
                library: AsyncValue<SearchResult3>.loading(),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Library tab → enter search mode → type a query.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Library'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'daft punk');
      await tester.pump();
      expect(find.text('daft punk'), findsOneWidget);

      // System back: PopScope(canPop:false) → onExit clears text + drops back
      // to the browse TabBar, rather than falling through to Home/exit.
      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('daft punk'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      // Back on the Library browse view (Artists/Albums/Playlists tabs).
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Artists')),
        findsOneWidget,
      );

      // Re-entering search shows an empty field (the query state was cleared).
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
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
