import 'package:audio_service/audio_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/jam.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/jam_host.dart';
import 'package:heerr/services/backend_service.dart';

class _MockBackend extends Mock implements BackendService {}

class _MockHandler extends Mock implements HeerrAudioHandler {}

JamSyncResponse _resp(
  List<JamCommand> cmds,
  int cursor, {
  bool ended = false,
}) => JamSyncResponse(commands: cmds, cursor: cursor, ended: ended);

MediaItem _item(String id) => MediaItem(
  id: 'http://nd/$id',
  title: id,
  extras: <String, dynamic>{'subsonicId': id},
);

void main() {
  late _MockBackend backend;
  late _MockHandler handler;
  late BehaviorSubject<MediaItem?> mediaItem;
  late BehaviorSubject<PlaybackState> playback;
  late BehaviorSubject<List<MediaItem>> queue;
  late List<int?> afters;
  late List<double> waits;
  late List<Map<String, dynamic>> pushes;
  late List<JamSyncResponse> script;
  late List<String> calls;

  setUp(() {
    backend = _MockBackend();
    handler = _MockHandler();
    mediaItem = BehaviorSubject<MediaItem?>.seeded(null);
    playback = BehaviorSubject<PlaybackState>.seeded(PlaybackState());
    queue = BehaviorSubject<List<MediaItem>>.seeded(<MediaItem>[]);
    when(() => handler.mediaItem).thenAnswer((_) => mediaItem);
    when(() => handler.playbackState).thenAnswer((_) => playback);
    when(() => handler.queue).thenAnswer((_) => queue);
    calls = <String>[];
    when(() => handler.pause()).thenAnswer((_) async => calls.add('pause'));
    when(() => handler.skipToNext()).thenAnswer((_) async {
      // Slow command: the next one must wait for it.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      calls.add('next');
    });

    when(() => backend.jamCreate()).thenAnswer(
      (_) async =>
          JamSession(id: 's1', code: 'K7Q2MX', expiresAt: DateTime(2026)),
    );
    when(() => backend.jamEnd(any())).thenAnswer((_) async {});
    pushes = <Map<String, dynamic>>[];
    when(() => backend.jamPushState(any(), any())).thenAnswer(
      (Invocation inv) async =>
          pushes.add(inv.positionalArguments[1] as Map<String, dynamic>),
    );
    afters = <int?>[];
    waits = <double>[];
    script = <JamSyncResponse>[];
    when(
      () => backend.jamSync(
        any(),
        state: any(named: 'state'),
        after: any(named: 'after'),
        waitS: any(named: 'waitS'),
      ),
    ).thenAnswer((Invocation inv) async {
      afters.add(inv.namedArguments[#after] as int?);
      waits.add(inv.namedArguments[#waitS] as double);
      if (script.isEmpty) {
        // Simulates the long-poll holding with nothing to deliver.
        await Future<void>.delayed(const Duration(seconds: 8));
        return _resp(<JamCommand>[], afters.last ?? 0);
      }
      final JamSyncResponse r = script.removeAt(0);
      if (r.cursor < 0) throw const NetworkError();
      return r;
    });
  });

  tearDown(() {
    mediaItem.close();
    playback.close();
    queue.close();
  });

  ProviderContainer container() => ProviderContainer(
    overrides: <Override>[
      backendServiceProvider.overrideWith((_) async => backend),
      audioHandlerProvider.overrideWithValue(handler),
      jamHostPollIntervalProvider.overrideWith(
        (_) => const Duration(seconds: 1),
      ),
    ],
  );

  test('bootstraps, then long-polls; commands run in order, one at a time', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamSyncResponse>[
        _resp(<JamCommand>[], 5), // bootstrap
        _resp(const <JamCommand>[
          JamCommand(id: 6, kind: 'next'),
          JamCommand(id: 7, kind: 'pause'),
        ], 7),
      ];
      c.read(jamHostProvider.notifier).start();
      fa.flushMicrotasks();
      expect(c.read(jamHostProvider)!.code, 'K7Q2MX');
      expect(afters, <int?>[null]);
      expect(waits, <double>[0]);

      fa.elapse(const Duration(milliseconds: 150)); // loop gap -> 2nd sync
      expect(calls, <String>[]); // `next` still running
      fa.elapse(const Duration(milliseconds: 300));
      expect(calls, <String>['next', 'pause']);
      expect(c.read(jamHostProvider)!.commandsReceived, 2);

      fa.elapse(const Duration(milliseconds: 150));
      expect(afters, <int?>[null, 5, 7]);
      expect(waits.skip(1), everyElement(kJamLongPollWaitS));
    });
  });

  test('ended stops polling and clears state', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamSyncResponse>[
        _resp(<JamCommand>[], 0),
        _resp(<JamCommand>[], 0, ended: true),
      ];
      c.read(jamHostProvider.notifier).start();
      fa.elapse(const Duration(milliseconds: 200));
      expect(c.read(jamHostProvider), isNull);
      fa.elapse(const Duration(seconds: 30));
      expect(afters.length, 2);
    });
  });

  test('a sync error is surfaced and retried after the retry delay', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamSyncResponse>[
        _resp(<JamCommand>[], 0),
        _resp(<JamCommand>[], -1), // throws
        _resp(<JamCommand>[], 0),
      ];
      c.read(jamHostProvider.notifier).start();
      fa.elapse(const Duration(milliseconds: 200));
      expect(c.read(jamHostProvider)!.error, isA<NetworkError>());
      expect(afters.length, 2);
      fa.elapse(const Duration(milliseconds: 700));
      expect(afters.length, 2); // still backing off
      fa.elapse(const Duration(milliseconds: 250));
      expect(afters.length, 3);
      expect(c.read(jamHostProvider)!.error, isNull);
    });
  });

  test('player changes are pushed at once (debounced); idle is not', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamSyncResponse>[_resp(<JamCommand>[], 0)];
      c.read(jamHostProvider.notifier).start();
      fa.elapse(const Duration(seconds: 1));
      expect(pushes, isEmpty); // nothing changed since the sync

      mediaItem.add(_item('a'));
      playback.add(
        PlaybackState(
          playing: true,
          processingState: AudioProcessingState.ready,
        ),
      );
      fa.elapse(const Duration(milliseconds: 200));
      expect(pushes.length, 1); // two events, one push
      expect((pushes.single['current'] as Map<String, dynamic>)['id'], 'a');
      expect(pushes.single['playing'], true);

      // Paused (no extrapolation on either side): a small position change
      // is not pushed...
      playback.add(PlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
        updatePosition: const Duration(seconds: 10),
      ));
      fa.elapse(const Duration(milliseconds: 200));
      expect(pushes.length, 2); // play -> pause is a change
      playback.add(PlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
        updatePosition: const Duration(seconds: 11),
      ));
      fa.elapse(const Duration(milliseconds: 200));
      expect(pushes.length, 2);

      // ...a seek far away is.
      playback.add(PlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
        updatePosition: const Duration(seconds: 90),
      ));
      fa.elapse(const Duration(milliseconds: 200));
      expect(pushes.length, 3);
      expect(pushes.last['position_ms'], 90000);
    });
  });

  test('stop ends the session server-side and stops polling + pushing', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      c.read(jamHostProvider.notifier).start();
      fa.flushMicrotasks();
      c.read(jamHostProvider.notifier).stop();
      mediaItem.add(_item('a'));
      fa.elapse(const Duration(seconds: 30));
      verify(() => backend.jamEnd('s1')).called(1);
      expect(c.read(jamHostProvider), isNull);
      expect(afters.length, 1);
      expect(pushes, isEmpty);
    });
  });
}
