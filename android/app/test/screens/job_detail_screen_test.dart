import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/providers/job_status.dart';
import 'package:heerr/screens/job_detail_screen.dart';
import 'package:heerr/widgets/skeleton.dart';
import 'package:heerr/widgets/status_pill.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Override _jobValue(String jobId, AsyncValue<JobView> value) {
  return jobStatusProvider(jobId).overrideWith(() => _StubJobStatus(value));
}

class _StubJobStatus extends JobStatus {
  _StubJobStatus(this._value);
  final AsyncValue<JobView> _value;

  @override
  Future<JobView> build(String jobId) {
    return _value.when(
      data: (JobView j) => Future<JobView>.value(j),
      loading: () => Completer<JobView>().future,
      error: (Object e, StackTrace st) => Future<JobView>.error(e, st),
    );
  }
}

Widget _wrap(String jobId, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: JobDetailScreen(jobId: jobId)),
  );
}

JobView _job({
  String jobId = 'abc12345-rest-of-uuid',
  JobState state = JobState.running,
  String uri = 'https://www.youtube.com/watch?v=test',
  DateTime? createdAt,
  DateTime? startedAt,
  DateTime? finishedAt,
  String? outputPath,
  String? error,
}) {
  return JobView(
    jobId: jobId,
    sourceUrl: uri,
    sourceType: ContentType.song,
    state: state,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 9, 12),
    startedAt: startedAt,
    finishedAt: finishedAt,
    outputPath: outputPath,
    error: error,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('appbar shows short job id; loading renders skeleton', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap('abcdefgh-rest', <Override>[
        _jobValue('abcdefgh-rest', const AsyncLoading<JobView>()),
      ]),
    );
    await tester.pump();

    expect(find.text('Job abcdefgh'), findsOneWidget);
    // Several SkeletonBox stand-ins for the upcoming fields.
    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('renders the full body for a running job', (
    WidgetTester tester,
  ) async {
    final JobView j = _job(
      jobId: 'abcdefgh-rest',
      state: JobState.running,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      startedAt: DateTime.now().subtract(const Duration(minutes: 4)),
    );
    await tester.pumpWidget(
      _wrap('abcdefgh-rest', <Override>[
        _jobValue('abcdefgh-rest', AsyncData<JobView>(j)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StatusPill), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(find.text('https://www.youtube.com/watch?v=test'), findsOneWidget);
    expect(find.text('abcdefgh-rest'), findsOneWidget); // full job id field
    expect(find.textContaining('m ago'), findsWidgets); // relative timestamps
  });

  testWidgets('output_path is rendered with a tap-to-copy affordance', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      clipboardCalls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final JobView j = _job(
      state: JobState.done,
      outputPath: '/data/media/music/Artist/Song.mp3',
      finishedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      _wrap(j.jobId, <Override>[_jobValue(j.jobId, AsyncData<JobView>(j))]),
    );
    await tester.pumpAndSettle();

    expect(find.text('/data/media/music/Artist/Song.mp3'), findsOneWidget);

    await tester.tap(find.text('/data/media/music/Artist/Song.mp3'));
    await tester.pumpAndSettle();

    expect(
      clipboardCalls.any(
        (MethodCall c) =>
            c.method == 'Clipboard.setData' &&
            (c.arguments as Map<dynamic, dynamic>)['text'] ==
                '/data/media/music/Artist/Song.mp3',
      ),
      isTrue,
    );
    expect(find.text('Copied output path'), findsOneWidget);
  });

  testWidgets('failed job shows the error message in an error container', (
    WidgetTester tester,
  ) async {
    final JobView j = _job(
      state: JobState.failed,
      error: 'spotdl: track not found on yt',
      finishedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      _wrap(j.jobId, <Override>[_jobValue(j.jobId, AsyncData<JobView>(j))]),
    );
    await tester.pumpAndSettle();

    expect(find.text('failed'), findsOneWidget);
    expect(find.text('spotdl: track not found on yt'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('error state (provider future failed) shows ApiError.message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap('j1', <Override>[
        _jobValue(
          'j1',
          AsyncError<JobView>(
            const NetworkError(),
            StackTrace.current,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('cannot reach backend — check tailscale'), findsOneWidget);
  });

  testWidgets('queued job: no startedAt / finishedAt fields rendered', (
    WidgetTester tester,
  ) async {
    final JobView j = _job(state: JobState.queued);
    await tester.pumpWidget(
      _wrap(j.jobId, <Override>[_jobValue(j.jobId, AsyncData<JobView>(j))]),
    );
    await tester.pumpAndSettle();

    expect(find.text('STARTED'), findsNothing);
    expect(find.text('FINISHED'), findsNothing);
    expect(find.text('queued'), findsOneWidget);
  });
}
