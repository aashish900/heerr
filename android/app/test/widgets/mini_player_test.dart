import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/mini_player.dart';
import 'package:heerr/widgets/waveform_strip.dart';

PlayerSnapshot _snapshot({MediaItem? item, bool playing = false}) {
  return PlayerSnapshot(
    item: item,
    state: PlaybackState(playing: playing),
  );
}

MediaItem _item({String id = 'http://stream/1', String title = 'Hey'}) {
  return MediaItem(id: id, title: title, artist: 'Pixies');
}

Widget _wrap({required AsyncValue<PlayerSnapshot> snapshot}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          bottomNavigationBar: MiniPlayer(),
          body: SizedBox.shrink(),
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (_, _) =>
            const Scaffold(body: Text('NOW_PLAYING_SCREEN')),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(snapshot.valueOrNull ??
                _snapshot()),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('hidden when snapshot has no current MediaItem',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(snapshot: AsyncData<PlayerSnapshot>(_snapshot())));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    // SizedBox.shrink renders with zero height.
    final SizedBox sb = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sb.height, 0);
  });

  testWidgets('renders title + artist + play icon when paused',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(
        _snapshot(item: _item(title: 'Where Is My Mind'), playing: false),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Where Is My Mind'), findsOneWidget);
    expect(find.text('Pixies'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('renders pause icon when playing',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(
        _snapshot(item: _item(), playing: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('tap on the bar pushes /player',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(
        _snapshot(item: _item(), playing: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hey'));
    await tester.pumpAndSettle();
    expect(find.text('NOW_PLAYING_SCREEN'), findsOneWidget);
  });

  testWidgets('shows the Preview badge for a preview MediaItem',
      (WidgetTester tester) async {
    const MediaItem preview = MediaItem(
      id: 'http://heerr/api/v1/preview/stream?source_url=x&token=y',
      title: 'Demo Track',
      artist: 'Someone',
      extras: <String, dynamic>{'preview': true},
    );
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(_snapshot(item: preview)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Preview'), findsOneWidget);
  });

  testWidgets('no Preview badge for a normal (library) MediaItem',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(_snapshot(item: _item())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Preview'), findsNothing);
  });

  testWidgets(
      'redesign: renders the waveform strip and a gradient play circle',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(
        _snapshot(item: _item(), playing: false),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(WaveformStrip), findsOneWidget);
    // The play/pause control is a gradient-filled circle (HOMESCREEN.md
    // task 7), not a plain IconButton.
    final Finder circle = find.byWidgetPredicate((Widget w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
        (w.decoration! as BoxDecoration).gradient == heerrGradient);
    expect(circle, findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets(
      'Part B: waveform tint is the brand-blended extracted cover colour',
      (WidgetTester tester) async {
    const Color extracted = Color(0xFF2266AA);
    dominantColorForOverride = (Uri? _) async => extracted;
    addTearDown(() => dominantColorForOverride = dominantColorFor);

    final MediaItem item = MediaItem(
      id: 'http://stream/1',
      title: 'Tinted',
      artist: 'Artist',
      artUri: Uri.parse('http://navi.test/cover/1'),
    );
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(_snapshot(item: item)),
    ));
    await tester.pumpAndSettle();

    final WaveformStrip strip =
        tester.widget<WaveformStrip>(find.byType(WaveformStrip));
    expect(strip.color, brandBlend(extracted));
  });

  testWidgets('Part B: extraction failure falls back to blended heerrPurple',
      (WidgetTester tester) async {
    dominantColorForOverride = (Uri? _) async => null;
    addTearDown(() => dominantColorForOverride = dominantColorFor);

    final MediaItem item = MediaItem(
      id: 'http://stream/1',
      title: 'NoTint',
      artUri: Uri.parse('http://navi.test/cover/none'),
    );
    await tester.pumpWidget(_wrap(
      snapshot: AsyncData<PlayerSnapshot>(_snapshot(item: item)),
    ));
    await tester.pumpAndSettle();

    final WaveformStrip strip =
        tester.widget<WaveformStrip>(find.byType(WaveformStrip));
    expect(strip.color, brandBlend(heerrPurple));
  });

  testWidgets('hidden when snapshot stream is still loading',
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
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MiniPlayer(),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    final SizedBox sb = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sb.height, 0);
  });

  testWidgets('hidden when audioHandlerProvider has no override (error case)',
      (WidgetTester tester) async {
    // No override → playerSnapshotProvider's Stream throws because the
    // underlying audioHandlerProvider throws by default. The mini-player
    // must still render zero-height SizedBox.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MiniPlayer(),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final SizedBox sb = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sb.height, 0);
  });
}
