import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/router.dart';
import 'package:heerr/theme.dart';

// In-memory fake for `flutter_secure_storage`. Needed because the real
// SettingsScreen (B3) reads `settingsProvider` at build time → which hits
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
  testWidgets('boots on the Library route by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    expect(_activeTitle(tester), 'Library');
  });

  testWidgets('bottom nav has exactly three tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    final NavigationBar nav = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(nav.destinations, hasLength(3));
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Library')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Queue')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')),
      findsOneWidget,
    );
  });

  testWidgets('Library tab renders the Artists / Albums / Playlists sub-tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
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

  testWidgets('tapping the Queue tab navigates to the Queue screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    // Disambiguate from the Library sub-tab named "Queue"-… (none exists,
    // but Queue is a bottom-nav label so target the NavigationBar subtree).
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Queue'),
      ),
    );
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

  testWidgets('navigation round-trip: Settings → Library returns to Library', (
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
        matching: find.text('Library'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_activeTitle(tester), 'Library');
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
}
