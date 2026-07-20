import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/episode_feed_response.dart';
import 'package:heerr/models/episode_with_channel.dart';
import 'package:heerr/providers/podcasts/podcast_episode_feed.dart';
import 'package:heerr/services/backend_service.dart';

class _StubBackend extends BackendService {
  _StubBackend(this._response) : super(Dio());
  final EpisodeFeedResponse _response;
  final List<String> filtersSeen = <String>[];

  @override
  Future<EpisodeFeedResponse> podcastEpisodeFeed(
    String filter, {
    int limit = 20,
    int offset = 0,
  }) async {
    filtersSeen.add(filter);
    return _response;
  }
}

void main() {
  const EpisodeWithChannel episode = EpisodeWithChannel(
    id: 'e1',
    channelId: 'c1',
    channelTitle: 'Show A',
    guid: 'g1',
    title: 'Episode 1',
    enclosureUrl: 'https://a.com/e1.mp3',
    downloaded: false,
    positionS: 0,
    played: false,
  );

  test('forwards the filter to the backend and returns its response',
      () async {
    final _StubBackend backend = _StubBackend(
      const EpisodeFeedResponse(episodes: <EpisodeWithChannel>[episode], total: 1),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    final EpisodeFeedResponse result =
        await container.read(podcastEpisodeFeedProvider('latest').future);

    expect(backend.filtersSeen, <String>['latest']);
    expect(result.total, 1);
    expect(result.episodes.single.title, 'Episode 1');
  });

  test('different filters resolve to independent provider instances',
      () async {
    final _StubBackend backend = _StubBackend(
      const EpisodeFeedResponse(episodes: <EpisodeWithChannel>[], total: 0),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    await container.read(podcastEpisodeFeedProvider('in_progress').future);
    await container.read(podcastEpisodeFeedProvider('downloaded').future);

    expect(backend.filtersSeen, <String>['in_progress', 'downloaded']);
  });
}
