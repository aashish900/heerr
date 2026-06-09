import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/skeleton.dart';

void main() {
  testWidgets('SkeletonBox renders with the configured size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SkeletonBox(width: 100, height: 16),
      ),
    ));
    final Container c = tester.widget<Container>(find.byType(Container));
    expect(c.constraints?.maxWidth, 100);
    expect(c.constraints?.maxHeight, 16);
  });

  testWidgets('SkeletonTile composes leading box + title + subtitle boxes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SkeletonTile()),
    ));
    // Three SkeletonBoxes: leading cover, title, subtitle.
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('SkeletonList builds `count` tiles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SkeletonList(count: 3)),
    ));
    expect(find.byType(SkeletonTile), findsNWidgets(3));
  });
}
