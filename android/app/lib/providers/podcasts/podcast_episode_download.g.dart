// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_episode_download.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastEpisodeDownloadDispatcherHash() =>
    r'5fc8ce105bd3202a87091637bf7c9b48d5e740fc';

/// PC4 (#53): tracks which episode ids have an in-flight
/// `POST /podcasts/episodes/{id}/download`. Same shape as
/// `providers/download.dart::DownloadDispatcher` (state is the set of
/// in-flight ids; UI watches its own id's membership to render a spinner) —
/// kept as a separate provider because the wire call is a different
/// endpoint with a different request shape (path param, no body).
///
/// Dispatched jobs reuse the existing `jobs` queue (`source_type ==
/// 'episode'`) and so already show up in `GET /queue` / the Queue screen
/// without further wiring.
///
/// Copied from [PodcastEpisodeDownloadDispatcher].
@ProviderFor(PodcastEpisodeDownloadDispatcher)
final podcastEpisodeDownloadDispatcherProvider =
    NotifierProvider<PodcastEpisodeDownloadDispatcher, Set<String>>.internal(
      PodcastEpisodeDownloadDispatcher.new,
      name: r'podcastEpisodeDownloadDispatcherProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$podcastEpisodeDownloadDispatcherHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PodcastEpisodeDownloadDispatcher = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
