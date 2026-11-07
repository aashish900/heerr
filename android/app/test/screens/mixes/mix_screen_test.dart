import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/mix.dart';
import 'package:heerr/models/profile_meta.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/download.dart';
import 'package:heerr/providers/mix_saver.dart';
import 'package:heerr/providers/mixes.dart';
import 'package:heerr/providers/profiles/profile_meta.dart';
import 'package:heerr/router.dart' show Routes;
import 'package:heerr/screens/mixes/mix_screen.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/widgets/skeleton.dart';

import '../../support/cred_test_support.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

class _StubMix extends MixNotifier {
  _StubMix(this._load);
  final Future<MixResponse> Function() _load;
  int builds = 0;
  int regenerateCalls = 0;

  @override
  Future<MixResponse> build(String id) {
    builds++;
    return _load();
  }

  @override
  Future<void> regenerate() async => regenerateCalls++;
}

class _StubSaver extends MixSaver {
  _StubSaver([this._initial]);
  final MixSaveState? _initial;
  final List<(String, int)> saves = <(String, int)>[];

  @override
  MixSaveState? build(String mixId) => _initial;

  @override
  Future<void> save({
    required String title,
    required List<RecommendedTrack> tracks,
  }) async {
    saves.add((title, tracks.length));
  }
}

class _StubMeta extends ProfileMetaNotifier {
  _StubMeta(this._nickname);
  final String? _nickname;

  @override
  Future<ProfileMeta> build() async => ProfileMeta(nickname: _nickname);
}

class _RecordingDispatcher extends DownloadDispatcher {
  final List<String> urls = <String>[];

  @override
  Set<String> build() => const <String>{};

  @override
  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    urls.add(sourceUrl);
    return const DownloadResponse(
      jobId: 'j',
      state: JobState.queued,
      deduped: false,
    );
  }
}

RecommendedTrack _track(int i) => RecommendedTrack(
  title: 'Song $i',
  artist: 'Artist $i',
  sourceUrl: 'https://music.youtube.com/watch?v=v$i',
);

MixResponse _mix({int n = 4, bool personalized = true}) => MixResponse(
  id: 'chill',
  title: 'Chill Mix',
  personalized: personalized,
  results: List<RecommendedTrack>.generate(n, _track),
);

Widget _wrap(
  _StubMix stub, {
  String? nickname = 'Aashish',
  HeerrAudioHandler? handler,
  _RecordingDispatcher? dispatcher,
  _StubSaver? saver,
}) {
  return ProviderScope(
    overrides: <Override>[
      mixNotifierProvider('chill').overrideWith(() => stub),
      mixSaverProvider('chill').overrideWith(() => saver ?? _StubSaver()),
      mixVibesProvider.overrideWith(
        (_) async => const <MixVibe>[MixVibe(id: 'chill', title: 'Chill Mix')],
      ),
      profileMetaNotifierProvider.overrideWith(() => _StubMeta(nickname)),
      activeProfileOverride(heerrBaseUrl: 'http://x:8000/api/v1'),
      if (handler != null) audioHandlerProvider.overrideWithValue(handler),
      if (dispatcher != null)
        downloadDispatcherProvider.overrideWith(() => dispatcher),
    ],
    child: MaterialApp(
      theme: heerrDarkTheme(),
      home: const MixScreen(vibeId: 'chill'),
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(<MediaItem>[]));

  test('route helper', () {
    expect(Routes.mix('chill'), '/mixes/chill');
  });

  testWidgets('loading: vibe title in the app bar + skeleton', (
    WidgetTester tester,
  ) async {
    final Completer<MixResponse> never = Completer<MixResponse>();
    await tester.pumpWidget(_wrap(_StubMix(() => never.future)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Chill Mix'), findsOneWidget);
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('error: message + Retry rebuilds the mix', (
    WidgetTester tester,
  ) async {
    final _StubMix stub = _StubMix(() async => throw Exception('503'));
    await tester.pumpWidget(_wrap(stub));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load this mix"), findsOneWidget);
    final int before = stub.builds;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(stub.builds, before + 1);
  });

  testWidgets('empty: nothing new for this vibe', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_StubMix(() async => _mix(n: 0))));
    await tester.pumpAndSettle();

    expect(find.text('Nothing new for this vibe'), findsOneWidget);
    expect(find.text('Play all'), findsNothing);
  });

  testWidgets('header: personalised mix is "Made for <nickname>" + count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(_StubMix(() async => _mix(n: 4))));
    await tester.pumpAndSettle();

    expect(find.text('Made for Aashish'), findsOneWidget);
    expect(find.text('4 songs'), findsOneWidget);
    for (int i = 0; i < 4; i++) {
      expect(find.text('Song $i'), findsOneWidget);
    }
  });

  testWidgets('header: no nickname → "Made for you"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_StubMix(() async => _mix()), nickname: null),
    );
    await tester.pumpAndSettle();
    expect(find.text('Made for you'), findsOneWidget);
  });

  testWidgets('header: unpersonalised mix says so', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_StubMix(() async => _mix(personalized: false))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Popular picks for this vibe'), findsOneWidget);
    expect(find.text('Made for Aashish'), findsNothing);
  });

  testWidgets('Play all queues every song from the first', (
    WidgetTester tester,
  ) async {
    final _MockHandler handler = _MockHandler();
    when(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      _wrap(_StubMix(() async => _mix(n: 3)), handler: handler),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play all'));
    await tester.pump();

    final VerificationResult v = verify(
      () => handler.playAll(
        captureAny(),
        startIndex: captureAny(named: 'startIndex'),
      ),
    );
    expect((v.captured[0] as List<MediaItem>).length, 3);
    expect(v.captured[1], 0);
  });

  testWidgets('tapping a row plays the mix from that song', (
    WidgetTester tester,
  ) async {
    final _MockHandler handler = _MockHandler();
    when(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      _wrap(_StubMix(() async => _mix(n: 4)), handler: handler),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Song 2'));
    await tester.pump();

    final VerificationResult v = verify(
      () => handler.playAll(
        captureAny(),
        startIndex: captureAny(named: 'startIndex'),
      ),
    );
    expect((v.captured[0] as List<MediaItem>).length, 4);
    expect(v.captured[1], 2);
  });

  testWidgets('row download queues that song without playing', (
    WidgetTester tester,
  ) async {
    final _MockHandler handler = _MockHandler();
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    await tester.pumpWidget(
      _wrap(
        _StubMix(() async => _mix(n: 2)),
        handler: handler,
        dispatcher: dispatcher,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download Song 1'));
    await tester.pump();

    expect(dispatcher.urls, <String>['https://music.youtube.com/watch?v=v1']);
    verifyNever(
      () => handler.playAll(any(), startIndex: any(named: 'startIndex')),
    );
  });

  testWidgets('Regenerate asks the notifier for a fresh mix', (
    WidgetTester tester,
  ) async {
    final _StubMix stub = _StubMix(() async => _mix());
    await tester.pumpWidget(_wrap(stub));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Regenerate mix'));
    await tester.pump();
    expect(stub.regenerateCalls, 1);
  });

  // --- MX9: Save as playlist ------------------------------------------------

  testWidgets('Save as playlist hands the whole mix to the saver', (
    WidgetTester tester,
  ) async {
    final _StubSaver saver = _StubSaver();
    await tester.pumpWidget(
      _wrap(_StubMix(() async => _mix(n: 4)), saver: saver),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save as playlist'));
    await tester.pump();
    expect(saver.saves, <(String, int)>[('Chill Mix', 4)]);
  });

  testWidgets('while saving: "Saving x/y", disabled', (
    WidgetTester tester,
  ) async {
    final _StubSaver saver = _StubSaver(
      const MixSaveState(
        playlistName: 'Chill Mix · 7 Nov',
        total: 25,
        resolved: 12,
      ),
    );
    await tester.pumpWidget(_wrap(_StubMix(() async => _mix()), saver: saver));
    // The saving spinner animates forever, so pump frames, don't settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Saving 12/25'), findsOneWidget);
    await tester.tap(find.text('Saving 12/25'), warnIfMissed: false);
    await tester.pump();
    expect(saver.saves, isEmpty);
  });

  testWidgets('finished: summary with failures; button saves again', (
    WidgetTester tester,
  ) async {
    final _StubSaver saver = _StubSaver(
      const MixSaveState(
        playlistName: 'Chill Mix · 7 Nov',
        total: 25,
        resolved: 25,
        added: 23,
        failed: 2,
        done: true,
      ),
    );
    await tester.pumpWidget(_wrap(_StubMix(() async => _mix()), saver: saver));
    await tester.pumpAndSettle();

    expect(
      find.text('Saved 23 of 25 to "Chill Mix · 7 Nov" · 2 failed'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save as playlist'));
    await tester.pump();
    expect(saver.saves, hasLength(1));
  });

  testWidgets('finished without failures: plain summary', (
    WidgetTester tester,
  ) async {
    final _StubSaver saver = _StubSaver(
      const MixSaveState(
        playlistName: 'Chill Mix · 7 Nov',
        total: 4,
        resolved: 4,
        added: 4,
        done: true,
      ),
    );
    await tester.pumpWidget(_wrap(_StubMix(() async => _mix()), saver: saver));
    await tester.pumpAndSettle();
    expect(find.text('Saved 4 songs to "Chill Mix · 7 Nov"'), findsOneWidget);
  });

  testWidgets('failed run shows its error', (WidgetTester tester) async {
    final _StubSaver saver = _StubSaver(
      const MixSaveState(
        playlistName: 'Chill Mix · 7 Nov',
        total: 4,
        done: true,
        error: "Couldn't create the playlist",
      ),
    );
    await tester.pumpWidget(_wrap(_StubMix(() async => _mix()), saver: saver));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't create the playlist"), findsOneWidget);
    expect(find.text('Save as playlist'), findsOneWidget);
  });
}
