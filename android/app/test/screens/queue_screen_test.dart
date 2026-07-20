import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/episode_download_response.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/queue_screen.dart';
import 'package:heerr/services/backend_service.dart';
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
  String uri = 'https://www.youtube.com/watch?v=test',
  ContentType sourceType = ContentType.song,
  String? episodeId,
}) {
  return JobView(
    jobId: jobId,
    sourceUrl: uri,
    sourceType: sourceType,
    state: state,
    createdAt: DateTime.utc(2026, 6, 9, 12),
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

  group('retry (#53)', () {
    testWidgets('retrying a song job re-dispatches via POST /download',
        (WidgetTester tester) async {
      final _StubBackend backend = _StubBackend();
      await tester.pumpWidget(_wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: const <JobView>[],
          recent: <JobView>[
            _job(
              jobId: 'song-job',
              state: JobState.failed,
              uri: 'https://www.youtube.com/watch?v=song1',
            ),
          ],
        ))),
        backendServiceProvider.overrideWith((_) async => backend),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(backend.downloadSourceUrls, <String>['https://www.youtube.com/watch?v=song1']);
      expect(backend.downloadPodcastEpisodeIds, isEmpty);
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets(
        'retrying an episode job re-dispatches via '
        'POST /podcasts/episodes/{id}/download, not /download',
        (WidgetTester tester) async {
      final _StubBackend backend = _StubBackend();
      await tester.pumpWidget(_wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: const <JobView>[],
          recent: <JobView>[
            _job(
              jobId: 'episode-job',
              state: JobState.failed,
              sourceType: ContentType.episode,
              episodeId: 'ep-1',
              uri: 'https://anchor.fm/s/x/podcast/play/1/https%3A%2F%2Fcdn.example.com%2Fe.mp3',
            ),
          ],
        ))),
        backendServiceProvider.overrideWith((_) async => backend),
      ]));
      await tester.pumpAndSettle();

      // The Podcasts tab, not Music, is where an episode job shows up.
      await tester.tap(find.text('Podcasts'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(backend.downloadPodcastEpisodeIds, <String>['ep-1']);
      expect(backend.downloadSourceUrls, isEmpty);
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('retrying an episode job with no episodeId shows an error, '
        'dispatches nothing', (WidgetTester tester) async {
      final _StubBackend backend = _StubBackend();
      await tester.pumpWidget(_wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: const <JobView>[],
          recent: <JobView>[
            _job(
              jobId: 'episode-job-no-id',
              state: JobState.failed,
              sourceType: ContentType.episode,
            ),
          ],
        ))),
        backendServiceProvider.overrideWith((_) async => backend),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Podcasts'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(backend.downloadPodcastEpisodeIds, isEmpty);
      expect(backend.downloadSourceUrls, isEmpty);
      expect(find.text("Can't retry: missing episode id"), findsOneWidget);
    });
  });

  group('Music / Podcasts content switch (#53)', () {
    testWidgets('Music tab shows only song jobs; Podcasts tab shows only '
        'episode jobs', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: <JobView>[
            _job(jobId: 'song-1', state: JobState.running),
          ],
          recent: <JobView>[
            _job(
              jobId: 'episode-1',
              state: JobState.done,
              sourceType: ContentType.episode,
              episodeId: 'ep-1',
            ),
          ],
        ))),
      ]));
      await tester.pumpAndSettle();

      // Default tab is Music.
      expect(find.text('job song-1'), findsOneWidget);
      expect(find.text('job episode-'), findsNothing);

      await tester.tap(find.text('Podcasts'));
      await tester.pumpAndSettle();

      expect(find.text('job song-1'), findsNothing);
      expect(find.text('job episode-'), findsOneWidget);
    });

    testWidgets('Podcasts tab with no episode jobs shows the podcast empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<Override>[
        _queueValue(AsyncData<QueueResponse>(QueueResponse(
          active: <JobView>[_job(jobId: 'song-only')],
          recent: const <JobView>[],
        ))),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Podcasts'));
      await tester.pumpAndSettle();

      expect(find.text('No jobs yet'), findsOneWidget);
      expect(find.text('Download a podcast episode to see it here'), findsOneWidget);
    });
  });
}
