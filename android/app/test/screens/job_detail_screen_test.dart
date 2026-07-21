import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/episode_download_response.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/providers/job_status.dart';
import 'package:heerr/screens/job_detail_screen.dart';
import 'package:heerr/services/backend_service.dart';
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
  ContentType sourceType = ContentType.song,
  String? episodeId,
  DateTime? createdAt,
  DateTime? startedAt,
  DateTime? finishedAt,
  String? outputPath,
  String? error,
}) {
  return JobView(
    jobId: jobId,
    sourceUrl: uri,
    sourceType: sourceType,
    state: state,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 9, 12),
    startedAt: startedAt,
    finishedAt: finishedAt,
    outputPath: outputPath,
    error: error,
    episodeId: episodeId,
  );
}

class _StubBackend extends BackendService {
  _StubBackend() : super(Dio());

  final List<String> downloadSourceUrls = <String>[];
  final List<String> downloadPodcastEpisodeIds = <String>[];

  @override
  Future<DownloadResponse> download({
    required String sourceUrl,
    required String sourceType,
    String? displayName,
  }) async {
    downloadSourceUrls.add(sourceUrl);
    return const DownloadResponse(
      jobId: 'new-job',
      state: JobState.queued,
      deduped: false,
    );
  }

  @override
  Future<EpisodeDownloadResponse> downloadPodcastEpisode(
    String episodeId,
  ) async {
    downloadPodcastEpisodeIds.add(episodeId);
    return const EpisodeDownloadResponse(
      jobId: 'new-episode-job',
      state: JobState.queued,
      deduped: false,
    );
  }
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
      error: 'download tool: track not found',
      finishedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      _wrap(j.jobId, <Override>[_jobValue(j.jobId, AsyncData<JobView>(j))]),
    );
    await tester.pumpAndSettle();

    expect(find.text('failed'), findsOneWidget);
    expect(find.text('download tool: track not found'), findsOneWidget);
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

  group('retry (#53)', () {
    testWidgets('retrying a failed song job re-dispatches via POST /download',
        (WidgetTester tester) async {
      final _StubBackend backend = _StubBackend();
      final JobView j = _job(
        state: JobState.failed,
        uri: 'https://www.youtube.com/watch?v=song1',
        error: 'boom',
      );
      await tester.pumpWidget(_wrap(j.jobId, <Override>[
        _jobValue(j.jobId, AsyncData<JobView>(j)),
        backendServiceProvider.overrideWith((_) async => backend),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry download'));
      await tester.pumpAndSettle();

      expect(backend.downloadSourceUrls, <String>['https://www.youtube.com/watch?v=song1']);
      expect(backend.downloadPodcastEpisodeIds, isEmpty);
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets(
        'retrying a failed episode job re-dispatches via '
        'POST /podcasts/episodes/{id}/download, not /download',
        (WidgetTester tester) async {
      final _StubBackend backend = _StubBackend();
      final JobView j = _job(
        state: JobState.failed,
        sourceType: ContentType.episode,
        episodeId: 'ep-1',
        uri: 'https://feeds.fountain.fm/x/items/y/files/AUDIO.mp3',
        error: "PermissionError: [Errno 13] Permission denied: '/data/media/podcasts'",
      );
      await tester.pumpWidget(_wrap(j.jobId, <Override>[
        _jobValue(j.jobId, AsyncData<JobView>(j)),
        backendServiceProvider.overrideWith((_) async => backend),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry download'));
      await tester.pumpAndSettle();

      expect(backend.downloadPodcastEpisodeIds, <String>['ep-1']);
      expect(backend.downloadSourceUrls, isEmpty);
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets(
        'retrying a failed episode job with no episodeId shows an error, '
        'dispatches nothing', (WidgetTester tester) async {
      final _StubBackend backend = _StubBackend();
      final JobView j = _job(
        state: JobState.failed,
        sourceType: ContentType.episode,
        error: 'boom',
      );
      await tester.pumpWidget(_wrap(j.jobId, <Override>[
        _jobValue(j.jobId, AsyncData<JobView>(j)),
        backendServiceProvider.overrideWith((_) async => backend),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry download'));
      await tester.pumpAndSettle();

      expect(backend.downloadPodcastEpisodeIds, isEmpty);
      expect(backend.downloadSourceUrls, isEmpty);
      expect(find.text("Can't retry: missing episode id"), findsOneWidget);
    });
  });
}
