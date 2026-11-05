import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/jam.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/jam_host.dart';
import 'package:heerr/providers/jam_remote.dart';
import 'package:heerr/screens/jam_screen.dart';

/// Fake host: no backend, no timer — start/stop just flip the state.
class _FakeJamHost extends JamHost {
  _FakeJamHost([this._initial]);

  final JamHostStatus? _initial;
  int stops = 0;

  @override
  JamHostStatus? build() => _initial;

  @override
  Future<void> start() async {
    state = const JamHostStatus(sessionId: 's1', code: 'K7Q2MX');
  }

  @override
  Future<void> stop() async {
    stops++;
    state = null;
  }
}

/// Fake guest: records joins / sends, no polling.
class _FakeRemote extends JamRemote {
  _FakeRemote([this._initial]);

  final JamRemoteStatus? _initial;
  final List<String> sent = <String>[];
  String? joinedWith;

  @override
  JamRemoteStatus? build() => _initial;

  @override
  Future<void> join(String code) async {
    joinedWith = code;
    state = const JamRemoteStatus(sessionId: 's1', hostUsername: 'aashish');
  }

  @override
  Future<void> send(String kind, [Map<String, dynamic>? payload]) async =>
      sent.add(kind);

  @override
  void leave() => state = null;
}

Future<_FakeJamHost> _pump(
  WidgetTester tester, [
  JamHostStatus? initial,
  _FakeRemote? remote,
]) async {
  final _FakeJamHost fake = _FakeJamHost(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        jamHostProvider.overrideWith(() => fake),
        jamRemoteProvider.overrideWith(() => remote ?? _FakeRemote()),
      ],
      child: const MaterialApp(home: JamScreen()),
    ),
  );
  return fake;
}

void main() {
  testWidgets('idle shows Start; Start shows the code', (WidgetTester t) async {
    await _pump(t);
    expect(find.byKey(const Key('jam-code')), findsNothing);
    await t.tap(find.byKey(const Key('jam-start')));
    await t.pump();
    expect(find.text('K7Q2MX'), findsOneWidget);
    expect(find.byKey(const Key('jam-stop')), findsOneWidget);
  });

  testWidgets('Stop returns to idle', (WidgetTester t) async {
    final _FakeJamHost fake = await _pump(
      t,
      const JamHostStatus(sessionId: 's1', code: 'ABC234'),
    );
    await t.tap(find.byKey(const Key('jam-stop')));
    await t.pump();
    expect(fake.stops, 1);
    expect(find.byKey(const Key('jam-start')), findsOneWidget);
  });

  testWidgets('sync error shows reconnecting', (WidgetTester t) async {
    await _pump(
      t,
      JamHostStatus(
        sessionId: 's1',
        code: 'ABC234',
        commandsReceived: 3,
        error: Exception(),
      ),
    );
    expect(find.text('Commands received: 3'), findsOneWidget);
    expect(find.byKey(const Key('jam-reconnecting')), findsOneWidget);
  });

  testWidgets('join with a code shows the joined view', (WidgetTester t) async {
    final _FakeRemote remote = _FakeRemote();
    await _pump(t, null, remote);
    await t.enterText(find.byKey(const Key('jam-code-field')), 'k7q2mx');
    await t.tap(find.byKey(const Key('jam-join')));
    await t.pump();
    expect(remote.joinedWith, 'k7q2mx');
    expect(find.text("Controlling aashish's phone"), findsOneWidget);
    expect(find.text('Nothing playing'), findsOneWidget);
  });

  testWidgets('joined view shows host now-playing and sends transport', (
    WidgetTester t,
  ) async {
    final _FakeRemote remote = _FakeRemote(
      JamRemoteStatus(
        sessionId: 's1',
        hostUsername: 'aashish',
        hostState: JamState(
          hostUsername: 'aashish',
          ended: false,
          state: <String, dynamic>{
            'playing': true,
            'position_ms': 30000,
            'current': const Song(
              id: 'a',
              title: 'Tum Hi Ho',
              duration: 260,
            ).toJson(),
            'queue': <dynamic>[
              const Song(id: 'a', title: 'Tum Hi Ho').toJson(),
              const Song(id: 'b', title: 'Kesariya').toJson(),
            ],
          },
        ),
      ),
    );
    await _pump(t, null, remote);
    expect(find.text('Tum Hi Ho'), findsOneWidget);
    expect(find.text('Kesariya'), findsOneWidget); // up next
    expect(find.byKey(const Key('jam-seek')), findsOneWidget);
    await t.tap(find.byKey(const Key('jam-playpause')));
    await t.tap(find.byKey(const Key('jam-next')));
    await t.pump();
    expect(remote.sent, <String>['pause', 'next']);
    await t.tap(find.byKey(const Key('jam-leave')));
    await t.pump();
    expect(find.byKey(const Key('jam-start')), findsOneWidget);
  });
}
