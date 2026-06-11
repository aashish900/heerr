import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/widgets/mini_player.dart';

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
