import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/episode_feed_response.dart';
import '../../models/episode_with_channel.dart';
import '../../player/podcast_playback_actions.dart';
import '../../providers/podcasts/podcast_episode_feed.dart';
import '../../router.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/skeleton.dart';

/// PR3 (#53): the Podcasts half of Home's Music/Podcasts content switch —
/// a "Continue Listening" horizontal carousel (`filter=in_progress`) and a
/// "Latest Episodes" list (`filter=latest`, capped to the first
/// [_kLatestCap] rows — Home is a jumping-off point, not a full feed; the
/// full feed lives in Library > Podcasts > Episodes).
class HomePodcastsBody extends ConsumerWidget {
  const HomePodcastsBody({super.key});

  static const int _kLatestCap = 5;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(podcastEpisodeFeedProvider('in_progress'));
    ref.invalidate(podcastEpisodeFeedProvider('latest'));
    await Future.wait<void>(<Future<void>>[
      ref
          .read(podcastEpisodeFeedProvider('in_progress').future)
          .catchError((_) => const EpisodeFeedResponse(episodes: <EpisodeWithChannel>[], total: 0)),
      ref
          .read(podcastEpisodeFeedProvider('latest').future)
          .catchError((_) => const EpisodeFeedResponse(episodes: <EpisodeWithChannel>[], total: 0)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: const <Widget>[
          _ContinueListeningCarousel(),
          _LatestEpisodesSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ContinueListeningCarousel extends ConsumerWidget {
  const _ContinueListeningCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<EpisodeFeedResponse>>(
      podcastEpisodeFeedProvider('in_progress'),
      (AsyncValue<EpisodeFeedResponse>? prev, AsyncValue<EpisodeFeedResponse> next) =>
          reactToApiError(context, prev, next, action: 'load continue listening'),
    );
    final AsyncValue<EpisodeFeedResponse> async =
        ref.watch(podcastEpisodeFeedProvider('in_progress'));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 150, child: SkeletonList(count: 1)),
      ),
      error: (Object _, _) => const SizedBox.shrink(),
      data: (EpisodeFeedResponse feed) {
        if (feed.episodes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionHeader('Continue Listening'),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: feed.episodes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int i) =>
                    _ContinueListeningCard(episode: feed.episodes[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContinueListeningCard extends ConsumerWidget {
  const _ContinueListeningCard({required this.episode});

  final EpisodeWithChannel episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('home-continue-listening-${episode.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => playEpisode(ref, context, episode.toPodcastEpisode()),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: episode.imageUrl == null && episode.channelImageUrl == null
                    ? Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.podcasts, color: cs.onSurfaceVariant),
                      )
                    : Image.network(
                        (episode.imageUrl ?? episode.channelImageUrl)!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.podcasts, color: cs.onSurfaceVariant),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              episode.channelTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestEpisodesSection extends ConsumerWidget {
  const _LatestEpisodesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<EpisodeFeedResponse>>(
      podcastEpisodeFeedProvider('latest'),
      (AsyncValue<EpisodeFeedResponse>? prev, AsyncValue<EpisodeFeedResponse> next) =>
          reactToApiError(context, prev, next, action: 'load latest episodes'),
    );
    final AsyncValue<EpisodeFeedResponse> async =
        ref.watch(podcastEpisodeFeedProvider('latest'));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 220, child: SkeletonList(count: 3)),
      ),
      error: (Object e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (EpisodeFeedResponse feed) {
        if (feed.episodes.isEmpty) {
          // Matches the empty-state + Discover CTA pattern used elsewhere
          // (PodcastShowsGrid's "No subscriptions yet") — most of the time
          // this branch means the user has no subscriptions at all.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: <Widget>[
                const EmptyState(
                  icon: Icons.podcasts,
                  title: 'No episodes yet',
                  subtitle: 'Subscribe to a podcast to see its latest episodes.',
                ),
                const SizedBox(height: 16),
                Center(
                  child: FilledButton(
                    key: const Key('home-podcasts-discover-action'),
                    onPressed: () => context.push(Routes.podcastsDiscover),
                    child: const Text('Discover podcasts'),
                  ),
                ),
              ],
            ),
          );
        }
        final List<EpisodeWithChannel> capped =
            feed.episodes.take(HomePodcastsBody._kLatestCap).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionHeader('Latest Episodes'),
            for (final EpisodeWithChannel ep in capped) _LatestEpisodeRow(episode: ep),
          ],
        );
      },
    );
  }
}

class _LatestEpisodeRow extends ConsumerWidget {
  const _LatestEpisodeRow({required this.episode});

  final EpisodeWithChannel episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('home-latest-episode-${episode.id}'),
      title: Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(episode.channelTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.play_circle_outline, color: heerrMagenta),
      onTap: () => playEpisode(ref, context, episode.toPodcastEpisode()),
    );
  }
}
