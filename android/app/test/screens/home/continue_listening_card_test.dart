import 'dart:async';

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
import 'package:heerr/utils/palette.dart';
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
}) =>
    _wrapStream(
      stream: Stream<PlayerSnapshot>.value(snapshot),
      handler: handler,
    );

// Feeds playerSnapshotProvider from a single, long-lived stream — matching
// production, where audio_service emits repeatedly into one subscription.
// Swapping ProviderScope overrides across a fresh pumpWidget call (i.e. two
// separate Stream.value() overrides) doesn't reliably rebuild an
// already-instantiated provider, which made an earlier play->pause
// regression test hang on pumpAndSettle for the wrong reason.
Widget _wrapStream({
  required Stream<PlayerSnapshot> stream,
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
        (Ref<AsyncValue<PlayerSnapshot>> ref) => stream,
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
    // While playing the waveform animates forever — pump fixed frames
    // instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-listening-play')));
    verify(handler.pause).called(1);
  });

  testWidgets(
      'regression: waveform animates while playing, static when paused',
      (WidgetTester tester) async {
    final StreamController<PlayerSnapshot> ctrl =
        StreamController<PlayerSnapshot>.broadcast();
    addTearDown(ctrl.close);

    await tester.pumpWidget(_wrapStream(stream: ctrl.stream));
    ctrl.add(_snap(item: _item(), playing: true));
    // The waveform animates forever while playing — pump fixed frames
    // instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<WaveformStrip>(find.byType(WaveformStrip)).animate,
      isTrue,
    );

    ctrl.add(_snap(item: _item(), playing: false));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WaveformStrip>(find.byType(WaveformStrip)).animate,
      isFalse,
    );
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

  group('Part B adaptive theming', () {
    tearDown(() {
      dominantColorForOverride = dominantColorFor;
    });

    MediaItem itemWithArt() => MediaItem(
          id: 'http://stream/1',
          title: 'Starboy',
          artist: 'The Weeknd',
          duration: const Duration(minutes: 3, seconds: 50),
          artUri: Uri.parse('http://navi.test/cover/1'),
        );

    testWidgets('waveform + glows take the brand-blended extracted colour',
        (WidgetTester tester) async {
      const Color extracted = Color(0xFF2266AA);
      int calls = 0;
      dominantColorForOverride = (Uri? _) async {
        calls++;
        return extracted;
      };
      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: itemWithArt()),
      ));
      await tester.pumpAndSettle();

      final WaveformStrip strip =
          tester.widget<WaveformStrip>(find.byType(WaveformStrip));
      expect(strip.color, brandBlend(extracted));
      expect(calls, 1, reason: 'one extraction per unique cover URI');
    });

    testWidgets('fallback tint without art (no cover-driven backdrop)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: _item()), // no artUri
      ));
      await tester.pumpAndSettle();

      final WaveformStrip strip =
          tester.widget<WaveformStrip>(find.byType(WaveformStrip));
      expect(strip.color, brandBlend(heerrPurple));
    });
  });

  group('restyle: mockup fidelity (user review)', () {
    testWidgets('card border is a thin single-colour magenta hairline',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(snapshot: _snap(item: _item())));
      await tester.pumpAndSettle();

      final Material card = tester.widget<Material>(find.byWidgetPredicate(
          (Widget w) => w is Material && w.shape is RoundedRectangleBorder));
      final RoundedRectangleBorder shape =
          card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, heerrMagenta.withValues(alpha: 0.5));
    });

    testWidgets('play control is an outlined ring, not a filled disc',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(snapshot: _snap(item: _item())));
      await tester.pumpAndSettle();

      final Container ring = tester.widget<Container>(find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration! as BoxDecoration).border != null));
      final BoxDecoration deco = ring.decoration! as BoxDecoration;
      expect(deco.gradient, isNull);
      expect(deco.border, isNotNull);
    });

    testWidgets('progress bar shows a round knob at the current position',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        snapshot: _snap(
          item: _item(),
          position: const Duration(minutes: 1, seconds: 7),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('continue-listening-progress-knob')),
          findsOneWidget);
    });

    testWidgets('album art tile is 161px wide (+15% over the original 140)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(snapshot: _snap(item: _item())));
      await tester.pumpAndSettle();

      final Container artTile = tester.widget<Container>(find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.constraints?.maxWidth == 161 &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).boxShadow != null));
      expect(artTile.constraints?.maxWidth, 161);
    });
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
