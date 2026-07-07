import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/widgets/download_icon.dart';
import 'package:heerr/widgets/result_tile.dart';

SearchResultItem _item({bool alreadyDownloaded = false}) {
  return SearchResultItem(
    sourceUrl: 'https://music.youtube.com/watch?v=abc123',
    sourceType: 'song',
    title: 'Let It Happen',
    artist: 'Tame Impala',
    album: 'Currents',
    alreadyDownloaded: alreadyDownloaded,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onDownload,
  VoidCallback? onPreview,
  VoidCallback? onLongPress,
  bool alreadyDownloaded = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ResultTile(
            item: _item(alreadyDownloaded: alreadyDownloaded),
            onDownload: onDownload,
            onPreview: onPreview,
            onLongPress: onLongPress,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the preview play button when onPreview is provided',
      (WidgetTester tester) async {
    await _pump(tester, onPreview: () {});
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    // Download affordance still present alongside it.
    expect(find.byWidgetPredicate((Widget w) => w is DownloadIcon && !w.filled), findsOneWidget);
  });

  testWidgets('no preview button when onPreview is null',
      (WidgetTester tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('tapping the row fires onPreview', (WidgetTester tester) async {
    int previews = 0;
    int downloads = 0;
    await _pump(
      tester,
      onDownload: () => downloads++,
      onPreview: () => previews++,
    );

    await tester.tap(find.text('Let It Happen'));
    await tester.pumpAndSettle();

    expect(previews, 1);
    expect(downloads, 0);
  });

  testWidgets('tapping the download icon fires onDownload',
      (WidgetTester tester) async {
    int previews = 0;
    int downloads = 0;
    await _pump(
      tester,
      onDownload: () => downloads++,
      onPreview: () => previews++,
    );

    await tester.tap(find.byWidgetPredicate((Widget w) => w is DownloadIcon && !w.filled));
    await tester.pumpAndSettle();

    expect(downloads, 1);
    expect(previews, 0);
  });

  testWidgets('tapping play button fires onPreview not onDownload',
      (WidgetTester tester) async {
    int previews = 0;
    int downloads = 0;
    await _pump(
      tester,
      onDownload: () => downloads++,
      onPreview: () => previews++,
    );

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();

    expect(previews, 1);
    expect(downloads, 0);
  });

  testWidgets('long-pressing the row fires onLongPress',
      (WidgetTester tester) async {
    int longPresses = 0;
    int downloads = 0;
    await _pump(
      tester,
      onDownload: () => downloads++,
      onPreview: () {},
      onLongPress: () => longPresses++,
    );

    await tester.longPress(find.text('Let It Happen'));
    await tester.pumpAndSettle();

    expect(longPresses, 1);
    expect(downloads, 0);
  });

  testWidgets('preview button works even when already downloaded',
      (WidgetTester tester) async {
    int previews = 0;
    await _pump(tester, alreadyDownloaded: true, onPreview: () => previews++);

    expect(find.byWidgetPredicate((Widget w) => w is DownloadIcon && w.filled), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();
    expect(previews, 1);
  });
}
