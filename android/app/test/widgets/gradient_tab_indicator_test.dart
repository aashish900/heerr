import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/theme.dart';
import 'package:heerr/widgets/gradient_tab_indicator.dart';

void main() {
  test('heerrDarkTheme uses GradientTabIndicator with a thin extension divider', () {
    final ThemeData theme = heerrDarkTheme();
    expect(theme.tabBarTheme.indicator, isA<GradientTabIndicator>());
    expect(theme.tabBarTheme.indicatorSize, TabBarIndicatorSize.label);
    expect(theme.tabBarTheme.dividerHeight, 1);
  });

  testWidgets('gradient tab indicator paints without error across tab switches',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: heerrDarkTheme(),
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(
                tabs: <Tab>[
                  Tab(text: 'Artists'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Playlists'),
                ],
              ),
            ),
            body: const TabBarView(
              children: <Widget>[
                Center(child: Text('Artists')),
                Center(child: Text('Albums')),
                Center(child: Text('Playlists')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsOneWidget);
  });
}
