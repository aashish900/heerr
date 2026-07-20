import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/enums.dart';
import 'package:heerr/models/episode_download_response.dart';
import 'package:heerr/providers/podcasts/podcast_episode_download.dart';
import 'package:heerr/services/backend_service.dart';

class _StubBackend extends BackendService {
  _StubBackend(this._response) : super(Dio());
  final EpisodeDownloadResponse _response;
  final List<String> calls = <String>[];

  @override
  Future<EpisodeDownloadResponse> downloadPodcastEpisode(
    String episodeId,
  ) async {
    calls.add(episodeId);
    return _response;
  }
}

void main() {
  test('dispatch() calls the backend and tracks + clears in-flight state',
      () async {
    final _StubBackend backend = _StubBackend(
      const EpisodeDownloadResponse(
        jobId: 'j1',
        state: JobState.queued,
        deduped: false,
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    final Future<EpisodeDownloadResponse> future = container
        .read(podcastEpisodeDownloadDispatcherProvider.notifier)
        .dispatch('e1');

    expect(
      container.read(podcastEpisodeDownloadDispatcherProvider),
      <String>{'e1'},
    );

    final EpisodeDownloadResponse res = await future;

    expect(res.jobId, 'j1');
    expect(backend.calls, <String>['e1']);
    expect(container.read(podcastEpisodeDownloadDispatcherProvider), isEmpty);
  });
}
