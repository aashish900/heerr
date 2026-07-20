import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/episode_list_response.dart';
import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/models/podcast_episode.dart';
import 'package:heerr/providers/podcasts/podcast_episodes.dart';
import 'package:heerr/services/backend_service.dart';

PodcastEpisode _ep(String id) => PodcastEpisode(
      id: id,
      channelId: 'c1',
      guid: 'guid-$id',
      title: 'Episode $id',
      enclosureUrl: 'https://ex.com/$id.mp3',
      downloaded: false,
      positionS: 0,
      played: false,
    );

class _StubBackend extends BackendService {
  _StubBackend(this._pages) : super(Dio());
  final List<EpisodeListResponse> _pages;
  int calls = 0;
  final List<int> offsetsSeen = <int>[];
  final List<String?> sortsSeen = <String?>[];

  @override
  Future<EpisodeListResponse> podcastEpisodes(
    String channelId, {
    int limit = 20,
    int offset = 0,
    String? sort,
  }) async {
    offsetsSeen.add(offset);
    sortsSeen.add(sort);
    final EpisodeListResponse page = _pages[calls];
    calls++;
    return page;
  }

  @override
  Future<PodcastChannel> refreshPodcastChannel(String channelId) async {
    return PodcastChannel(id: channelId, feedUrl: 'https://ex.com/f.xml', title: 'Show');
  }
}

void main() {
  test('build() loads the first page', () async {
    final _StubBackend backend = _StubBackend(<EpisodeListResponse>[
      EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1'), _ep('2')], total: 5),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    final PodcastEpisodePage page =
        await container.read(podcastEpisodesNotifierProvider('c1').future);

    expect(page.episodes, hasLength(2));
    expect(page.total, 5);
    expect(page.hasMore, isTrue);
    expect(backend.offsetsSeen, <int>[0]);
  });

  test('loadMore() appends the next page at the right offset', () async {
    final _StubBackend backend = _StubBackend(<EpisodeListResponse>[
      EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1'), _ep('2')], total: 3),
      EpisodeListResponse(episodes: <PodcastEpisode>[_ep('3')], total: 3),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    await container.read(podcastEpisodesNotifierProvider('c1').future);
    await container
        .read(podcastEpisodesNotifierProvider('c1').notifier)
        .loadMore();

    final PodcastEpisodePage page =
        container.read(podcastEpisodesNotifierProvider('c1')).valueOrNull!;
    expect(page.episodes.map((PodcastEpisode e) => e.id), <String>['1', '2', '3']);
    expect(page.hasMore, isFalse);
    expect(backend.offsetsSeen, <int>[0, 2]);
  });

  test('loadMore() no-ops once hasMore is false', () async {
    final _StubBackend backend = _StubBackend(<EpisodeListResponse>[
      EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1')], total: 1),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    await container.read(podcastEpisodesNotifierProvider('c1').future);
    await container
        .read(podcastEpisodesNotifierProvider('c1').notifier)
        .loadMore();

    expect(backend.calls, 1);
  });

  test('refresh() re-pulls the feed then reloads page 1', () async {
    final _StubBackend backend = _StubBackend(<EpisodeListResponse>[
      EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1')], total: 1),
      EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1'), _ep('2')], total: 2),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    await container.read(podcastEpisodesNotifierProvider('c1').future);
    await container.read(podcastEpisodesNotifierProvider('c1').notifier).refresh();

    final PodcastEpisodePage page =
        container.read(podcastEpisodesNotifierProvider('c1')).valueOrNull!;
    expect(page.episodes, hasLength(2));
    expect(backend.offsetsSeen, <int>[0, 0]);
  });

  group('setSort (PA2/PR3, #53)', () {
    test('reloads page 1 with the new sort', () async {
      final _StubBackend backend = _StubBackend(<EpisodeListResponse>[
        EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1'), _ep('2')], total: 2),
        EpisodeListResponse(episodes: <PodcastEpisode>[_ep('2'), _ep('1')], total: 2),
      ]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          backendServiceProvider.overrideWith((_) async => backend),
        ],
      );
      addTearDown(container.dispose);

      await container.read(podcastEpisodesNotifierProvider('c1').future);
      await container
          .read(podcastEpisodesNotifierProvider('c1').notifier)
          .setSort('oldest');

      final PodcastEpisodePage page =
          container.read(podcastEpisodesNotifierProvider('c1')).valueOrNull!;
      expect(page.episodes.map((PodcastEpisode e) => e.id), <String>['2', '1']);
      expect(backend.sortsSeen, <String?>[null, 'oldest']);
      expect(backend.offsetsSeen, <int>[0, 0]);
    });

    test('setting the same sort twice is a no-op', () async {
      final _StubBackend backend = _StubBackend(<EpisodeListResponse>[
        EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1')], total: 1),
        EpisodeListResponse(episodes: <PodcastEpisode>[_ep('1')], total: 1),
      ]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          backendServiceProvider.overrideWith((_) async => backend),
        ],
      );
      addTearDown(container.dispose);

      await container.read(podcastEpisodesNotifierProvider('c1').future);
      final PodcastEpisodesNotifier notifier =
          container.read(podcastEpisodesNotifierProvider('c1').notifier);
      await notifier.setSort('oldest');
      await notifier.setSort('oldest');

      expect(backend.calls, 2);
    });
  });
}
