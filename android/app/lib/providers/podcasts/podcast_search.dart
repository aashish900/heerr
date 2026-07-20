import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/podcast_channel.dart';
import '../../services/backend_service.dart';
import '../search.dart';

part 'podcast_search.g.dart';

/// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
/// way as the online song search (`providers/search.dart::ytmSearch`) —
/// shares [searchDebounceProvider] rather than duplicating the constant.
///
/// Family-keyed by the query string. Empty/whitespace queries short-circuit
/// without hitting the network. Results have a null `PodcastChannel.id`
/// (not yet ingested) — the Discover screen matches against
/// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
/// already subscribed.
@riverpod
Future<List<PodcastChannel>> podcastSearch(
  PodcastSearchRef ref,
  String query,
) async {
  if (query.trim().isEmpty) {
    return const <PodcastChannel>[];
  }

  final Duration debounce = ref.read(searchDebounceProvider);

  final CancelToken cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  await Future<void>.delayed(debounce);

  if (cancelToken.isCancelled) {
    throw const _DebounceCancelled();
  }

  final BackendService backend =
      await ref.watch(backendServiceProvider.future);
  return backend.searchPodcasts(query, cancelToken: cancelToken);
}

class _DebounceCancelled implements Exception {
  const _DebounceCancelled();
  @override
  String toString() => 'podcast search debounce cancelled';
}
