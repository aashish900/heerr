import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/podcast_channel.dart';
import '../../providers/podcasts/podcast_subscriptions.dart';
import '../../router.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/skeleton.dart';

/// PC3 (#53): the calling user's subscribed channels
/// (`GET /podcasts/subscriptions`, via [podcastSubscriptionsProvider]).
/// Backend prereq: P3.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<PodcastChannel>>>(
      podcastSubscriptionsProvider,
      (AsyncValue<List<PodcastChannel>>? prev,
          AsyncValue<List<PodcastChannel>> next) =>
          reactToApiError(context, prev, next, action: 'load subscriptions'),
    );

    final AsyncValue<List<PodcastChannel>> async =
        ref.watch(podcastSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcasts'),
        actions: <Widget>[
          IconButton(
            key: const Key('podcasts-discover-action'),
            icon: const Icon(Icons.add),
            tooltip: 'Discover podcasts',
            onPressed: () => context.push(Routes.podcastsDiscover),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(podcastSubscriptionsProvider.notifier).refresh(),
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
          data: (List<PodcastChannel> channels) {
            if (channels.isEmpty) {
              return ListView(
                children: <Widget>[
                  const SizedBox(height: 48),
                  const EmptyState(
                    icon: Icons.podcasts,
                    title: 'No subscriptions yet',
                    subtitle: 'Discover a podcast to subscribe.',
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: () =>
                          context.push(Routes.podcastsDiscover),
                      child: const Text('Discover podcasts'),
                    ),
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.82,
              ),
              itemCount: channels.length,
              itemBuilder: (BuildContext context, int i) {
                final PodcastChannel channel = channels[i];
                return _ChannelCard(channel: channel);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final PodcastChannel channel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('podcast-subscription-${channel.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(Routes.podcastsChannel(channel.id!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: channel.imageUrl == null
                  ? Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.podcasts, color: cs.onSurfaceVariant),
                    )
                  : Image.network(
                      channel.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Container(
                        color: cs.surfaceContainerHighest,
                        child:
                            Icon(Icons.podcasts, color: cs.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            channel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (channel.author != null)
            Text(
              channel.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
