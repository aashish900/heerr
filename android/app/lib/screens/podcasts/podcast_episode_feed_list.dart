import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/episode_feed_response.dart';
import '../../models/episode_with_channel.dart';
import '../../player/podcast_playback_actions.dart';
import '../../providers/podcasts/podcast_episode_download.dart';
import '../../providers/podcasts/podcast_episode_feed.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/skeleton.dart';

/// PR3 (#53): renders one of the cross-subscription episode feeds
/// (`podcastEpisodeFeedProvider`) as a plain list — shared by the Library
/// "Episodes" (filter `latest`) and "Downloads" (filter `downloaded`) tabs,
/// and by Home's "Latest Episodes" section. Home's "Continue Listening"
/// carousel renders the same `filter: in_progress` data in its own
/// horizontal layout instead (`screens/home/home_podcasts_body.dart`), so
/// isn't built on this widget.
class PodcastEpisodeFeedList extends ConsumerWidget {
  const PodcastEpisodeFeedList({
    required this.filter,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    super.key,
  });

  final String filter;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String action = filter == 'downloaded' ? 'load downloads' : 'load episodes';
    ref.listen<AsyncValue<EpisodeFeedResponse>>(
      podcastEpisodeFeedProvider(filter),
      (AsyncValue<EpisodeFeedResponse>? prev, AsyncValue<EpisodeFeedResponse> next) =>
          reactToApiError(context, prev, next, action: action),
    );

    final AsyncValue<EpisodeFeedResponse> async =
        ref.watch(podcastEpisodeFeedProvider(filter));

    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(e is ApiError ? e.message : 'Error: $e'),
        ),
      ),
      data: (EpisodeFeedResponse feed) {
        final List<EpisodeWithChannel> episodes = feed.episodes;
        if (episodes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                subtitle: emptySubtitle,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: episodes.length,
          itemBuilder: (BuildContext context, int i) =>
              _FeedEpisodeTile(episode: episodes[i]),
        );
      },
    );
  }
}

class _FeedEpisodeTile extends ConsumerWidget {
  const _FeedEpisodeTile({required this.episode});

  final EpisodeWithChannel episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dispatching = ref.watch(
      podcastEpisodeDownloadDispatcherProvider
          .select((Set<String> s) => s.contains(episode.id)),
    );

    return ListTile(
      key: Key('podcast-feed-episode-${episode.id}'),
      leading: _FeedEpisodeArt(imageUrl: episode.imageUrl ?? episode.channelImageUrl),
      title: Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(episode.channelTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => playEpisode(ref, context, episode.toPodcastEpisode()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (episode.played) Icon(Icons.check_circle, color: cs.primary),
          _downloadTrailing(context, ref, cs, dispatching: dispatching),
        ],
      ),
    );
  }

  Widget _downloadTrailing(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs, {
    required bool dispatching,
  }) {
    if (episode.downloaded) {
      return Icon(Icons.download_done, color: cs.onSurfaceVariant, semanticLabel: 'Downloaded');
    }
    if (dispatching) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return IconButton(
      key: Key('podcast-feed-episode-download-${episode.id}'),
      icon: const Icon(Icons.download_outlined),
      tooltip: 'Download',
      onPressed: () => _download(context, ref),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(podcastEpisodeDownloadDispatcherProvider.notifier)
          .dispatch(episode.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text('Queued: ${episode.title}'),
        ),
      );
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e, action: 'download');
    }
  }
}

class _FeedEpisodeArt extends StatelessWidget {
  const _FeedEpisodeArt({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const double size = 48;
    final Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.podcasts, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final String? url = imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
