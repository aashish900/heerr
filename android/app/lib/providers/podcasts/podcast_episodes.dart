import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/podcast_episode.dart';
import '../../services/backend_service.dart';

part 'podcast_episodes.g.dart';

/// Page size for `GET /podcasts/channels/{id}/episodes`.
const int kEpisodePageSize = 20;

/// One page-accumulated snapshot of a channel's episode list.
/// [total] is the channel's full episode count (server-side, capped at 300
/// by `services/feeds.py::_MAX_EPISODES`) — [hasMore] compares it against
/// how many episodes have been loaded so far.
class PodcastEpisodePage {
  const PodcastEpisodePage({required this.episodes, required this.total});

  final List<PodcastEpisode> episodes;
  final int total;

  bool get hasMore => episodes.length < total;
}

/// PC3 (#53): paginated episode list for one channel, family-keyed by
/// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
/// [refresh] re-pulls the RSS feed server-side
/// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
/// pull-to-refresh actually picks up newly-published episodes rather than
/// just re-reading the same cached rows.
@riverpod
class PodcastEpisodesNotifier extends _$PodcastEpisodesNotifier {
  late String _channelId;

  @override
  Future<PodcastEpisodePage> build(String channelId) async {
    _channelId = channelId;
    final BackendService backend =
        await ref.watch(backendServiceProvider.future);
    final result = await backend.podcastEpisodes(
      channelId,
      limit: kEpisodePageSize,
      offset: 0,
    );
    return PodcastEpisodePage(episodes: result.episodes, total: result.total);
  }

  /// Appends the next page. No-op while a load is already in flight or
  /// there's nothing more to fetch.
  Future<void> loadMore() async {
    final PodcastEpisodePage? current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final BackendService backend =
        await ref.read(backendServiceProvider.future);
    final result = await backend.podcastEpisodes(
      _channelId,
      limit: kEpisodePageSize,
      offset: current.episodes.length,
    );
    state = AsyncData<PodcastEpisodePage>(
      PodcastEpisodePage(
        episodes: <PodcastEpisode>[...current.episodes, ...result.episodes],
        total: result.total,
      ),
    );
  }

  /// Pull-to-refresh: re-pulls the RSS feed, then reloads from page 1.
  Future<void> refresh() async {
    final BackendService backend =
        await ref.read(backendServiceProvider.future);
    await backend.refreshPodcastChannel(_channelId);
    ref.invalidateSelf();
    await future;
  }
}
