import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/episode_download_response.dart';
import '../../services/backend_service.dart';

part 'podcast_episode_download.g.dart';

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
@Riverpod(keepAlive: true)
class PodcastEpisodeDownloadDispatcher
    extends _$PodcastEpisodeDownloadDispatcher {
  @override
  Set<String> build() => const <String>{};

  Future<EpisodeDownloadResponse> dispatch(String episodeId) async {
    state = <String>{...state, episodeId};
    try {
      final BackendService backend =
          await ref.read(backendServiceProvider.future);
      return await backend.downloadPodcastEpisode(episodeId);
    } finally {
      state = <String>{...state}..remove(episodeId);
    }
  }
}
