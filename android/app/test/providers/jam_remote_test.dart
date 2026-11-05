import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/jam.dart';
import 'package:heerr/providers/jam_remote.dart';
import 'package:heerr/services/backend_service.dart';

class _MockBackend extends Mock implements BackendService {}

JamState _st(int n, {bool ended = false, bool playing = true}) => JamState(
  hostUsername: 'aashish',
  ended: ended,
  stateAt: DateTime.utc(2026, 11, 5, 0, 0, n),
  state: <String, dynamic>{'n': n, 'playing': playing, 'position_ms': 0},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBackend backend;
  late List<Object> script; // JamState, or an error to throw
  late List<(DateTime?, double)> calls;

  setUp(() {
    backend = _MockBackend();
    calls = <(DateTime?, double)>[];
    script = <Object>[];
    when(() => backend.jamJoin(any())).thenAnswer(
      (_) async =>
          JamJoin(id: 's1', hostUsername: 'aashish', expiresAt: DateTime(2026)),
    );
    when(
      () => backend.jamState(
        any(),
        since: any(named: 'since'),
        waitS: any(named: 'waitS'),
      ),
    ).thenAnswer((Invocation inv) async {
      calls.add((
        inv.namedArguments[#since] as DateTime?,
        inv.namedArguments[#waitS] as double,
      ));
      if (script.isEmpty) {
        // Long-poll holding with nothing new.
        await Future<void>.delayed(const Duration(seconds: 8));
        return _st(0);
      }
      final Object next = script.removeAt(0);
      if (next is JamState) return next;
      throw next;
    });
    when(() => backend.jamSend(any(), any(), any())).thenAnswer((_) async => 1);
  });

  ProviderContainer container() => ProviderContainer(
    overrides: <Override>[
      backendServiceProvider.overrideWith((_) async => backend),
      jamRemotePollIntervalProvider.overrideWith(
        (_) => const Duration(seconds: 2),
      ),
    ],
  );

  test(
    'join fetches state at once, then long-polls since the last state_at',
    () {
      fakeAsync((FakeAsync fa) {
        final ProviderContainer c = container();
        addTearDown(c.dispose);
        script = <Object>[_st(1), _st(2)];
        c.read(jamRemoteProvider.notifier).join(' k7q2mx ');
        fa.flushMicrotasks();
        verify(() => backend.jamJoin('k7q2mx')).called(1);
        expect(calls.first, (null, 0.0));
        expect(c.read(jamRemoteProvider)!.hostState!.state!['n'], 1);

        fa.elapse(const Duration(milliseconds: 200));
        expect(calls[1], (DateTime.utc(2026, 11, 5, 0, 0, 1), 8.0));
        expect(c.read(jamRemoteProvider)!.hostState!.state!['n'], 2);
      });
    },
  );

  test('ended host state leaves and stops polling', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <Object>[_st(1), _st(2, ended: true)];
      c.read(jamRemoteProvider.notifier).join('x');
      fa.elapse(const Duration(milliseconds: 200));
      expect(c.read(jamRemoteProvider), isNull);
      fa.elapse(const Duration(seconds: 30));
      expect(calls.length, 2);
    });
  });

  test('poll error keeps the snapshot and retries after the delay', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <Object>[_st(1), const NetworkError(), _st(2)];
      c.read(jamRemoteProvider.notifier).join('x');
      fa.elapse(const Duration(milliseconds: 200));
      expect(calls.length, 2);
      expect(c.read(jamRemoteProvider)!.hostState!.state!['n'], 1);
      fa.elapse(const Duration(milliseconds: 1500));
      expect(calls.length, 2); // backing off
      fa.elapse(const Duration(milliseconds: 500)); // retry at 2.15s
      expect(calls.length, 3);
      expect(c.read(jamRemoteProvider)!.hostState!.state!['n'], 2);
    });
  });

  test('paused lifecycle stops polling; resumed polls immediately', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <Object>[_st(1), _st(2), _st(3)];
      final JamRemote n = c.read(jamRemoteProvider.notifier);
      n.join('x');
      fa.flushMicrotasks();
      n.didChangeAppLifecycleState(AppLifecycleState.paused);
      fa.elapse(const Duration(seconds: 10));
      expect(calls.length, 1);
      n.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fa.flushMicrotasks();
      expect(calls.length, 2);
    });
  });

  test('play / pause / seek update the shown host state at once', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <Object>[_st(1)];
      final JamRemote n = c.read(jamRemoteProvider.notifier);
      n.join('x');
      fa.flushMicrotasks();

      n.send('pause');
      fa.flushMicrotasks();
      verify(
        () => backend.jamSend('s1', 'pause', <String, dynamic>{}),
      ).called(1);
      expect(c.read(jamRemoteProvider)!.hostState!.state!['playing'], false);

      n.send('seek', <String, dynamic>{'position_ms': 42000});
      fa.flushMicrotasks();
      expect(
        c.read(jamRemoteProvider)!.hostState!.state!['position_ms'],
        42000,
      );
      // state_at is untouched, so the long-poll still waits for the host.
      expect(
        c.read(jamRemoteProvider)!.hostState!.stateAt,
        DateTime.utc(2026, 11, 5, 0, 0, 1),
      );

      n.send('next');
      fa.flushMicrotasks();
      expect(c.read(jamRemoteProvider)!.hostState!.state!['n'], 1);
    });
  });

  test('leave clears and stops polling', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <Object>[_st(1)];
      final JamRemote n = c.read(jamRemoteProvider.notifier);
      n.join('x');
      fa.flushMicrotasks();
      n.leave();
      expect(c.read(jamRemoteProvider), isNull);
      fa.elapse(const Duration(seconds: 30));
      expect(calls.length, 1); // left before the next long-poll started
    });
  });
}
