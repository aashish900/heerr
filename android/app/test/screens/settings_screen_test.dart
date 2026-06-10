import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/servers_screen.dart';
import 'package:heerr/screens/settings_screen.dart';

class _InMemoryStorage implements SecureStorage {
  _InMemoryStorage();
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

void main() {
  testWidgets('Settings screen lists a "Servers" entry', (
    WidgetTester tester,
  ) async {
    final SecureStorage store = _InMemoryStorage();
    await tester.pumpWidget(_wrap(<Override>[
      secureStorageProvider.overrideWithValue(store),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Servers'), findsOneWidget);
  });

  testWidgets('Tapping Servers navigates to the ServersScreen empty state', (
    WidgetTester tester,
  ) async {
    final SecureStorage store = _InMemoryStorage();
    await tester.pumpWidget(_wrap(<Override>[
      secureStorageProvider.overrideWithValue(store),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Servers'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No servers yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
