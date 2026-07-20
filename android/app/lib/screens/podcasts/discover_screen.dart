import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/podcast_channel.dart';
import '../../providers/podcasts/podcast_search.dart';
import '../../providers/podcasts/podcast_subscriptions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/skeleton.dart';

/// PC2 (#53): Podcast Index search → tap a result → preview sheet →
/// Subscribe/Unsubscribe. Backend prereq: P2 (search), P3 (subscribe).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover Podcasts')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('podcast-discover-search-field'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search podcasts',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? const EmptyState(
                    icon: Icons.podcasts,
                    title: 'Find a podcast',
                    subtitle: 'Search by show name via Podcast Index.',
                  )
                : _DiscoverResults(query: _query),
          ),
        ],
      ),
    );
  }
}

class _DiscoverResults extends ConsumerWidget {
  const _DiscoverResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<PodcastChannel>>>(
      podcastSearchProvider(query),
      (AsyncValue<List<PodcastChannel>>? prev,
          AsyncValue<List<PodcastChannel>> next) =>
          reactToApiError(context, prev, next, action: 'search'),
    );

    final AsyncValue<List<PodcastChannel>> async =
        ref.watch(podcastSearchProvider(query));
    final List<PodcastChannel>? subscriptions =
        ref.watch(podcastSubscriptionsProvider).valueOrNull;

    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(e is ApiError ? e.message : 'podcast search error: $e'),
      ),
      data: (List<PodcastChannel> results) {
        if (results.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'No podcasts found',
            subtitle: 'Try a different search term.',
          );
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (BuildContext context, int i) {
            final PodcastChannel channel = results[i];
            final bool subscribed =
                isFeedSubscribed(subscriptions, channel.feedUrl);
            return ListTile(
              key: Key('podcast-search-result-${channel.feedUrl}'),
              leading: _ChannelArt(imageUrl: channel.imageUrl),
              title: Text(channel.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: channel.author == null
                  ? null
                  : Text(channel.author!, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: subscribed
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => _ChannelPreviewSheet.show(
                context: context,
                channel: channel,
              ),
            );
          },
        );
      },
    );
  }
}

class _ChannelArt extends StatelessWidget {
  const _ChannelArt({required this.imageUrl});

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

/// Channel-preview modal: title/author/description + a Subscribe /
/// Unsubscribe toggle. Subscribe state is read live from
/// [podcastSubscriptionsProvider] (matched by `feedUrl`, since a fresh
/// search result carries no `id`), so the toggle reflects reality even if
/// the user subscribed from elsewhere in the app.
class _ChannelPreviewSheet extends ConsumerStatefulWidget {
  const _ChannelPreviewSheet({required this.channel});

  final PodcastChannel channel;

  static void show({
    required BuildContext context,
    required PodcastChannel channel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChannelPreviewSheet(channel: channel),
    );
  }

  @override
  ConsumerState<_ChannelPreviewSheet> createState() =>
      _ChannelPreviewSheetState();
}

class _ChannelPreviewSheetState extends ConsumerState<_ChannelPreviewSheet> {
  bool _busy = false;

  Future<void> _toggle(PodcastChannel? subscribed) async {
    setState(() => _busy = true);
    try {
      if (subscribed != null) {
        await ref
            .read(podcastSubscriptionsProvider.notifier)
            .unsubscribe(subscribed.id!);
      } else {
        await ref
            .read(podcastSubscriptionsProvider.notifier)
            .subscribe(widget.channel.feedUrl);
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e, action: 'subscribe');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<PodcastChannel>? subscriptions =
        ref.watch(podcastSubscriptionsProvider).valueOrNull;
    final PodcastChannel? subscribed =
        subscribedChannelFor(subscriptions, widget.channel.feedUrl);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ChannelArt(imageUrl: widget.channel.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.channel.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.channel.author != null)
                        Text(
                          widget.channel.author!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.channel.description != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                widget.channel.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('podcast-subscribe-toggle'),
              onPressed: _busy ? null : () => _toggle(subscribed),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(subscribed != null ? 'Unsubscribe' : 'Subscribe'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
