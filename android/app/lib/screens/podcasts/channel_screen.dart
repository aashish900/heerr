import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/podcast_channel.dart';
import '../../models/podcast_episode.dart';
import '../../providers/podcasts/podcast_episode_download.dart';
import '../../providers/podcasts/podcast_episodes.dart';
import '../../providers/podcasts/podcast_subscriptions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/skeleton.dart';

/// PC3 (#53): a subscribed channel's paginated episode list. Episode rows
/// are informational only in this milestone (title/date/duration + played
/// or resume state) — download (PC4) and playback (PC5) actions land later.
/// Backend prereq: P3 (channel lookup), P4 (episode list + refresh).
class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({required this.channelId, super.key});

  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 200) {
      return;
    }
    ref
        .read(podcastEpisodesNotifierProvider(widget.channelId).notifier)
        .loadMore();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PodcastEpisodePage>>(
      podcastEpisodesNotifierProvider(widget.channelId),
      (AsyncValue<PodcastEpisodePage>? prev,
          AsyncValue<PodcastEpisodePage> next) =>
          reactToApiError(context, prev, next, action: 'load episodes'),
    );

    final PodcastChannel? channel = _findSubscribedChannel(ref);
    final AsyncValue<PodcastEpisodePage> async =
        ref.watch(podcastEpisodesNotifierProvider(widget.channelId));

    return Scaffold(
      appBar: AppBar(title: Text(channel?.title ?? 'Podcast')),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(podcastEpisodesNotifierProvider(widget.channelId).notifier)
            .refresh(),
        child: async.when(
          loading: () => const SkeletonList(count: 6),
          error: (Object e, _) => ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(e is ApiError ? e.message : 'Error: $e'),
              ),
            ],
          ),
          data: (PodcastEpisodePage page) {
            if (page.episodes.isEmpty) {
              return ListView(
                children: const <Widget>[
                  SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.podcasts,
                    title: 'No episodes yet',
                    subtitle: 'Pull to refresh once the feed publishes one.',
                  ),
                ],
              );
            }
            return ListView.builder(
              controller: _scroll,
              itemCount: page.episodes.length + (page.hasMore ? 1 : 0),
              itemBuilder: (BuildContext context, int i) {
                if (i >= page.episodes.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _EpisodeTile(episode: page.episodes[i]);
              },
            );
          },
        ),
      ),
    );
  }

  PodcastChannel? _findSubscribedChannel(WidgetRef ref) {
    final List<PodcastChannel>? subscriptions =
        ref.watch(podcastSubscriptionsProvider).valueOrNull;
    if (subscriptions == null) return null;
    for (final PodcastChannel c in subscriptions) {
      if (c.id == widget.channelId) return c;
    }
    return null;
  }
}

/// PC4 (#53): adds the per-episode Download action to the otherwise
/// read-only PC3 row. Dispatched jobs reuse the existing `jobs` queue
/// (`source_type == 'episode'`) — progress is surfaced by the existing
/// Queue screen, not tracked inline here; a successful dispatch just shows
/// a "Queued" snackbar, matching the online-search download affordance
/// (`library_search_results.dart::_downloadOnly`). [episode.downloaded]
/// renders as a static offline badge (not a button) once the job lands —
/// re-fetched on the channel's next pull-to-refresh.
class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.episode});

  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dispatching = ref.watch(
      podcastEpisodeDownloadDispatcherProvider
          .select((Set<String> s) => s.contains(episode.id)),
    );

    return ListTile(
      key: Key('podcast-episode-${episode.id}'),
      title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(episode)),
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
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          Icons.download_done,
          color: cs.onSurfaceVariant,
          semanticLabel: 'Downloaded',
        ),
      );
    }
    if (dispatching) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      key: Key('podcast-episode-download-${episode.id}'),
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

  String _subtitle(PodcastEpisode ep) {
    final List<String> parts = <String>[];
    if (ep.publishedAt != null) parts.add(_formatDate(ep.publishedAt!));
    if (ep.positionS > 0 && !ep.played) {
      parts.add('Resume at ${_formatDuration(ep.positionS)}');
    } else if (ep.durationS != null) {
      parts.add(_formatDuration(ep.durationS!));
    }
    return parts.join(' • ');
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime d) {
    final String mm = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
