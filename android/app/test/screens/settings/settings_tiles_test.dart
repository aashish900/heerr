import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/screens/settings/settings_tiles.dart';
import 'package:heerr/theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: heerrDarkTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SettingsSectionHeader', () {
    testWidgets('renders the label text', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const SettingsSectionHeader('Downloads & Storage')));
      expect(find.text('Downloads & Storage'), findsOneWidget);
    });
  });

  group('SettingsGroupCard', () {
    testWidgets('renders children with dividers between them', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const SettingsGroupCard(
        children: <Widget>[
          SettingsTile(icon: Icons.wifi, title: 'Row A'),
          SettingsTile(icon: Icons.wifi, title: 'Row B'),
        ],
      )));
      expect(find.text('Row A'), findsOneWidget);
      expect(find.text('Row B'), findsOneWidget);
      // One divider between the two rows, none trailing.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('single child renders no divider', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const SettingsGroupCard(
        children: <Widget>[
          SettingsTile(icon: Icons.wifi, title: 'Only row'),
        ],
      )));
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('SettingsTile', () {
    testWidgets('renders icon, title, subtitle, value, chevron', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(SettingsTile(
        icon: Icons.wifi,
        title: 'Sync interval',
        subtitle: 'How often the app checks for new tracks.',
        value: '15 min',
        onTap: () {},
      )));
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.text('Sync interval'), findsOneWidget);
      expect(find.text('How often the app checks for new tracks.'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('no chevron when onTap is null and trailing is provided', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(SettingsTile(
        icon: Icons.wifi,
        title: 'Wi-Fi only',
        trailing: Switch(value: true, onChanged: (_) {}),
      )));
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('tap fires onTap and is keyed from the title slug', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(SettingsTile(
        icon: Icons.wifi,
        title: 'Clear all downloads',
        onTap: () => tapped = true,
      )));
      expect(find.byKey(const Key('settings-tile-clear-all-downloads')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-tile-clear-all-downloads')));
      expect(tapped, isTrue);
    });

    testWidgets('meets the 48dp minimum touch target', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const SettingsTile(icon: Icons.wifi, title: 'Row')));
      final Size size = tester.getSize(find.byType(SettingsTile));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('SettingsSwitchTile', () {
    testWidgets('renders switch reflecting value and calls onChanged', (WidgetTester tester) async {
      bool? changedTo;
      await tester.pumpWidget(_wrap(SettingsSwitchTile(
        icon: Icons.wifi,
        title: 'Wi-Fi only',
        subtitle: 'Pause syncing on cellular data.',
        value: false,
        onChanged: (bool v) => changedTo = v,
      )));
      final Switch sw = tester.widget(find.byType(Switch));
      expect(sw.value, isFalse);
      await tester.tap(find.byType(Switch));
      expect(changedTo, isTrue);
    });
  });

  group('SettingsDropdownTile', () {
    testWidgets('renders current value and calls onChanged on selection', (WidgetTester tester) async {
      int? selected;
      await tester.pumpWidget(_wrap(SettingsDropdownTile<int>(
        icon: Icons.timer_outlined,
        title: 'Sync interval',
        value: 15,
        items: const <int>[5, 15, 30, 60],
        labelBuilder: (int v) => '$v min',
        onChanged: (int v) => selected = v,
      )));
      expect(find.text('15 min'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 min').last);
      await tester.pumpAndSettle();

      expect(selected, 30);
    });
  });
}
