import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/screens/home/continue_listening_card.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/widgets/waveform_strip.dart';

class _StubHandler extends Mock implements HeerrAudioHandler {}

PlayerSnapshot _snap({
  MediaItem? item,
  bool playing = false,
  Duration position = Duration.zero,
}) {
  return PlayerSnapshot(
    item: item,
    state: PlaybackState(playing: playing, updatePosition: position),
  );
}

MediaItem _item({
  String title = 'Starboy',
  String artist = 'The Weeknd',
  Duration? duration = const Duration(minutes: 3, seconds: 50),
}) {
  return MediaItem(
    id: 'http://stream/1',
    title: title,
    artist: artist,
    duration: duration,
  );
}

Widget _wrap({
  required PlayerSnapshot snapshot,
  HeerrAudioHandler? handler,
}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: ContinueListeningCard()),
      ),
      GoRoute(
        path: '/player',
        builder: (_, _) => const Scaffold(body: Text('NOW_PLAYING_SCREEN')),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      if (handler != null) audioHandlerProvider.overrideWithValue(handler),
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(snapshot),
      ),
    ],
    child: MaterialApp.router(
      theme: heerrDarkTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('hidden when the snapshot has no current item',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(snapshot: _snap()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue-listening-card')), findsNothing);
  });

  testWidgets('renders badge, title, artist, waveform and times',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(
        item: _item(),
        position: const Duration(minutes: 1, seconds: 7),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('CONTINUE LISTENING'), findsOneWidget);
    expect(find.text('Starboy'), findsOneWidget);
    expect(find.text('The Weeknd'), findsOneWidget);
    expect(find.byType(WaveformStrip), findsOneWidget);
    expect(find.text('1:07'), findsOneWidget);
    expect(find.text('3:50'), findsOneWidget);
  });

  testWidgets('progress fraction = position / duration',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(
        item: _item(duration: const Duration(minutes: 2)),
        position: const Duration(minutes: 1),
      ),
    ));
    await tester.pumpAndSettle();

    final FractionallySizedBox fill = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('continue-listening-progress')));
    expect(fill.widthFactor, closeTo(0.5, 0.001));
  });

  testWidgets('null duration renders --:-- and zero progress (no crash)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(
        item: _item(duration: null),
        position: const Duration(seconds: 30),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('--:--'), findsOneWidget);
    final FractionallySizedBox fill = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('continue-listening-progress')));
    expect(fill.widthFactor, 0);
  });

  testWidgets('play button calls handler.play() when paused',
      (WidgetTester tester) async {
    final _StubHandler handler = _StubHandler();
    when(handler.play).thenAnswer((_) async {});
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
      handler: handler,
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-listening-play')));
    verify(handler.play).called(1);
  });

  testWidgets('play button calls handler.pause() when playing',
      (WidgetTester tester) async {
    final _StubHandler handler = _StubHandler();
    when(handler.pause).thenAnswer((_) async {});
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: true),
      handler: handler,
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-listening-play')));
    verify(handler.pause).called(1);
  });

  testWidgets('card tap (not on the button) pushes /player',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Starboy'));
    await tester.pumpAndSettle();
    expect(find.text('NOW_PLAYING_SCREEN'), findsOneWidget);
  });

  group('WaveformStrip.barHeights', () {
    test('deterministic for equal seeds', () {
      expect(WaveformStrip.barHeights(40, 123),
          equals(WaveformStrip.barHeights(40, 123)));
    });

    test('differs across seeds', () {
      expect(WaveformStrip.barHeights(40, 1),
          isNot(equals(WaveformStrip.barHeights(40, 2))));
    });

    test('heights stay within 0.15..1.0', () {
      for (final double h in WaveformStrip.barHeights(100, 7)) {
        expect(h, inInclusiveRange(0.15, 1.0));
      }
    });
  });
}
