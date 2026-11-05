import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/playback_actions.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/jam_remote.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

/// Joined guest: records sends instead of hitting the backend.
class _FakeRemote extends JamRemote {
  _FakeRemote({this.fail});

  final ApiError? fail;
  final List<(String, Map<String, dynamic>?)> sent =
      <(String, Map<String, dynamic>?)>[];

  @override
  JamRemoteStatus? build() =>
      const JamRemoteStatus(sessionId: 's1', hostUsername: 'aashish');

  @override
  Future<void> send(String kind, [Map<String, dynamic>? payload]) async {
    if (fail != null) throw fail!;
    sent.add((kind, payload));
  }
}

const Song _a = Song(id: 'a', title: 'A');
const Song _b = Song(id: 'b', title: 'B');

Future<void> _run(
  WidgetTester t,
  _FakeRemote remote,
  _MockHandler handler,
  Future<void> Function(WidgetRef ref, BuildContext context) action,
) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        jamRemoteProvider.overrideWith(() => remote),
        audioHandlerProvider.overrideWithValue(handler),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) => TextButton(
              onPressed: () => action(ref, context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pump();
}

void main() {
  late _MockHandler handler;

  setUp(() => handler = _MockHandler());

  testWidgets('play song is sent to the host, local player untouched', (
    WidgetTester t,
  ) async {
    final _FakeRemote remote = _FakeRemote();
    await _run(
      t,
      remote,
      handler,
      (WidgetRef ref, BuildContext c) => playSongFromSubsonic(ref, c, _a),
    );
    expect(remote.sent.single.$1, 'play_songs');
    expect(remote.sent.single.$2!['songs'], <dynamic>[_a.toJson()]);
    expect(remote.sent.single.$2!['start_index'], 0);
    expect(find.text('Sent to aashish'), findsOneWidget);
    verifyZeroInteractions(handler);
  });

  testWidgets('play all keeps start index', (WidgetTester t) async {
    final _FakeRemote remote = _FakeRemote();
    await _run(
      t,
      remote,
      handler,
      (WidgetRef ref, BuildContext c) =>
          playAllSongsFromSubsonic(ref, c, const <Song>[_a, _b], startIndex: 1),
    );
    expect(remote.sent.single.$1, 'play_songs');
    expect((remote.sent.single.$2!['songs'] as List<dynamic>).length, 2);
    expect(remote.sent.single.$2!['start_index'], 1);
    verifyZeroInteractions(handler);
  });

  testWidgets('play all over the cap sends a window from the tapped song', (
    WidgetTester t,
  ) async {
    final _FakeRemote remote = _FakeRemote();
    final List<Song> many = <Song>[
      for (int i = 0; i < kJamMaxSongs + 20; i++) Song(id: '$i', title: '$i'),
    ];
    await _run(
      t,
      remote,
      handler,
      (WidgetRef ref, BuildContext c) =>
          playAllSongsFromSubsonic(ref, c, many, startIndex: 10),
    );
    final List<dynamic> songs =
        remote.sent.single.$2!['songs'] as List<dynamic>;
    expect(songs.length, kJamMaxSongs);
    expect((songs.first as Map<String, dynamic>)['id'], '10');
    expect(remote.sent.single.$2!['start_index'], 0);
  });

  testWidgets('add to queue sends enqueue', (WidgetTester t) async {
    final _FakeRemote remote = _FakeRemote();
    await _run(
      t,
      remote,
      handler,
      (WidgetRef ref, BuildContext c) => addSongsToQueue(ref, c, <Song>[_b]),
    );
    expect(remote.sent.single.$1, 'enqueue');
    verifyZeroInteractions(handler);
  });

  testWidgets('preview and shuffle-all are blocked while joined', (
    WidgetTester t,
  ) async {
    final _FakeRemote remote = _FakeRemote();
    await _run(
      t,
      remote,
      handler,
      (WidgetRef ref, BuildContext c) => playPreview(
        ref,
        c,
        const SearchResultItem(
          title: 'x',
          artist: 'y',
          sourceUrl: 'u',
          sourceType: 'song',
          alreadyDownloaded: false,
        ),
      ),
    );
    expect(
      find.text('Not available while controlling aashish'),
      findsOneWidget,
    );
    await _run(
      t,
      remote,
      handler,
      (WidgetRef ref, BuildContext c) => shuffleAllSongsFromSubsonic(ref, c),
    );
    expect(find.text('Not available while controlling aashish'), findsWidgets);
    expect(remote.sent, isEmpty);
    verifyZeroInteractions(handler);
  });

  testWidgets('ended session (404) leaves', (WidgetTester t) async {
    final _FakeRemote remote = _FakeRemote(fail: const NotFoundError());
    late ProviderContainer container;
    await _run(t, remote, handler, (WidgetRef ref, BuildContext c) {
      container = ProviderScope.containerOf(c);
      return playSongFromSubsonic(ref, c, _a);
    });
    expect(container.read(jamRemoteProvider), isNull);
    expect(find.textContaining('Jam session ended'), findsOneWidget);
  });
}
