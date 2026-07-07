import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/download_icon.dart';
import 'package:heerr/widgets/library_result_tile.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('LibraryResultTile — trailing-slot precedence', () {
    testWidgets('isCurrentlyPlaying wins over marker + play', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: null,
        coverArtId: null,
        onTap: () {},
        trailingPlay: true,
        onPlay: () {},
        isCurrentlyPlaying: true,
        isMarkedForOffline: true,
        onMarkToggle: () {},
      )));
      await tester.pump();
      // Only one play_arrow (the green now-playing one). No download icon.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(DownloadIcon), findsNothing);
      expect(find.byIcon(Icons.play_arrow_outlined), findsNothing);
    });

    testWidgets('onMarkToggle → outlined icon when not marked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: null,
        coverArtId: null,
        onTap: () {},
        onMarkToggle: () {},
        isMarkedForOffline: false,
      )));
      await tester.pump();
      expect(
        find.byWidgetPredicate((Widget w) => w is DownloadIcon && !w.filled),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((Widget w) => w is DownloadIcon && w.filled),
        findsNothing,
      );
    });

    testWidgets('onMarkToggle → filled green icon when marked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: null,
        coverArtId: null,
        onTap: () {},
        onMarkToggle: () {},
        isMarkedForOffline: true,
      )));
      await tester.pump();
      final DownloadIcon icon = tester.widget<DownloadIcon>(
        find.byType(DownloadIcon),
      );
      expect(icon.filled, isTrue);
    });

    testWidgets('mark toggle fires onMarkToggle', (
      WidgetTester tester,
    ) async {
      int count = 0;
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: null,
        coverArtId: null,
        onTap: () {},
        onMarkToggle: () => count += 1,
        isMarkedForOffline: false,
      )));
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      expect(count, 1);
    });

    testWidgets('trailingPlay + marker = passive badge alongside play', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: null,
        coverArtId: null,
        onTap: () {},
        trailingPlay: true,
        onPlay: () {},
        isMarkedForOffline: true,
      )));
      await tester.pump();
      // Both the marker badge (passive, no toggle) and the play button.
      expect(find.byType(DownloadIcon), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
    });

    testWidgets('trailingPlay alone (no marker) shows only play', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: null,
        coverArtId: null,
        onTap: () {},
        trailingPlay: true,
        onPlay: () {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
      expect(find.byType(DownloadIcon), findsNothing);
    });
  });

  group('LibraryResultTile — offlineProgress bar', () {
    testWidgets('renders a LinearProgressIndicator when progress != null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: 'sub',
        coverArtId: null,
        onTap: () {},
        offlineProgress: 0.5,
      )));
      await tester.pump();
      final LinearProgressIndicator p =
          tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(p.value, 0.5);
    });

    testWidgets('no progress bar when offlineProgress is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(LibraryResultTile(
        title: 'X',
        subtitle: 'sub',
        coverArtId: null,
        onTap: () {},
      )));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('LibraryResultTile — long-press (M3)', () {
    testWidgets(
      'long-press fires the onLongPress callback',
      (WidgetTester tester) async {
        int longPresses = 0;
        await tester.pumpWidget(_wrap(LibraryResultTile(
          title: 'X',
          subtitle: 'sub',
          coverArtId: null,
          onTap: () {},
          onLongPress: () => longPresses++,
        )));
        await tester.pump();
        await tester.longPress(find.byType(LibraryResultTile));
        await tester.pumpAndSettle();
        expect(longPresses, 1);
      },
    );

    testWidgets(
      'null onLongPress does not crash on long-press',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(LibraryResultTile(
          title: 'X',
          subtitle: 'sub',
          coverArtId: null,
          onTap: () {},
        )));
        await tester.pump();
        await tester.longPress(find.byType(LibraryResultTile));
        await tester.pumpAndSettle();
        // If we get here without an exception, the no-op long-press
        // contract holds.
      },
    );
  });
}
