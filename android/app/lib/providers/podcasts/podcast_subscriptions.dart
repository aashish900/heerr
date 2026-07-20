import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/podcast_channel.dart';
import '../../services/backend_service.dart';

part 'podcast_subscriptions.g.dart';

/// The calling user's subscribed channels (`GET /podcasts/subscriptions`).
///
/// Shared between the Discover screen (PC2 — matches search results against
/// this list by `feedUrl` to render Subscribe/Unsubscribe) and the
/// Subscriptions screen (PC3 — renders this list directly), so both stay in
/// sync through the same provider rather than duplicating subscribe state.
@Riverpod(keepAlive: true)
class PodcastSubscriptions extends _$PodcastSubscriptions {
  @override
  Future<List<PodcastChannel>> build() async {
    final BackendService backend =
        await ref.watch(backendServiceProvider.future);
    return backend.podcastSubscriptions();
  }

  /// Subscribes to [feedUrl] (ingesting the feed server-side if it's new)
  /// and appends the result to local state. Returns the ingested channel
  /// (`id` set) so the caller can immediately offer "Unsubscribe".
  Future<PodcastChannel> subscribe(String feedUrl) async {
    final BackendService backend =
        await ref.read(backendServiceProvider.future);
    final PodcastChannel channel = await backend.subscribePodcast(feedUrl);

    final List<PodcastChannel> current = state.valueOrNull ?? const <PodcastChannel>[];
    if (!current.any((PodcastChannel c) => c.id == channel.id)) {
      state = AsyncData<List<PodcastChannel>>(<PodcastChannel>[
        channel,
        ...current,
      ]);
    }
    return channel;
  }

  /// Unsubscribes from [channelId] and removes it from local state.
  Future<void> unsubscribe(String channelId) async {
    final BackendService backend =
        await ref.read(backendServiceProvider.future);
    await backend.unsubscribePodcast(channelId);

    final List<PodcastChannel> current = state.valueOrNull ?? const <PodcastChannel>[];
    state = AsyncData<List<PodcastChannel>>(
      current.where((PodcastChannel c) => c.id != channelId).toList(),
    );
  }

  /// Pull-to-refresh (PC3 Subscriptions screen) — re-fetches the list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// True when [feedUrl] appears (by exact match) in the current subscription
/// list. Returns `false` while the list is loading/erroring rather than
/// propagating that state — the Discover screen always has an offer-to-
/// subscribe fallback, so "unknown" reads the same as "not subscribed".
bool isFeedSubscribed(List<PodcastChannel>? subscriptions, String feedUrl) {
  if (subscriptions == null) return false;
  return subscriptions.any((PodcastChannel c) => c.feedUrl == feedUrl);
}

/// Looks up the subscribed [PodcastChannel] (with its `id`) for [feedUrl],
/// or `null` when not subscribed. Used to resolve the `channelId` an
/// Unsubscribe action needs.
PodcastChannel? subscribedChannelFor(
  List<PodcastChannel>? subscriptions,
  String feedUrl,
) {
  if (subscriptions == null) return null;
  for (final PodcastChannel c in subscriptions) {
    if (c.feedUrl == feedUrl) return c;
  }
  return null;
}
