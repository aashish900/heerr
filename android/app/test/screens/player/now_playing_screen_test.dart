import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';

PlayerSnapshot _snap({MediaItem? item, bool playing = false}) {
  return PlayerSnapshot(
    item: item,
    state: PlaybackState(playing: playing),
  );
}

MediaItem _item({
  String id = 'http://stream/1',
  String title = 'Track A',
  String artist = 'Artist A',
  Duration duration = const Duration(minutes: 3, seconds: 30),
}) {
  return MediaItem(
    id: id,
    title: title,
    artist: artist,
    duration: duration,
  );
}

Widget _wrap({
  required PlayerSnapshot snapshot,
  List<MediaItem> queue = const <MediaItem>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(snapshot),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(queue),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) =>
            Stream<MediaItem?>.value(snapshot.item),
      ),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

void main() {
  testWidgets('"Nothing is playing" when snapshot has no item',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(snapshot: _snap()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing is playing.'), findsOneWidget);
  });

  testWidgets('renders title, artist, duration, and play icon when paused',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Track A'), findsWidgets);
    expect(find.text('Artist A'), findsOneWidget);
    // duration 3:30
    expect(find.text('3:30'), findsOneWidget);
    // paused → play_circle_fill on the centre transport.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
  });

  testWidgets('renders pause icon when playing',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: true),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });

  testWidgets('renders queue items with current track marked',
      (WidgetTester tester) async {
    // Tall viewport so the queue list at the bottom has room for both
    // tiles — the cover art + scrubber + transport eat most of the default
    // 600px height.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final MediaItem a = _item(id: 'http://s/1', title: 'Track A');
    final MediaItem b = _item(id: 'http://s/2', title: 'Track B');
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: a, playing: true),
      queue: <MediaItem>[a, b],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Track A'), findsWidgets);
    expect(find.text('Track B'), findsOneWidget);
    // The current track gets the equalizer icon.
    expect(find.byIcon(Icons.equalizer), findsOneWidget);
  });

  testWidgets('empty queue → "Queue is empty"',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
      queue: const <MediaItem>[],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Queue is empty.'), findsOneWidget);
  });

  testWidgets('scrubber Slider has max = duration in ms',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(
        item: _item(duration: const Duration(seconds: 200)),
        playing: false,
      ),
    ));
    await tester.pumpAndSettle();
    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.max, 200 * 1000);
  });

  testWidgets('snapshot stream loading → CircularProgressIndicator',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerSnapshotProvider.overrideWith(
            (Ref<AsyncValue<PlayerSnapshot>> ref) =>
                Stream<PlayerSnapshot>.fromFuture(
                    Completer<PlayerSnapshot>().future),
          ),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
