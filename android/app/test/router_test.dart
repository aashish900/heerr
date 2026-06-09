import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/router.dart';
import 'package:heerr/theme.dart';

Widget _bootApp() {
  return ProviderScope(
    child: MaterialApp.router(
      theme: heerrDarkTheme(),
      routerConfig: buildHeerrRouter(),
    ),
  );
}

// Returns the active screen's AppBar title by reading the Scaffold's
// AppBar widget — more robust than `find.text(...)` because each stub
// renders the same label in both the AppBar and the body.
String _activeTitle(WidgetTester tester) {
  final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
  final Text title = bar.title! as Text;
  return title.data!;
}

void main() {
  testWidgets('boots on the Search route by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    expect(_activeTitle(tester), 'Search');
  });

  testWidgets('tapping the Queue tab navigates to the Queue screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    expect(_activeTitle(tester), 'Queue');
  });

  testWidgets('tapping the Settings tab navigates to the Settings screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(_activeTitle(tester), 'Settings');
  });

  testWidgets('navigation round-trip: Settings → Search returns to Search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(_activeTitle(tester), 'Settings');

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(_activeTitle(tester), 'Search');
  });

  testWidgets('uses Material 3 dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(_bootApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).useMaterial3, isTrue);
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
