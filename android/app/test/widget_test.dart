import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/main.dart';

void main() {
  testWidgets('HeerrApp renders the brand text on a dark surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HeerrApp());

    // The bare hello-world shows "heerr" as the only text widget.
    expect(find.text('heerr'), findsOneWidget);

    // Dark theme: the colour scheme should be in dark mode.
    final BuildContext context = tester.element(find.text('heerr'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
