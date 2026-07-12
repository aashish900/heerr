import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/now_playing_background.dart';

/// NOWPLAYING.md NP1 — immersive blurred-art background.
///
/// [Image.network] doesn't decode under `flutter_tester` (no real network,
/// no terminating decode pipeline — see `library_cover_art_test.dart`), so
/// the art-uri case uses a bounded `pump()` loop instead of `pumpAndSettle`
/// and only asserts on the keyed subtree, not on decoded pixels.
void main() {
  Widget wrap({Uri? artUri, Color? tintColor}) {
    return MaterialApp(
      home: NowPlayingBackground(
        artUri: artUri,
        tintColor: tintColor,
        child: const Center(child: Text('content')),
      ),
    );
  }

  testWidgets('null artUri + null tint renders child + brand glow fallback',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('content'), findsOneWidget);
    // The brand-magenta glow is always present (the design's atmosphere is
    // magenta even before the palette resolves) — only the blurred-art
    // layer waits for a URI.
    expect(find.byKey(const Key('now-playing-bg-glow')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('now-playing-bg-none')),
      findsOneWidget,
    );
  });

  testWidgets('tintColor provided renders a glow layer',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(tintColor: const Color(0xFFAB47BC)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-bg-glow')), findsOneWidget);
  });

  testWidgets('artUri renders a keyed blurred-art subtree',
      (WidgetTester tester) async {
    final Uri uri = Uri.parse('http://navi.test/art/1');
    await tester.pumpWidget(wrap(artUri: uri));
    // Bounded pump — Image.network never resolves under flutter_tester.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(ValueKey<String>('now-playing-bg-${uri.toString()}')),
      findsOneWidget,
    );
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('switching artUri swaps the keyed subtree',
      (WidgetTester tester) async {
    final Uri first = Uri.parse('http://navi.test/art/1');
    final Uri second = Uri.parse('http://navi.test/art/2');
    await tester.pumpWidget(wrap(artUri: first));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(ValueKey<String>('now-playing-bg-${first.toString()}')),
      findsOneWidget,
    );

    await tester.pumpWidget(wrap(artUri: second));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(ValueKey<String>('now-playing-bg-${second.toString()}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('now-playing-bg-${first.toString()}')),
      findsNothing,
    );
  });
}
