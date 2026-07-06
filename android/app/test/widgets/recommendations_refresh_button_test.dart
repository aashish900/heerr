import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/widgets/recommendations_refresh_button.dart';

class _StubRecs extends Recommendations {
  _StubRecs([Future<List<RecommendedTrack>>? future])
      : _future = future ?? Future<List<RecommendedTrack>>.value(
            const <RecommendedTrack>[]);
  final Future<List<RecommendedTrack>> _future;
  int refreshCalls = 0;

  @override
  Future<List<RecommendedTrack>> build() => _future;

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }
}

Widget _wrap(_StubRecs stub, {VoidCallback? onBeforeRefresh}) {
  return ProviderScope(
    overrides: <Override>[
      recommendationsProvider.overrideWith(() => stub),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: RecommendationsRefreshButton(
            key: const Key('recs-refresh'),
            onBeforeRefresh: onBeforeRefresh,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('idle: bare icon, no tonal disc; tap fires refresh',
      (WidgetTester tester) async {
    final _StubRecs stub = _StubRecs();
    await tester.pumpWidget(_wrap(stub));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recs-refresh-busy')), findsNothing);

    await tester.tap(find.byKey(const Key('recs-refresh')));
    await tester.pump();

    expect(stub.refreshCalls, 1);
  });

  testWidgets('busy: tonal disc variant renders; taps are no-ops',
      (WidgetTester tester) async {
    final Completer<List<RecommendedTrack>> never =
        Completer<List<RecommendedTrack>>();
    final _StubRecs stub = _StubRecs(never.future);
    await tester.pumpWidget(_wrap(stub));
    // No pumpAndSettle — provider never resolves + spin animation repeats.
    await tester.pump();

    expect(find.byKey(const Key('recs-refresh-busy')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recs-refresh')));
    await tester.pump();

    expect(stub.refreshCalls, 0);
  });

  testWidgets('onBeforeRefresh runs before the refresh call',
      (WidgetTester tester) async {
    final List<String> order = <String>[];
    final _StubRecs stub = _StubRecs();
    await tester.pumpWidget(_wrap(
      stub,
      onBeforeRefresh: () => order.add('before'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recs-refresh')));
    await tester.pump();

    expect(order, <String>['before']);
    expect(stub.refreshCalls, 1);
  });
}
