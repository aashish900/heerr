import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/glass_icon_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the icon and fires onPressed when tapped',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(wrap(GlassIconButton(
      icon: Icons.keyboard_arrow_down,
      tooltip: 'Collapse',
      onPressed: () => taps++,
    )));
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    expect(taps, 1);
  });

  testWidgets('null onPressed disables the button',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const GlassIconButton(
      icon: Icons.speaker_outlined,
      tooltip: 'Audio device',
      onPressed: null,
    )));
    final InkWell inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
  });

  testWidgets('shows the tooltip message', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(GlassIconButton(
      icon: Icons.more_vert,
      tooltip: 'More',
      onPressed: () {},
    )));
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('iconColor overrides the default white tint when enabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(GlassIconButton(
      icon: Icons.download_done,
      onPressed: () {},
      iconColor: const Color(0xFFF533C8),
    )));
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.download_done));
    expect(icon.color, const Color(0xFFF533C8));
  });

  testWidgets('disabled button ignores iconColor and dims to white38',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const GlassIconButton(
      icon: Icons.schedule,
      onPressed: null,
      iconColor: Color(0xFFF533C8),
    )));
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.schedule));
    expect(icon.color, Colors.white38);
  });
}
