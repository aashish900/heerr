import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/playback_actions.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/jam_remote.dart';
import 'package:heerr/providers/profiles/active_profile.dart';

import '../support/cred_test_support.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

class _JoinedJam extends JamRemote {
  @override
  JamRemoteStatus? build() =>
      const JamRemoteStatus(sessionId: 's1', hostUsername: 'aashish');
}

SearchResultItem _item(int i) => SearchResultItem(
  sourceUrl: 'https://music.youtube.com/watch?v=v$i',
  sourceType: 'song',
  title: 'Song $i',
  artist: 'Artist $i',
  alreadyDownloaded: false,
);

Future<void> _run(
  WidgetTester t,
  HeerrAudioHandler handler,
  List<SearchResultItem> items, {
  int startIndex = 0,
  bool signedIn = true,
  bool jam = false,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        audioHandlerProvider.overrideWithValue(handler),
        if (signedIn)
          activeProfileOverride(heerrBaseUrl: 'http://x:8000/api/v1')
        else
          activeProfileProvider.overrideWithValue(null),
        if (jam) jamRemoteProvider.overrideWith(_JoinedJam.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) => TextButton(
              onPressed: () =>
                  playPreviews(ref, context, items, startIndex: startIndex),
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

  setUpAll(() => registerFallbackValue(<MediaItem>[]));
  setUp(() {
    handler = _MockHandler();
    when(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    ).thenAnswer((_) async {});
  });

  testWidgets('queues every item as a preview and starts at startIndex', (
    WidgetTester t,
  ) async {
    await _run(t, handler, <SearchResultItem>[
      _item(0),
      _item(1),
      _item(2),
    ], startIndex: 1);

    final VerificationResult v = verify(
      () => handler.playAll(
        captureAny(),
        startIndex: captureAny(named: 'startIndex'),
      ),
    );
    final List<MediaItem> queued = v.captured[0] as List<MediaItem>;
    expect(v.captured[1], 1);
    expect(queued.map((MediaItem m) => m.title).toList(), <String>[
      'Song 0',
      'Song 1',
      'Song 2',
    ]);
    expect(queued.every((MediaItem m) => m.extras?['preview'] == true), isTrue);
    expect(
      queued[2].extras?['sourceUrl'],
      'https://music.youtube.com/watch?v=v2',
    );
    expect(queued.first.id, startsWith('http://x:8000/api/v1/preview/stream'));
  });

  testWidgets('empty list does nothing', (WidgetTester t) async {
    await _run(t, handler, <SearchResultItem>[]);
    verifyNever(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    );
  });

  testWidgets('not signed in → explains, plays nothing', (
    WidgetTester t,
  ) async {
    await _run(t, handler, <SearchResultItem>[_item(0)], signedIn: false);
    expect(find.textContaining('Not signed in'), findsOneWidget);
    verifyNever(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    );
  });

  testWidgets('blocked while controlling a jam host', (WidgetTester t) async {
    await _run(t, handler, <SearchResultItem>[_item(0)], jam: true);
    expect(
      find.text('Not available while controlling aashish'),
      findsOneWidget,
    );
    verifyNever(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    );
  });
}
