import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/episode_feed_response.dart';
import '../../services/backend_service.dart';

part 'podcast_episode_feed.g.dart';

/// PA1/PR3 (#53): episodes across every show the calling user is
/// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
/// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
/// Backs Home's Continue Listening/Latest Episodes sections and the Library
/// Episodes/Downloads tabs — three call sites sharing one provider rather
/// than three near-identical ones. Fixed page size (20); none of PR3's
/// three call sites paginate.
@riverpod
Future<EpisodeFeedResponse> podcastEpisodeFeed(
  PodcastEpisodeFeedRef ref,
  String filter,
) async {
  final BackendService backend =
      await ref.watch(backendServiceProvider.future);
  return backend.podcastEpisodeFeed(filter);
}
