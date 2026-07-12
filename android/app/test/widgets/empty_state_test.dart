import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/empty_state.dart';

void main() {
  testWidgets('renders the icon and title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyState(icon: Icons.queue_music, title: 'No jobs yet'),
      ),
    ));
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
  });

  testWidgets('subtitle is rendered when provided', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.search,
          title: 'Search library',
          subtitle: 'Tracks, albums, or playlists',
        ),
      ),
    ));
    expect(find.text('Tracks, albums, or playlists'), findsOneWidget);
  });

  testWidgets('subtitle is not in the tree when null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyState(icon: Icons.search_off, title: 'No results'),
      ),
    ));
    expect(find.text('No results'), findsOneWidget);
    // There's exactly one Text widget directly under the EmptyState's column.
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });
}
