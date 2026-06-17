import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/settings/profiles_section.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = <String, String>{};
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

Profile _profile({
  required String id,
  required String name,
}) {
  final DateTime t = DateTime.utc(2026, 6, 17, 10, 0, 0);
  return Profile(
    id: id,
    displayName: name,
    heerrBaseUrl: 'http://h:8000',
    heerrBearerToken: 'tok-$id',
    navidromeBaseUrl: 'http://n:4533',
    navidromeUsername: name,
    navidromePassword: 'pw-$id',
    createdAt: t,
    lastUsedAt: t,
  );
}

Future<ProviderContainer> _seedRegistry({
  required List<Profile> profiles,
  required String? activeId,
  required _FakeSecureStorage fake,
}) async {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
    ],
  );
  await c.read(profileRegistryProvider.future);
  for (final Profile p in profiles) {
    await c.read(profileRegistryProvider.notifier).addProfile(p);
  }
  if (activeId != null) {
    await c.read(profileRegistryProvider.notifier).setActive(activeId);
  }
  return c;
}

Widget _harness(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext ctx, _) =>
            const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext ctx, _) =>
            const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext ctx, _) => const Scaffold(
          body: ProfilesSection(),
        ),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ProfilesSection', () {
    testWidgets('empty registry → empty-state + Add profile row',
        (tester) async {
      final ProviderContainer c = await _seedRegistry(
        profiles: const <Profile>[],
        activeId: null,
        fake: _FakeSecureStorage(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));
      await tester.pumpAndSettle();

      expect(find.text('No profiles yet'), findsOneWidget);
      expect(find.text('Add profile'), findsOneWidget);
    });

    testWidgets('renders one row per profile + marks active', (tester) async {
      final Profile a = _profile(id: 'p-a', name: 'alice');
      final Profile b = _profile(id: 'p-b', name: 'bob');
      final ProviderContainer c = await _seedRegistry(
        profiles: <Profile>[a, b],
        activeId: a.id,
        fake: _FakeSecureStorage(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);

      // Active row has selected: true → ListTile.selected is set; verify
      // via finder.
      final Finder aliceRow = find.ancestor(
        of: find.text('alice'),
        matching: find.byType(ListTile),
      );
      final ListTile tile = tester.widget<ListTile>(aliceRow);
      expect(tile.selected, isTrue);
      // bob is not selected.
      final ListTile bobTile = tester.widget<ListTile>(find.ancestor(
        of: find.text('bob'),
        matching: find.byType(ListTile),
      ));
      expect(bobTile.selected, isFalse);
    });

    testWidgets('switch flow — confirm dialog → setActive', (tester) async {
      final Profile a = _profile(id: 'p-a', name: 'alice');
      final Profile b = _profile(id: 'p-b', name: 'bob');
      final ProviderContainer c = await _seedRegistry(
        profiles: <Profile>[a, b],
        activeId: a.id,
        fake: _FakeSecureStorage(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));
      await tester.pumpAndSettle();

      await tester.tap(find.text('bob'));
      await tester.pumpAndSettle();

      // Confirmation dialog visible.
      expect(find.text('Switch profile?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
      await tester.pumpAndSettle();

      // setActive ran.
      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.activeId, b.id);
    });

    testWidgets('remove active profile → registry has no active',
        (tester) async {
      final Profile a = _profile(id: 'p-a', name: 'alice');
      final ProviderContainer c = await _seedRegistry(
        profiles: <Profile>[a],
        activeId: a.id,
        fake: _FakeSecureStorage(),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));
      await tester.pumpAndSettle();

      // Open the popup menu on alice's row.
      await tester.tap(find.byIcon(Icons.adaptive.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Confirm.
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, isEmpty);
      expect(s.activeId, isNull);
    });
  });
}
