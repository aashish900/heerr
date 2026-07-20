import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/backend_service.dart';
import 'episode_progress_controller.dart';
import 'player_provider.dart';

part 'episode_progress_provider.g.dart';

/// Boots an [EpisodeProgressController] wired to the running
/// `HeerrAudioHandler` + [BackendService]. Keep-alive so it survives screen
/// rebuilds and tracks every episode play across the session — same shape
/// as `scrobble_provider.dart::scrobbleProvider`.
///
/// Read once at the root of the widget tree (see `HeerrApp.build`) to
/// trigger the subscription chain. Exposes nothing the UI needs — its work
/// is purely the side-effecting controller it owns.
@Riverpod(keepAlive: true)
Future<void> episodeProgress(EpisodeProgressRef ref) async {
  final handler = ref.watch(audioHandlerProvider);
  final BackendService backend = await ref.watch(backendServiceProvider.future);

  final EpisodeProgressController controller = EpisodeProgressController(
    mediaItemStream: handler.mediaItem.stream,
    positionStream: handler.player.positionStream,
    playbackStateStream: handler.playbackState.stream,
    report: (String episodeId, int positionS, {required bool played}) =>
        backend
            .updateEpisodeProgress(
              episodeId,
              positionS: positionS,
              played: played,
            )
            .then((_) {}),
  );
  controller.start();
  ref.onDispose(() {
    // Fire-and-forget dispose; Riverpod's onDispose is sync. The stream
    // cancels complete quickly (same rationale as scrobble_provider.dart).
    controller.dispose();
  });
}
