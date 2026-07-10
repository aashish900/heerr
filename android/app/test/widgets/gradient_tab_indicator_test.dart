import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/theme.dart';
import 'package:heerr/widgets/gradient_tab_indicator.dart';

void main() {
  test(
      'heerrDarkTheme uses GradientTabIndicator with a full-width faint line',
      () {
    final ThemeData theme = heerrDarkTheme();
    final Decoration? indicator = theme.tabBarTheme.indicator;
    expect(indicator, isA<GradientTabIndicator>());
    final GradientTabIndicator gradientIndicator = indicator! as GradientTabIndicator;
    expect(gradientIndicator.fadeAlpha, greaterThan(0));
    expect(gradientIndicator.boldWidthFraction, greaterThan(0));
    expect(gradientIndicator.boldWidthFraction, lessThanOrEqualTo(1));
    // .tab (not .label) so the Decoration is handed the full selected tab's
    // width — the faint line needs to span the whole tab, not just the label.
    expect(theme.tabBarTheme.indicatorSize, TabBarIndicatorSize.tab);
    expect(theme.tabBarTheme.dividerColor, Colors.transparent);
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
