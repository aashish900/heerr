import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/mix.dart';
import 'package:heerr/providers/mixes.dart';
import 'package:heerr/screens/home/your_mixes_section.dart';
import 'package:heerr/theme.dart';

const List<MixVibe> _vibes = <MixVibe>[
  MixVibe(id: 'chill', title: 'Chill Mix'),
  MixVibe(id: 'feel-good', title: 'Feel Good Mix'),
  MixVibe(id: 'party', title: 'Party Mix'),
  MixVibe(id: 'romance', title: 'Romance Mix'),
  MixVibe(id: 'heartbreak', title: 'Heartbreak Mix'),
  MixVibe(id: 'workout', title: 'Workout Mix'),
  MixVibe(id: 'focus', title: 'Focus Mix'),
  MixVibe(id: 'sleep', title: 'Sleep Mix'),
];

Widget _wrap(Future<List<MixVibe>> Function() load) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(child: YourMixesSection()),
        ),
      ),
      GoRoute(
        path: '/mixes/:id',
        builder: (_, GoRouterState s) =>
            Scaffold(body: Text('MIX:${s.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[mixVibesProvider.overrideWith((_) => load())],
    child: MaterialApp.router(theme: heerrDarkTheme(), routerConfig: router),
  );
}

Finder _tiles() => find.byKey(const ValueKey<String>('mix-tile'));

void main() {
  testWidgets('header + one tile per vibe, in one horizontal row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(() async => _vibes));
    await tester.pumpAndSettle();

    expect(find.text('Your Mixes'), findsOneWidget);
    expect(_tiles(), findsNWidgets(8));
    final Rect first = tester.getRect(_tiles().at(0));
    final Rect second = tester.getRect(_tiles().at(1));
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.right));
    expect(first.width, closeTo(first.height, 0.01)); // square
    expect(find.text('Chill Mix'), findsOneWidget);
  });

  testWidgets('row slides sideways to the last vibe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(() async => _vibes));
    await tester.pumpAndSettle();

    final double screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getRect(_tiles().at(7)).left, greaterThan(screen));
    await tester.drag(_tiles().first, const Offset(-3000, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(_tiles().at(7)).right, lessThanOrEqualTo(screen));
  });

  testWidgets('tapping a tile opens that mix', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(() async => _vibes));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Party Mix'));
    await tester.pumpAndSettle();
    expect(find.text('MIX:party'), findsOneWidget);
  });

  testWidgets('hidden when the vibes call fails', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(() async => throw Exception('down')));
    await tester.pumpAndSettle();

    expect(find.text('Your Mixes'), findsNothing);
    expect(_tiles(), findsNothing);
  });

  testWidgets('hidden when there are no vibes', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(() async => <MixVibe>[]));
    await tester.pumpAndSettle();

    expect(find.text('Your Mixes'), findsNothing);
  });

  test('every vibe has its own icon; unknown ids fall back', () {
    final Set<IconData> icons = <IconData>{
      for (final MixVibe v in _vibes) vibeStyle(v.id).icon,
    };
    expect(icons, hasLength(8));
    expect(vibeStyle('polka').icon, Icons.graphic_eq);
    // Gradients only use the theme's brand colours.
    for (final MixVibe v in _vibes) {
      for (final Color c in vibeStyle(v.id).gradient.colors) {
        expect(<Color>[heerrMagenta, heerrPurple, heerrViolet], contains(c));
      }
    }
  });
}
