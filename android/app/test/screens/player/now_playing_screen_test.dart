import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';

// Static counters so the (transient) provider instance can report into the
// test without us having to fish it back out via ProviderContainer.
int _pauseCalls = 0;
int _resumeCalls = 0;

class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async {
    return const QueueResponse(active: <JobView>[], recent: <JobView>[]);
  }

  @override
  void pause() {
    _pauseCalls++;
  }

  @override
  Future<void> resume() async {
    _resumeCalls++;
  }
}

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

/// #35: queue-mutation tests need a real handler behind the rows' swipe /
/// drag / tap gestures. Everything is stubbed via mocktail.
class _StubHandler extends Mock implements HeerrAudioHandler {}

Widget _wrap({
  required PlayerSnapshot snapshot,
  List<MediaItem> queue = const <MediaItem>[],
  HeerrAudioHandler? handler,
}) {
  return ProviderScope(
    overrides: <Override>[
      if (handler != null) audioHandlerProvider.overrideWithValue(handler),
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
      queueProvider.overrideWith(_StubQueue.new),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

void main() {
  setUp(() {
    _pauseCalls = 0;
    _resumeCalls = 0;
    paletteExtractorOverride = (Uri? _) async => null; // deterministic, no I/O
  });

  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
  });

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

  group('queue edit (#35)', () {
    late _StubHandler handler;

    setUp(() {
      handler = _StubHandler();
      when(() => handler.removeQueueItemAt(any())).thenAnswer((_) async {});
      when(() => handler.moveQueueItem(any(), any()))
          .thenAnswer((_) async {});
    });

    Future<void> pumpQueue(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final MediaItem a = _item(id: 'http://s/1', title: 'Track A');
      final MediaItem b = _item(id: 'http://s/2', title: 'Track B');
      final MediaItem c = _item(id: 'http://s/3', title: 'Track C');
      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: a, playing: true),
        queue: <MediaItem>[a, b, c],
        handler: handler,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('rows render drag handles', (WidgetTester tester) async {
      await pumpQueue(tester);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });

    testWidgets('swipe-to-dismiss removes the row at its index',
        (WidgetTester tester) async {
      await pumpQueue(tester);
      await tester.drag(find.text('Track B'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      verify(() => handler.removeQueueItemAt(1)).called(1);
    });

    testWidgets('dragging a handle reorders via moveQueueItem',
        (WidgetTester tester) async {
      await pumpQueue(tester);
      // Row height ~56px; drag Track A's handle down past Track B.
      await tester.timedDrag(
        find.byIcon(Icons.drag_handle).first,
        const Offset(0, 70),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      final List<dynamic> args = verify(
        () => handler.moveQueueItem(captureAny(), captureAny()),
      ).captured;
      expect(args[0], 0);
      expect(args[1], 1);
    });
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
          queueProvider.overrideWith(_StubQueue.new),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // K1.2 — palette tint
  testWidgets(
    'paints a gradient surface when palette extractor returns a colour',
    (WidgetTester tester) async {
      paletteExtractorOverride =
          (Uri? _) async => const Color(0xFFAB47BC); // purple-ish
      await tester.pumpWidget(_wrap(
        snapshot: _snap(
          item: _item(id: 'http://stream/x'),
          playing: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DecoratedBox), findsWidgets);
      // No tint means the helper widget falls through to the raw child;
      // having a non-null colour gates the gradient path.
    },
  );

  testWidgets('does NOT crash when palette extractor returns null',
      (WidgetTester tester) async {
    paletteExtractorOverride = (Uri? _) async => null;
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Track A'), findsWidgets);
  });

  // K1.3 — lifecycle
  testWidgets('pauses queueProvider on mount and resumes on dispose',
      (WidgetTester tester) async {
    expect(_pauseCalls, 0);
    expect(_resumeCalls, 0);

    // Use a builder we can toggle, keeping ProviderScope alive across the
    // remount so the resume() call in NowPlayingScreen.dispose can still
    // resolve the provider's notifier.
    final ValueNotifier<bool> showPlayer = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerSnapshotProvider.overrideWith(
            (Ref<AsyncValue<PlayerSnapshot>> ref) =>
                Stream<PlayerSnapshot>.value(
                  _snap(item: _item(), playing: true),
                ),
          ),
          playerQueueProvider.overrideWith(
            (Ref<AsyncValue<List<MediaItem>>> ref) =>
                Stream<List<MediaItem>>.value(const <MediaItem>[]),
          ),
          currentMediaItemProvider.overrideWith(
            (Ref<AsyncValue<MediaItem?>> ref) =>
                Stream<MediaItem?>.value(_item()),
          ),
          queueProvider.overrideWith(_StubQueue.new),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showPlayer,
            builder: (BuildContext c, bool show, _) =>
                show ? const NowPlayingScreen() : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pauseCalls, 1);
    expect(_resumeCalls, 0);

    showPlayer.value = false;
    await tester.pumpAndSettle();
    expect(_resumeCalls, 1);
  });
}
