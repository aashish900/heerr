import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/jam_host.dart';
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

Future<_FakeJamHost> _pump(
  WidgetTester tester, [
  JamHostStatus? initial,
]) async {
  final _FakeJamHost fake = _FakeJamHost(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[jamHostProvider.overrideWith(() => fake)],
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
}
