import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/podcast_channel.dart';
import '../../models/podcast_episode.dart';
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

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode});

  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('podcast-episode-${episode.id}'),
      title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(episode)),
      trailing: episode.played
          ? Icon(Icons.check_circle, color: cs.primary)
          : (episode.downloaded
              ? Icon(Icons.download_done, color: cs.onSurfaceVariant)
              : null),
    );
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
