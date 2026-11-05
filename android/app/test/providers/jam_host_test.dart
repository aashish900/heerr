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

void main() {
  late _MockBackend backend;
  late _MockHandler handler;
  late BehaviorSubject<MediaItem?> mediaItem;
  late BehaviorSubject<PlaybackState> playback;
  late BehaviorSubject<List<MediaItem>> queue;
  late List<int?> afters;
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
    when(() => handler.play()).thenAnswer((_) async => calls.add('play'));

    when(() => backend.jamCreate()).thenAnswer(
      (_) async =>
          JamSession(id: 's1', code: 'K7Q2MX', expiresAt: DateTime(2026)),
    );
    when(() => backend.jamEnd(any())).thenAnswer((_) async {});
    afters = <int?>[];
    script = <JamSyncResponse>[];
    when(
      () => backend.jamSync(
        any(),
        state: any(named: 'state'),
        after: any(named: 'after'),
      ),
    ).thenAnswer((Invocation inv) async {
      afters.add(inv.namedArguments[#after] as int?);
      if (script.isEmpty) return _resp(<JamCommand>[], afters.last ?? 0);
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

  test('runs commands in order, one at a time, and advances the cursor', () {
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

      fa.elapse(const Duration(seconds: 1));
      expect(calls, <String>[]); // `next` still running
      fa.elapse(const Duration(milliseconds: 300));
      expect(calls, <String>['next', 'pause']);
      expect(c.read(jamHostProvider)!.commandsReceived, 2);

      fa.elapse(const Duration(seconds: 1));
      expect(afters, <int?>[null, 5, 7]);
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
      fa.elapse(const Duration(seconds: 1));
      expect(c.read(jamHostProvider), isNull);
      fa.elapse(const Duration(seconds: 5));
      expect(afters.length, 2);
    });
  });

  test('a sync error keeps polling and is surfaced', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamSyncResponse>[
        _resp(<JamCommand>[], 0),
        _resp(<JamCommand>[], -1), // throws
      ];
      c.read(jamHostProvider.notifier).start();
      fa.elapse(const Duration(seconds: 1));
      expect(c.read(jamHostProvider)!.error, isA<NetworkError>());
      fa.elapse(const Duration(seconds: 1));
      expect(afters.length, 3);
      expect(c.read(jamHostProvider)!.error, isNull);
    });
  });

  test('stop ends the session server-side and stops polling', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      c.read(jamHostProvider.notifier).start();
      fa.flushMicrotasks();
      c.read(jamHostProvider.notifier).stop();
      fa.elapse(const Duration(seconds: 5));
      verify(() => backend.jamEnd('s1')).called(1);
      expect(c.read(jamHostProvider), isNull);
      expect(afters.length, 1);
    });
  });
}
