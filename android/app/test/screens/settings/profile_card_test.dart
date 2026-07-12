import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/profiles/profile_avatar.dart';
import 'package:heerr/screens/settings/profile_card.dart';

Profile _profile() => Profile(
      id: 'p1',
      displayName: 'Alice',
      heerrBaseUrl: 'http://h',
      heerrBearerToken: 't',
      navidromeBaseUrl: 'http://n',
      navidromeUsername: 'alice-nd',
      navidromePassword: 'pw',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    );

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('settings_profile_card'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Widget wrap(Profile? profile) {
    final GoRouter router = GoRouter(
      initialLocation: '/settings',
      routes: <RouteBase>[
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: ProfileCard()),
        ),
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('PROFILE_SCREEN')),
        ),
      ],
    );
    return ProviderScope(
      overrides: <Override>[
        activeProfileProvider.overrideWithValue(profile),
        avatarsDirProvider.overrideWith((_) async => tmp),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('renders display name and the "Manage your profile" caption', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(_profile()));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Manage your profile'), findsOneWidget);
  });

  testWidgets('tap pushes /profile', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(_profile()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-profile-card')));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE_SCREEN'), findsOneWidget);
  });

  testWidgets('signed out renders nothing', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-profile-card')), findsNothing);
  });
}
