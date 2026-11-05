import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/jam.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/jam_display.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/jam_remote.dart';
import 'package:heerr/providers/server_creds.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

class _FakeRemote extends JamRemote {
  _FakeRemote(this._initial, {this.fail});

  final JamRemoteStatus? _initial;
  final ApiError? fail;
  final List<(String, Map<String, dynamic>?)> sent =
      <(String, Map<String, dynamic>?)>[];

  @override
  JamRemoteStatus? build() => _initial;

  @override
  Future<void> send(String kind, [Map<String, dynamic>? payload]) async {
    if (fail != null) throw fail!;
    sent.add((kind, payload));
  }

  @override
  void leave() => state = null;
}

const JamRemoteStatus _joined = JamRemoteStatus(
  sessionId: 's1',
  hostUsername: 'aashish',
  hostState: JamState(
    hostUsername: 'aashish',
    ended: false,
    state: <String, dynamic>{
      'playing': true,
      'position_ms': 30000,
      'current': <String, dynamic>{
        'id': 'a',
        'title': 'Tum Hi Ho',
        'duration': 260,
      },
      'queue': <dynamic>[
        <String, dynamic>{'id': 'a', 'title': 'Tum Hi Ho'},
        <String, dynamic>{'id': 'b', 'title': 'Kesariya'},
        'garbage',
      ],
    },
  ),
);

List<Override> _overrides(_FakeRemote remote, _MockHandler handler) =>
    <Override>[
      jamRemoteProvider.overrideWith(() => remote),
      audioHandlerProvider.overrideWithValue(handler),
      serverCredsProvider.overrideWith(
        (_) => (
          navidromeBaseUrl: 'http://nd',
          navidromeUsername: 'g',
          navidromePassword: 'p',
        ),
      ),
    ];

void main() {
  test('joined: snapshot + queue come from the host state', () {
    final ProviderContainer c = ProviderContainer(
      overrides: _overrides(_FakeRemote(_joined), _MockHandler()),
    );
    addTearDown(c.dispose);

    final PlayerSnapshot s = c.read(displaySnapshotProvider).value!;
    expect(s.item!.title, 'Tum Hi Ho');
    expect(s.item!.duration, const Duration(seconds: 260));
    expect(s.item!.extras!['subsonicId'], 'a');
    expect(s.isPlaying, isTrue);
    expect(s.state.processingState, AudioProcessingState.ready);
    expect(s.position.inMilliseconds, greaterThanOrEqualTo(30000));

    final List<MediaItem> q = c.read(displayQueueProvider).value!;
    expect(q.map((MediaItem m) => m.title), <String>['Tum Hi Ho', 'Kesariya']);
  });

  group('playerTransport', () {
    late _MockHandler handler;

    setUp(() {
      handler = _MockHandler();
      when(() => handler.skipToNext()).thenAnswer((_) async {});
    });

    Future<ProviderContainer> run(
      WidgetTester t,
      _FakeRemote remote,
      Future<void> Function(WidgetRef ref) action,
    ) async {
      late ProviderContainer container;
      await t.pumpWidget(
        ProviderScope(
          overrides: _overrides(remote, handler),
          child: MaterialApp(
            home: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () => action(ref),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pump();
      return container;
    }

    testWidgets('joined: seek goes to the host', (WidgetTester t) async {
      final _FakeRemote remote = _FakeRemote(_joined);
      await run(
        t,
        remote,
        (WidgetRef ref) =>
            playerTransport(ref, 'seek', position: const Duration(seconds: 5)),
      );
      expect(remote.sent.single.$1, 'seek');
      expect(remote.sent.single.$2, <String, dynamic>{'position_ms': 5000});
      verifyZeroInteractions(handler);
    });

    testWidgets('not joined: drives the local handler', (WidgetTester t) async {
      final _FakeRemote remote = _FakeRemote(null);
      await run(t, remote, (WidgetRef ref) => playerTransport(ref, 'next'));
      verify(() => handler.skipToNext()).called(1);
      expect(remote.sent, isEmpty);
    });

    testWidgets('joined: 404 leaves the session', (WidgetTester t) async {
      final _FakeRemote remote = _FakeRemote(
        _joined,
        fail: const NotFoundError(),
      );
      final ProviderContainer c = await run(
        t,
        remote,
        (WidgetRef ref) => playerTransport(ref, 'next'),
      );
      expect(c.read(jamRemoteProvider), isNull);
      verifyZeroInteractions(handler);
    });
  });
}
