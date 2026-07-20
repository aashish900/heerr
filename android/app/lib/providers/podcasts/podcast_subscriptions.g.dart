// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_subscriptions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastSubscriptionsHash() =>
    r'ef49c1d0d84f7887347bc34a5ed6fe7b90b72869';

/// The calling user's subscribed channels (`GET /podcasts/subscriptions`).
///
/// Shared between the Discover screen (PC2 — matches search results against
/// this list by `feedUrl` to render Subscribe/Unsubscribe) and the
/// Subscriptions screen (PC3 — renders this list directly), so both stay in
/// sync through the same provider rather than duplicating subscribe state.
///
/// Copied from [PodcastSubscriptions].
@ProviderFor(PodcastSubscriptions)
final podcastSubscriptionsProvider =
    AsyncNotifierProvider<PodcastSubscriptions, List<PodcastChannel>>.internal(
      PodcastSubscriptions.new,
      name: r'podcastSubscriptionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$podcastSubscriptionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PodcastSubscriptions = AsyncNotifier<List<PodcastChannel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
