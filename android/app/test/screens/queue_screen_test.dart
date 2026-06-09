import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/queue_screen.dart';
import 'package:heerr/widgets/empty_state.dart';
import 'package:heerr/widgets/skeleton.dart';
import 'package:heerr/widgets/status_pill.dart';

// ---------------------------------------------------------------------------
// Helpers — override queueProvider with a controllable AsyncValue.
// ---------------------------------------------------------------------------

Override _queueValue(AsyncValue<QueueResponse> value) {
  return queueProvider.overrideWith(() {
    return _StubQueue(value);
  });
}

class _StubQueue extends Queue {
  _StubQueue(this._value);
  final AsyncValue<QueueResponse> _value;

  @override
  Future<QueueResponse> build() {
    return _value.when(
      data: (QueueResponse r) => Future<QueueResponse>.value(r),
      loading: () => Completer<QueueResponse>().future,
      error: (Object e, StackTrace st) => Future<QueueResponse>.error(e, st),
    );
  }

  @override
  void pause() {}
  @override
  Future<void> resume() async {}
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: QueueScreen()),
  );
}

JobView _job({
  String jobId = 'job-aaaaaaaa-1',
  JobState state = JobState.queued,
  String uri = 'spotify:track:abc',
}) {
  return JobView(
    jobId: jobId,
    spotifyUri: uri,
    spotifyType: SpotifyType.track,
    state: state,
    createdAt: DateTime.utc(2026, 6, 9, 12),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('loading state renders a SkeletonList', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<Override>[_queueValue(const AsyncLoading<QueueResponse>())]),
    );
    await tester.pump(); // do NOT pumpAndSettle (loading future never resolves)

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(SkeletonTile), findsWidgets);
  });

  testWidgets('empty state renders EmptyState "No jobs yet"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<Override>[
        _queueValue(const AsyncData<QueueResponse>(
          QueueResponse(active: <JobView>[], recent: <JobView>[]),
        )),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
  });

  testWidgets('both sections render with their job tiles and status pills', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: <JobView>[
            _job(jobId: 'aaa11111-act', state: JobState.running),
          ],
          recent: <JobView>[
            _job(jobId: 'bbb22222-don', state: JobState.done),
            _job(jobId: 'ccc33333-fai', state: JobState.failed),
          ],
        ))),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    // 3 job tiles total → 3 status pills.
    expect(find.byType(StatusPill), findsNWidgets(3));
    // Pill labels are present (case-sensitive lowercase per widget).
    expect(find.text('running'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
    expect(find.text('failed'), findsOneWidget);
    // Short ids surface in the subtitle.
    expect(find.text('job aaa11111'), findsOneWidget);
    expect(find.text('job bbb22222'), findsOneWidget);
    expect(find.text('job ccc33333'), findsOneWidget);
  });

  testWidgets('only-active list does not render the Recent section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: <JobView>[_job()],
          recent: const <JobView>[],
        ))),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Recent'), findsNothing);
  });

  testWidgets('error state renders ApiError.message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<Override>[
        _queueValue(AsyncError<QueueResponse>(
          const NetworkError(),
          StackTrace.current,
        )),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('cannot reach backend — check tailscale'), findsOneWidget);
  });

  group('StatusPill widget', () {
    testWidgets('renders the correct label per JobState', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              StatusPill(state: JobState.queued),
              StatusPill(state: JobState.running),
              StatusPill(state: JobState.done),
              StatusPill(state: JobState.failed),
            ],
          ),
        ),
      ));
      expect(find.text('queued'), findsOneWidget);
      expect(find.text('running'), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
      expect(find.text('failed'), findsOneWidget);
    });
  });
}
