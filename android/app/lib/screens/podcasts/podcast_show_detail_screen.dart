import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/podcast_channel.dart';
import '../../models/podcast_episode.dart';
import '../../player/podcast_playback_actions.dart';
import '../../providers/podcasts/podcast_episode_download.dart';
import '../../providers/podcasts/podcast_episodes.dart';
import '../../providers/podcasts/podcast_subscriptions.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/gradient_tab_indicator.dart';
import '../../widgets/skeleton.dart';

/// PR1 (#53): a subscribed show's detail screen — hero art, Continue /
/// Following actions, Continue Listening + Latest Episode mini-sections
/// (both derived client-side from the already-loaded episode page — no new
/// backend), and Episodes / About tabs. Replaces the PC3 `ChannelScreen` at
/// the same route (`/podcasts/channel/:id`). No "Related" tab (dropped —
/// see the plan's scope decisions; the design's data isn't backed by
/// anything the feed/DB carries).
class PodcastShowDetailScreen extends ConsumerStatefulWidget {
  const PodcastShowDetailScreen({required this.channelId, super.key});

  final String channelId;

  @override
  ConsumerState<PodcastShowDetailScreen> createState() =>
      _PodcastShowDetailScreenState();
}

class _PodcastShowDetailScreenState
    extends ConsumerState<PodcastShowDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scroll = ScrollController();

  // Cached across unsubscribe, so the hero doesn't blank out the moment
  // the user taps "Following" to unsubscribe (podcastSubscriptionsProvider
  // no longer carries this channel once that happens).
  PodcastChannel? _cachedChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _tabController.dispose();
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

  PodcastChannel? _resolveChannel(WidgetRef ref) {
    final List<PodcastChannel>? subscriptions =
        ref.watch(podcastSubscriptionsProvider).valueOrNull;
    if (subscriptions != null) {
      for (final PodcastChannel c in subscriptions) {
        if (c.id == widget.channelId) {
          _cachedChannel = c;
          break;
        }
      }
    }
    return _cachedChannel;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PodcastEpisodePage>>(
      podcastEpisodesNotifierProvider(widget.channelId),
      (AsyncValue<PodcastEpisodePage>? prev,
          AsyncValue<PodcastEpisodePage> next) =>
          reactToApiError(context, prev, next, action: 'load episodes'),
    );

    final PodcastChannel? channel = _resolveChannel(ref);
    final AsyncValue<PodcastEpisodePage> async =
        ref.watch(podcastEpisodesNotifierProvider(widget.channelId));
    final List<PodcastEpisode> episodes =
        async.valueOrNull?.episodes ?? const <PodcastEpisode>[];

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: <Widget>[
          _ShowHero(channel: channel, episodeCount: async.valueOrNull?.total),
          _ActionRow(channel: channel, episodes: episodes),
          _MiniSections(episodes: episodes),
          TabBar(
            controller: _tabController,
            indicator: const GradientTabIndicator(),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: heerrMagenta,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: const <Tab>[
              Tab(text: 'Episodes'),
              Tab(text: 'About'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                RefreshIndicator(
                  onRefresh: () => ref
                      .read(podcastEpisodesNotifierProvider(widget.channelId)
                          .notifier)
                      .refresh(),
                  child: async.when(
                    loading: () => const SkeletonList(count: 6),
                    error: (Object e, _) => ListView(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              Text(e is ApiError ? e.message : 'Error: $e'),
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
                              subtitle:
                                  'Pull to refresh once the feed publishes one.',
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        controller: _scroll,
                        itemCount:
                            page.episodes.length + (page.hasMore ? 1 : 0),
                        itemBuilder: (BuildContext context, int i) {
                          if (i >= page.episodes.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _EpisodeTile(
                            episode: page.episodes[i],
                            channel: channel,
                          );
                        },
                      );
                    },
                  ),
                ),
                _AboutTab(channel: channel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Large cover art + gradient scrim, title, `author • N episodes`.
class _ShowHero extends StatelessWidget {
  const _ShowHero({required this.channel, required this.episodeCount});

  final PodcastChannel? channel;
  final int? episodeCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String title = channel?.title ?? 'Podcast';
    final List<String> metaParts = <String>[
      if (channel?.author != null) channel!.author!,
      if (episodeCount != null) '$episodeCount episodes',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PodcastArt(imageUrl: channel?.imageUrl, size: 96),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (metaParts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    metaParts.join(' • '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (channel?.description != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    channel!.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Continue/Play + Following. "Continue" resumes the show's most-recent
/// in-progress episode; falls back to "Play" (the newest episode) when
/// nothing is in progress yet. Hidden (via disabled state) until episodes
/// have loaded.
class _ActionRow extends ConsumerStatefulWidget {
  const _ActionRow({required this.channel, required this.episodes});

  final PodcastChannel? channel;
  final List<PodcastEpisode> episodes;

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  bool _followBusy = false;

  PodcastEpisode? get _continueEpisode {
    for (final PodcastEpisode e in widget.episodes) {
      if (e.positionS > 0 && !e.played) return e;
    }
    return null;
  }

  Future<void> _toggleFollow() async {
    final PodcastChannel? channel = widget.channel;
    if (channel?.id == null) return;
    setState(() => _followBusy = true);
    try {
      await ref
          .read(podcastSubscriptionsProvider.notifier)
          .unsubscribe(channel!.id!);
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e, action: 'unsubscribe');
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PodcastEpisode? continueEp = _continueEpisode;
    final PodcastEpisode? playEp =
        continueEp ?? (widget.episodes.isEmpty ? null : widget.episodes.first);
    final bool following = widget.channel != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              key: const Key('podcast-show-continue'),
              onPressed: playEp == null
                  ? null
                  : () => playEpisode(ref, context, playEp),
              icon: Icon(
                  continueEp != null ? Icons.play_arrow : Icons.play_circle_outline),
              label: Text(continueEp != null ? 'Continue' : 'Play'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('podcast-show-following-toggle'),
            onPressed: _followBusy ? null : _toggleFollow,
            child: _followBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(following ? 'Following' : 'Follow'),
          ),
        ],
      ),
    );
  }
}

/// Continue Listening + Latest Episode mini-rows, derived client-side from
/// the already-loaded first episode page (no new backend call).
class _MiniSections extends StatelessWidget {
  const _MiniSections({required this.episodes});

  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return const SizedBox.shrink();

    PodcastEpisode? continueEp;
    for (final PodcastEpisode e in episodes) {
      if (e.positionS > 0 && !e.played) {
        continueEp = e;
        break;
      }
    }
    final PodcastEpisode latest = episodes.first;

    final List<Widget> rows = <Widget>[];
    if (continueEp != null) {
      rows.add(_MiniEpisodeRow(
        key: const Key('podcast-show-continue-listening'),
        label: 'Continue Listening',
        episode: continueEp,
      ));
    }
    if (continueEp?.id != latest.id) {
      rows.add(_MiniEpisodeRow(
        key: const Key('podcast-show-latest-episode'),
        label: 'Latest Episode',
        episode: latest,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _MiniEpisodeRow extends ConsumerWidget {
  const _MiniEpisodeRow({required this.label, required this.episode, super.key});

  final String label;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => playEpisode(ref, context, episode),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.channel});

  final PodcastChannel? channel;

  @override
  Widget build(BuildContext context) {
    final String? description = channel?.description;
    if (description == null || description.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.info_outline,
          title: 'No description',
          subtitle: 'This show has no description.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// PR1 (#53): richer episode row — leading art (falls back to the show's
/// art, then a podcast glyph), a thin gradient progress bar when partially
/// played, and the existing PC4 download-state machine. Sort control
/// (Newest / Oldest / Unplayed) is deferred to Phase PR3, when the backend
/// gains a `sort` query param — shipping it now would offer dead options.
class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.episode, required this.channel});

  final PodcastEpisode episode;
  final PodcastChannel? channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dispatching = ref.watch(
      podcastEpisodeDownloadDispatcherProvider
          .select((Set<String> s) => s.contains(episode.id)),
    );
    final bool inProgress = episode.positionS > 0 && !episode.played;
    final double? progressFraction =
        (inProgress && episode.durationS != null && episode.durationS! > 0)
            ? (episode.positionS / episode.durationS!).clamp(0.0, 1.0)
            : null;

    return ListTile(
      key: Key('podcast-episode-${episode.id}'),
      leading: _PodcastArt(
        imageUrl: episode.imageUrl ?? channel?.imageUrl,
        size: 48,
      ),
      title: Text(
        episode.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: episode.played
            ? TextStyle(color: cs.onSurfaceVariant)
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_subtitle(episode)),
          if (progressFraction != null) ...<Widget>[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: ShaderMask(
                shaderCallback: (Rect bounds) =>
                    heerrGradient.createShader(bounds),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 3,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => playEpisode(ref, context, episode),
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

/// Shared square art tile with a podcast-glyph fallback — used for both
/// the show hero and episode leading art.
class _PodcastArt extends StatelessWidget {
  const _PodcastArt({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.podcasts,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
