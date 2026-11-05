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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBackend backend;
  late List<JamState> script;
  late int polls;

  setUp(() {
    backend = _MockBackend();
    polls = 0;
    script = <JamState>[];
    when(() => backend.jamJoin(any())).thenAnswer(
      (_) async =>
          JamJoin(id: 's1', hostUsername: 'aashish', expiresAt: DateTime(2026)),
    );
    when(() => backend.jamState(any())).thenAnswer((_) async {
      polls++;
      if (script.isEmpty) {
        return const JamState(hostUsername: 'aashish', ended: false);
      }
      final JamState s = script.removeAt(0);
      if (s.hostUsername == 'boom') throw const NetworkError();
      return s;
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

  test('join polls host state on the interval', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamState>[
        const JamState(
          hostUsername: 'aashish',
          ended: false,
          state: <String, dynamic>{'playing': true},
        ),
      ];
      c.read(jamRemoteProvider.notifier).join(' k7q2mx ');
      fa.flushMicrotasks();
      verify(() => backend.jamJoin('k7q2mx')).called(1);
      expect(c.read(jamRemoteProvider)!.hostState!.state!['playing'], true);
      fa.elapse(const Duration(seconds: 4));
      expect(polls, 3);
    });
  });

  test('ended host state leaves and stops polling', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamState>[
        const JamState(hostUsername: 'aashish', ended: false),
        const JamState(hostUsername: 'aashish', ended: true),
      ];
      c.read(jamRemoteProvider.notifier).join('x');
      fa.elapse(const Duration(seconds: 2));
      expect(c.read(jamRemoteProvider), isNull);
      fa.elapse(const Duration(seconds: 10));
      expect(polls, 2);
    });
  });

  test('poll error keeps the snapshot and keeps polling', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      script = <JamState>[
        const JamState(hostUsername: 'aashish', ended: false),
        const JamState(hostUsername: 'boom', ended: false),
      ];
      c.read(jamRemoteProvider.notifier).join('x');
      fa.elapse(const Duration(seconds: 4));
      expect(c.read(jamRemoteProvider), isNotNull);
      expect(polls, 3);
    });
  });

  test('paused lifecycle stops polling; resumed polls immediately', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      final JamRemote n = c.read(jamRemoteProvider.notifier);
      n.join('x');
      fa.flushMicrotasks();
      n.didChangeAppLifecycleState(AppLifecycleState.paused);
      fa.elapse(const Duration(seconds: 10));
      expect(polls, 1);
      n.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fa.flushMicrotasks();
      expect(polls, 2);
    });
  });

  test('send refreshes the host state sooner than the poll interval', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      final JamRemote n = c.read(jamRemoteProvider.notifier);
      n.join('x');
      fa.flushMicrotasks();
      expect(polls, 1);
      n.send('next');
      fa.elapse(const Duration(milliseconds: 1300));
      expect(polls, 2); // not waiting for the 2s tick
      fa.elapse(const Duration(seconds: 2));
      expect(polls, 3); // back on the normal cadence, single loop
    });
  });

  test('send forwards to the backend; leave clears', () {
    fakeAsync((FakeAsync fa) {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      final JamRemote n = c.read(jamRemoteProvider.notifier);
      n.join('x');
      fa.flushMicrotasks();
      n.send('pause');
      fa.flushMicrotasks();
      verify(
        () => backend.jamSend('s1', 'pause', <String, dynamic>{}),
      ).called(1);
      n.leave();
      expect(c.read(jamRemoteProvider), isNull);
      fa.elapse(const Duration(seconds: 10));
      expect(polls, 1);
    });
  });
}
